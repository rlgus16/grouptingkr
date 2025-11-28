import 'dart:async';

import 'package:flutter/material.dart';
import 'package:groupting/services/chatroom_service.dart';

import '../models/group_model.dart';
import '../models/invitation_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/group_service.dart';
import '../services/invitation_service.dart';
import '../services/user_service.dart';

class GroupController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final GroupService _groupService = GroupService();
  final InvitationService _invitationService = InvitationService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  GroupModel? _currentGroup;
  List<UserModel> _groupMembers = [];
  List<InvitationModel> _receivedInvitations = [];
  List<InvitationModel> _sentInvitations = [];
  bool _isMatching = false;
  String _myGroupId = '';

  // Streams
  Stream<GroupModel?>? _groupStream;
  StreamSubscription<GroupModel?>? _groupSubscription;
  StreamSubscription<List<InvitationModel>>? _receivedInvitationsSubscription;
  StreamSubscription<List<InvitationModel>>? _sentInvitationsSubscription;
  Timer? _reconnectTimer;

  // Callbacks
  VoidCallback? onMatchingCompleted;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GroupModel? get currentGroup => _currentGroup;
  List<UserModel> get groupMembers => _groupMembers;
  List<InvitationModel> get receivedInvitations => _receivedInvitations;
  List<InvitationModel> get sentInvitations => _sentInvitations;
  bool get isMatching => _isMatching;
  bool get isOwner =>
      _currentGroup != null &&
      _currentGroup!.isOwner(_firebaseService.currentUserId ?? '');
  bool get canMatch =>
      _currentGroup != null && _currentGroup!.canMatch && isOwner;
  bool get isMatched => _currentGroup?.status == GroupStatus.matched;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearData() {
    _groupSubscription?.cancel();
    _groupSubscription = null;
    _receivedInvitationsSubscription?.cancel();
    _receivedInvitationsSubscription = null;
    _sentInvitationsSubscription?.cancel();
    _sentInvitationsSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    _currentGroup = null;
    _groupMembers.clear();
    _receivedInvitations.clear();
    _sentInvitations.clear();
    _isMatching = false;
    notifyListeners();
  }

  // 그룹 생성
  Future<bool> createGroup() async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        _setError('로그인이 필요합니다.');
        return false;
      }

      // === 프로필 완성도 서버 사이드 검증 ===
      final userService = UserService();
      final currentUser = await userService.getUserById(currentUserId);
      
      if (currentUser == null) {
        _setError('사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.');
        return false;
      }
      
      // 프로필 완성도 체크
      if (!_isProfileCompleteForGroupCreation(currentUser)) {
        _setError('그룹을 생성하려면 프로필을 완성해야 합니다.');
        return false;
      }

      final group = await _groupService.createGroup(currentUserId);
      _currentGroup = group;
      await _loadGroupMembers();

      // 그룹 상태 실시간 감지 시작
      _startGroupStatusStream();

      // [빠른손] 채팅방 존재 여부 확인 후 없는 경우 임시 생성 >>
      _myGroupId = group.id;
      final chatroomService = ChatroomService();
      final members = await _groupService.getGroupMembers(_myGroupId);
      final participants = [for (final m in members) m.uid];

      await chatroomService.getOrCreateChatroom(
        chatRoomId: _myGroupId,
        groupId: _myGroupId,
        participants: participants,
      );
      // <<

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('그룹 생성에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 그룹 상태 실시간 감지 (재연결 로직 포함)
  void _startGroupStatusStream() {
    if (_currentGroup == null) return;

    final chatroomService = ChatroomService();

    // 기존 구독 취소
    _groupSubscription?.cancel();
    _reconnectTimer?.cancel();

    _groupStream = _groupService.getGroupStream(_currentGroup!.id);
    _groupSubscription = _groupStream!.listen(
      (group) {
        if (group != null) {
          final currentUserId = _firebaseService.currentUserId;
          if (currentUserId == null || !group.memberIds.contains(currentUserId)) {
            _clearData();
            return;
          }

          final oldStatus = _currentGroup?.status;

          // [빠른손] 그룹 내 멤버 수 변경 감지(수락 및 나가기) 시 멤버 다시 로드
          if (_currentGroup?.memberCount != group.memberCount) {
            _loadGroupMembers();

            // [빠른손] 임시 채팅방 참여자 업데이트
            _myGroupId = _currentGroup?.id ?? '';
            if (group.isMember(_firebaseService.currentUserId ?? '')) {
              _myGroupId = group.id;
            }

            // [빠른손] 채팅방 ID가 유효하고 현재 사용자가 방장인 경우에만 업데이트
            if (_myGroupId.isNotEmpty &&
                group.ownerId == _firebaseService.currentUserId) {
              chatroomService.updateParticipants(
                chatRoomId: _myGroupId,
                participants: group.memberIds,
              );
            }
          }

          // [빠른손] 매칭 중 상태 업데이트
          _isMatching = group.status == GroupStatus.matching;

          _currentGroup = group;

          // 매칭 완료 감지
          if (oldStatus == GroupStatus.matching &&
              group.status == GroupStatus.matched) {
            // [빠른손] 임시 채팅방 삭제 >>
            chatroomService.deleteChatroom(_myGroupId);
            _myGroupId = '';
            // <<
            _handleMatchingCompleted();
          }

          _loadGroupMembers();

          notifyListeners();
        } else {
          // 그룹이 삭제된 경우 (예: 마지막 멤버가 나감)
          _clearData();
        }
      },
      onError: (error) {
        _scheduleReconnect();
      },
      onDone: () {
        if (_currentGroup != null) {
          _scheduleReconnect();
        }
      },
    );
  }

  // 스트림 재연결 스케줄링
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentGroup != null) {
        _startGroupStatusStream();
      }
    });
  }

  // 매칭 완료 처리
  void _handleMatchingCompleted() {

    // UI 콜백 호출 (null 체크)
    if (onMatchingCompleted != null) {
      try {
        onMatchingCompleted!();
      } catch (e) {
        debugPrint('매칭 완료 콜백 실행 중 오류: $e');
      }
    }

    // 그룹 멤버 다시 로드 (상대방 그룹 멤버 포함)
    _loadGroupMembers();

    // 잠시 후 한 번 더 로드 (Firestore 동기화 지연 대응)
    Future.delayed(const Duration(seconds: 2), () {
      // 컨트롤러가 여전히 유효한지 확인
      if (_currentGroup != null && _currentGroup!.status == GroupStatus.matched) {
        _loadGroupMembers();
      }
    });
  }

  // 그룹 멤버 로드
  Future<void> _loadGroupMembers() async {
    if (_currentGroup == null) return;

    try {
      _groupMembers = await _groupService.getGroupMembers(_currentGroup!.id);
      notifyListeners();
    } catch (e) {
      _setError('그룹 멤버를 로드하는데 실패했습니다: $e');
    }
  }

  // 친구 초대
  Future<bool> inviteFriend({required String nickname, String? message}) async {
    try {
      _setLoading(true);
      _setError(null);

      if (_currentGroup == null) {
        _setError('그룹이 없습니다.');
        _setLoading(false);
        return false;
      }

      await _invitationService.sendInvitation(
        groupId: _currentGroup!.id,
        toUserNickname: nickname,
        message: message,
      );

      await _loadSentInvitations();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_getFriendlyErrorMessage(e.toString()));
      _setLoading(false);
      return false;
    }
  }

  // 사용자 친화적인 에러 메시지 변환
  String _getFriendlyErrorMessage(String error) {
    if (error.contains('해당 사용자는 이미 다른 그룹에 속해있습니다')) {
      return '이미 다른 그룹에 참여 중인 친구예요';
    } else if (error.contains('해당 닉네임의 사용자를 찾을 수 없습니다')) {
      return '존재하지 않는 닉네임이에요';
    } else if (error.contains('자기 자신에게는 초대를 보낼 수 없습니다')) {
      return '본인은 초대할 수 없어요';
    } else if (error.contains('그룹 인원이 가득 찼습니다')) {
      return '그룹 인원이 가득 찼어요 (최대 5명)';
    } else if (error.contains('그룹 방장만 초대를 보낼 수 있습니다')) {
      return '방장만 친구를 초대할 수 있어요';
    } else if (error.contains('이미 해당 사용자에게 초대를 보냈습니다')) {
      return '이미 초대를 보낸 친구예요';
    } else if (error.contains('로그인이 필요합니다')) {
      return '로그인이 필요해요';
    } else if (error.contains('그룹을 찾을 수 없습니다')) {
      return '그룹 정보를 찾을 수 없어요';
    } else {
      return '초대 전송에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  // 보낸 초대 취소
  Future<bool> cancelSentInvitation(String invitationId) async {
    try {
      _setLoading(true);
      _setError(null);

      final success = await _invitationService.cancelInvitation(invitationId);
      if (success) {
        await _loadSentInvitations();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('초대 취소에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 받은 초대 로드
  Future<void> _loadReceivedInvitations() async {
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId == null) return;

    try {
      // 기존 구독 취소
      _receivedInvitationsSubscription?.cancel();
      
      _receivedInvitationsSubscription = _invitationService.getReceivedInvitationsStream(currentUserId).listen((
        invitations,
      ) {
        _receivedInvitations = invitations;
        notifyListeners();
      }, onError: (error) {
        _setError('받은 초대를 로드하는데 실패했습니다: $error');
      });
    } catch (e) {
      _setError('받은 초대를 로드하는데 실패했습니다: $e');
    }
  }

  // 보낸 초대 로드
  Future<void> _loadSentInvitations() async {
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId == null) return;

    try {
      // 기존 구독 취소
      _sentInvitationsSubscription?.cancel();
      
      _sentInvitationsSubscription = _invitationService.getSentInvitationsStream(currentUserId).listen((
        invitations,
      ) {
        _sentInvitations = invitations;
        notifyListeners();
      }, onError: (error) {
        _setError('보낸 초대를 로드하는데 실패했습니다: $error');
      });
    } catch (e) {
      _setError('보낸 초대를 로드하는데 실패했습니다: $e');
    }
  }

  // 초대 수락 (업데이트)
  Future<bool> acceptInvitation(String invitationId) async {
    // 1. 업데이트: 즉시 UI에서 초대 제거
    final invitationToAccept = _receivedInvitations.firstWhere(
      (invitation) => invitation.id == invitationId,
      orElse: () => throw Exception('초대를 찾을 수 없습니다'),
    );
    
    // UI에서 즉시 제거
    _receivedInvitations.removeWhere((invitation) => invitation.id == invitationId);
    notifyListeners(); // 즉시 UI 업데이트
    
    try {
      _setLoading(true);
      _setError(null);

      debugPrint('초대 수락 시작: $invitationId');
      
      final success = await _invitationService.respondToInvitation(
        invitationId,
        true,
      );

      if (success) {
        debugPrint('초대 수락 성공 - 그룹 정보 새로고침');
        // 강제로 그룹 정보 새로고침 (스트림 지연 방지)
        await loadCurrentGroup();
        
        // 잠시 후 한 번 더 새로고침 (Firestore 동기화 지연 대응)
        Future.delayed(const Duration(seconds: 1), () {
          if (_currentGroup != null) {
            loadCurrentGroup();
          }
        });
      } else {
        // 실패 시 초대를 다시 목록에 추가 (롤백)
        _receivedInvitations.add(invitationToAccept);
        _receivedInvitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _setLoading(false);
      return success;
    } catch (e) {
      debugPrint('초대 수락 실패: $e');
      
      // 실패 시 초대를 다시 목록에 추가 (롤백)
      _receivedInvitations.add(invitationToAccept);
      _receivedInvitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners(); // UI 롤백
      
      _setError('초대 수락에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 초대 거절 (업데이트)
  Future<bool> rejectInvitation(String invitationId) async {
    // 1. 업데이트: 즉시 UI에서 초대 제거
    final invitationToReject = _receivedInvitations.firstWhere(
      (invitation) => invitation.id == invitationId,
      orElse: () => throw Exception('초대를 찾을 수 없습니다'),
    );
    
    // UI에서 즉시 제거
    _receivedInvitations.removeWhere((invitation) => invitation.id == invitationId);
    notifyListeners(); // 즉시 UI 업데이트
    
    try {
      _setLoading(true);
      _setError(null);

      debugPrint('초대 거절 시작: $invitationId');
      
      final success = await _invitationService.respondToInvitation(
        invitationId,
        false,
      );

      if (!success) {
        // 실패 시 초대를 다시 목록에 추가 (롤백)
        _receivedInvitations.add(invitationToReject);
        _receivedInvitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners(); // UI 롤백
      }

      _setLoading(false);
      return success;
    } catch (e) {
      debugPrint('초대 거절 실패: $e');
      
      // 실패 시 초대를 다시 목록에 추가 (롤백)
      _receivedInvitations.add(invitationToReject);
      _receivedInvitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners(); // UI 롤백
      
      _setError('초대 거절에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 현재 그룹 로드
  Future<void> loadCurrentGroup() async {
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId == null) {
      _clearData();
      return;
    }

    try {
      _currentGroup = await _groupService.getUserCurrentGroup(currentUserId);
      
      if (_currentGroup != null) {
        await _loadGroupMembers();
        _startGroupStatusStream();
      } else {
        _clearData();
      }
      notifyListeners();
    } catch (e) {
      _setError('그룹 정보를 로드하는데 실패했습니다: $e');
    }
  }

  // 매칭 시작
  Future<bool> startMatching() async {
    try {
      _setLoading(true);
      _setError(null);

      if (_currentGroup == null) {
        _setError('그룹이 없습니다.');
        return false;
      }

      // 디버깅: 매칭 시작 전 현재 상태 확인
      await _groupService.debugMatchingGroups();
      
      await _groupService.startMatching(_currentGroup!.id);
      _isMatching = true;

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('매칭 시작에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 매칭 취소
  Future<bool> cancelMatching() async {
    try {
      _setLoading(true);
      _setError(null);

      if (_currentGroup == null) {
        _setError('그룹이 없습니다.');
        return false;
      }

      await _groupService.cancelMatching(_currentGroup!.id);
      _isMatching = false;

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('매칭 취소에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 그룹 나가기
  Future<bool> leaveGroup() async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null || _currentGroup == null) {
        _setError('그룹 정보가 없습니다.');
        _setLoading(false);
        return false;
      }

      final success = await _groupService.leaveGroup(
        _currentGroup!.id,
        currentUserId,
      );

      if (success) {
        // 즉시 이전 그룹의 리스너를 중지하고 상태를 클리어
        _groupSubscription?.cancel();
        _groupSubscription = null;
        _currentGroup = null;
        _groupMembers.clear();
        
        // 새로운 그룹 정보를 로드
        await refreshData();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('그룹 나가기에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 멤버 ID로 멤버 정보 가져오기
  UserModel? getMemberById(String userId) {
    try {
      return _groupMembers.firstWhere((member) => member.uid == userId);
    } catch (e) {
      return null;
    }
  }

  // 초기화 (에러 상태 포함)
  Future<void> initialize() async {
    try {
      _setError(null);
      debugPrint('GroupController: 초기화 시작');
      
      await refreshData();
      
      debugPrint('GroupController: 초기화 완료');
    } catch (e) {
      debugPrint('GroupController: 초기화 실패: $e');
      _setError('초기화에 실패했습니다: $e');
    }
  }

  // 로그아웃 시 모든 스트림 정리
  void onSignOut() {
    _groupSubscription?.cancel();
    _receivedInvitationsSubscription?.cancel();
    _sentInvitationsSubscription?.cancel();
    _reconnectTimer?.cancel();
    
    // 매칭 리스너도 모두 정리
    GroupService.stopAllMatchingListeners();
    
    _clearData();
  }

  // 정리
  @override
  void dispose() {
    onSignOut(); // onSignOut 로직을 그대로 사용
    super.dispose();
  }

  // 그룹 생성을 위한 프로필 완성도 체크 (서버 사이드 검증)
  bool _isProfileCompleteForGroupCreation(UserModel user) {
    // 1. 기본 회원 정보 확인
    if (user.phoneNumber.isEmpty ||
        user.birthDate.isEmpty ||
        user.gender.isEmpty) {
      return false;
    }
    
    // 2. 프로필 정보 확인 (그룹 생성을 위한 필수 정보)
    if (user.nickname.isEmpty ||
        user.introduction.isEmpty ||
        user.height <= 0 ||
        user.activityArea.isEmpty ||
        user.profileImages.isEmpty) {
      return false;
    }
    
    // 3. 프로필 완성 플래그 확인
    if (!user.isProfileComplete) {
      return false;
    }
    
    return true;
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 데이터 새로고침 (네트워크 오류 복구용)
  Future<void> refreshData() async {
    try {
      debugPrint('GroupController: 데이터 새로고침 시작');
      
      // 에러 상태 초기화
      _setError(null);
      _setLoading(true);

      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        _setError('로그인 정보가 없습니다. 다시 로그인해주세요.');
        _setLoading(false);
        _clearData(); // 로그아웃 상태이므로 데이터 클리어
        return;
      }

      // 현재 그룹 정보 다시 로드
      await loadCurrentGroup();
      
      // 초대 정보 다시 로드
      await _loadReceivedInvitations();
      await _loadSentInvitations();
      
      _setLoading(false);
      debugPrint('GroupController: 데이터 새로고침 완료');
      
    } catch (e) {
      debugPrint('GroupController: 데이터 새로고침 실패: $e');
      _setError('데이터 새로고침에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 앱이 포그라운드로 전환될 때 호출
  void onAppResumed() {
    debugPrint('GroupController: 앱 포그라운드 전환 감지');
    
    // 데이터 새로고침
    refreshData();
  }
}

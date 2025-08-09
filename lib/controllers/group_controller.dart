import 'package:flutter/material.dart';
import 'dart:async';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../services/firebase_service.dart';
import '../services/group_service.dart';
import '../services/invitation_service.dart';

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

      final group = await _groupService.createGroup(currentUserId);
      _currentGroup = group;
      await _loadGroupMembers();

      // 그룹 상태 실시간 감지 시작
      _startGroupStatusStream();

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

    // print('그룹 상태 스트림 시작: ${_currentGroup!.id}');

    // 기존 구독 취소
    _groupSubscription?.cancel();
    _reconnectTimer?.cancel();

    _groupStream = _groupService.getGroupStream(_currentGroup!.id);
    _groupSubscription = _groupStream!.listen(
      (group) {
        if (group != null) {
          final oldStatus = _currentGroup?.status;
          final oldMatchedGroupId = _currentGroup?.matchedGroupId;
          _currentGroup = group;

          // print('그룹 상태 업데이트: ${group.status}');
          if (group.matchedGroupId != null) {
            // print('매칭된 그룹 ID: ${group.matchedGroupId}');
          }

          // 매칭 완료 감지
          if (oldStatus == GroupStatus.matching &&
              group.status == GroupStatus.matched) {
            // print('매칭 완료 감지! 매칭된 그룹: ${group.matchedGroupId}');
            _handleMatchingCompleted();
          }

          // 매칭된 그룹이 변경된 경우 멤버 다시 로드
          if (oldMatchedGroupId != group.matchedGroupId) {
            // print('매칭된 그룹 변경 감지, 멤버 다시 로드');
            _loadGroupMembers();
          }

          notifyListeners();
        }
      },
      onError: (error) {
        // print('그룹 상태 스트림 오류: $error');
        _scheduleReconnect();
      },
      onDone: () {
        // print('그룹 상태 스트림 종료, 재연결 시도');
        _scheduleReconnect();
      },
    );
  }

  // 스트림 재연결 스케줄링
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      // print('그룹 스트림 재연결 시도');
      _startGroupStatusStream();
    });
  }

  // 매칭 완료 처리
  void _handleMatchingCompleted() {
    // print('매칭 완료 처리 시작');

    // UI 콜백 호출 (null 체크)
    if (onMatchingCompleted != null) {
      try {
        onMatchingCompleted!();
      } catch (e) {
        // print('매칭 완료 콜백 실행 중 오류: $e');
      }
    }

    // 그룹 멤버 다시 로드 (상대방 그룹 멤버 포함)
    _loadGroupMembers();

    // 잠시 후 한 번 더 로드 (Firestore 동기화 지연 대응)
    Future.delayed(const Duration(seconds: 2), () {
      // 컨트롤러가 여전히 유효한지 확인
      if (_currentGroup != null && _currentGroup!.status == GroupStatus.matched) {
        // print('매칭 완료 2초 후 추가 멤버 로드');
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
      _setError('초대 전송에 실패했습니다: $e');
      _setLoading(false);
      return false;
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
        // print('받은 초대 스트림 오류: $error');
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
        // print('보낸 초대 스트림 오류: $error');
        _setError('보낸 초대를 로드하는데 실패했습니다: $error');
      });
    } catch (e) {
      _setError('보낸 초대를 로드하는데 실패했습니다: $e');
    }
  }

  // 초대 수락
  Future<bool> acceptInvitation(String invitationId) async {
    try {
      _setLoading(true);
      _setError(null);

      final success = await _invitationService.respondToInvitation(
        invitationId,
        true,
      );

      if (success) {
        await loadCurrentGroup();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('초대 수락에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 초대 거절
  Future<bool> rejectInvitation(String invitationId) async {
    try {
      _setLoading(true);
      _setError(null);

      final success = await _invitationService.respondToInvitation(
        invitationId,
        false,
      );

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('초대 거절에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 현재 그룹 로드
  Future<void> loadCurrentGroup() async {
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId == null) return;

    try {
      _currentGroup = await _groupService.getUserCurrentGroup(currentUserId);
      if (_currentGroup != null) {
        await _loadGroupMembers();
        // 기존 그룹이 있을 때도 실시간 상태 감지 시작
        _startGroupStatusStream();
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
      
      // print('=== 매칭 시작 완료 ===');
      // print('그룹 ID: ${_currentGroup!.id}');
      // print('멤버 수: ${_currentGroup!.memberCount}');
      // print('==================');

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

      // print('그룹 나가기 시작: 그룹ID=${_currentGroup!.id}, 사용자ID=$currentUserId');

      final success = await _groupService.leaveGroup(
        _currentGroup!.id,
        currentUserId,
      );

      // print('그룹 나가기 결과: $success');

      if (success) {
        _clearData();
        // print('그룹 데이터 클리어 완료');
      }

      _setLoading(false);
      return success;
    } catch (e) {
      // print('그룹 나가기 오류: $e');
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

  // 초기화
  void initialize() {
    loadCurrentGroup();
    _loadReceivedInvitations();
    _loadSentInvitations();
  }

  // 수동 새로고침
  Future<void> refreshData() async {
    // print('수동 새로고침 시작');
    try {
      await loadCurrentGroup();
      await _loadReceivedInvitations();
      await _loadSentInvitations();
      // print('수동 새로고침 완료');
    } catch (e) {
      // print('수동 새로고침 실패: $e');
      _setError('데이터 새로고침에 실패했습니다: $e');
    }
  }

  // 포그라운드 복귀 시 자동 새로고침
  void onAppResumed() {
    // print('앱 포그라운드 복귀, 자동 새로고침');
    refreshData();

    // 스트림 재연결
    if (_currentGroup != null) {
      _startGroupStatusStream();
    }
  }

  // 로그아웃 시 모든 스트림 정리
  void onSignOut() {
    // print('로그아웃: 모든 스트림과 데이터 정리');
    _groupSubscription?.cancel();
    _receivedInvitationsSubscription?.cancel();
    _sentInvitationsSubscription?.cancel();
    _reconnectTimer?.cancel();
    
    // 매칭 리스너도 모두 정리
    GroupService.stopAllMatchingListeners();
    
    _clearData();
    // print('GroupController: 모든 스트림 정리 완료');
  }

  // 정리
  void dispose() {
    _groupSubscription?.cancel();
    _receivedInvitationsSubscription?.cancel();
    _sentInvitationsSubscription?.cancel();
    _reconnectTimer?.cancel();
    
    // 매칭 리스너도 모두 정리
    GroupService.stopAllMatchingListeners();
    
    _clearData();
    super.dispose();
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }
}

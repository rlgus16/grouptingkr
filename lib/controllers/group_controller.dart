import 'dart:async';
import 'package:flutter/material.dart';
import 'package:groupting/models/group_model.dart';
import 'package:groupting/models/invitation_model.dart';
import 'package:groupting/models/user_model.dart';
import 'package:groupting/services/firebase_service.dart';
import 'package:groupting/services/group_service.dart';
import 'package:groupting/services/invitation_service.dart';
import 'package:groupting/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final GroupService _groupService = GroupService();
  final InvitationService _invitationService = InvitationService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _errorMessage;
  GroupModel? _currentGroup;

  // [FIX] Track the specific group ID we are trying to load
  // This prevents race conditions between UserStream and GroupStream
  String? _targetGroupId;

  List<UserModel> _groupMembers = [];
  List<InvitationModel> _receivedInvitations = [];
  List<InvitationModel> _sentInvitations = [];
  List<String> _blockedUserIds = [];

  StreamSubscription<UserModel?>? _userStreamSubscription;
  StreamSubscription<GroupModel?>? _groupStreamSubscription;
  StreamSubscription<List<InvitationModel>>? _receivedInvitationsSubscription;
  StreamSubscription<List<InvitationModel>>? _sentInvitationsSubscription;

  VoidCallback? onMatchingCompleted;

  // 차단 목록 업데이트
  void updateBlockedUsers(List<String> blockedIds) {
    if (_blockedUserIds.length != blockedIds.length ||
        !_blockedUserIds.toSet().containsAll(blockedIds)) {
      _blockedUserIds = List.from(blockedIds);
      notifyListeners();
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GroupModel? get currentGroup => _currentGroup;
  List<UserModel> get groupMembers => _groupMembers.toList();

  List<InvitationModel> get receivedInvitations => _receivedInvitations
      .where((inv) => !_blockedUserIds.contains(inv.fromUserId))
      .toList();
  List<InvitationModel> get sentInvitations => _sentInvitations;

  bool get isMatching => _currentGroup?.status == GroupStatus.matching;
  bool get isMatched => _currentGroup?.status == GroupStatus.matched;

  bool get isOwner =>
      _currentGroup != null &&
          _currentGroup!.isOwner(_firebaseService.currentUserId ?? '');

  bool get canMatch =>
      _currentGroup != null &&
          !_currentGroup!.id.contains('_') &&
          isOwner;

  GroupController() {
    initialize();
  }

  Future<void> initialize() async {
    _setLoading(true);
    final userId = _firebaseService.currentUserId;
    if (userId == null) {
      _clearData();
      _setLoading(false);
      return;
    }

    await _loadInvitations();
    _startUserStream(userId);
  }

  void _startUserStream(String userId) {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = _userService.getUserStream(userId).listen(
          (user) {
        final newGroupId = user?.currentGroupId;

        if (newGroupId == null) {
          _targetGroupId = null; // [FIX] Reset target
          _groupStreamSubscription?.cancel();
          _currentGroup = null;
          _groupMembers.clear();
          _setLoading(false);
          notifyListeners();
          return;
        }

        // [FIX] Prevent unnecessary stream restarts
        if (newGroupId == _targetGroupId) {
          if (_currentGroup != null) _setLoading(false);
          return;
        }

        _setLoading(true);
        _startGroupStream(newGroupId);
      },
      onError: (error) => _setError('사용자 정보 스트림 오류: $error'),
    );
  }

  void _startGroupStream(String groupId) {
    _targetGroupId = groupId;

    _groupStreamSubscription?.cancel();
    _groupStreamSubscription = _groupService.getGroupStream(groupId).listen(
          (group) async {
        if (_targetGroupId != groupId) return;

        final oldStatus = _currentGroup?.status;
        _currentGroup = group;

        if (group != null) {
          await _loadGroupMembers();

          // 반드시 '매칭 중(matching)' 상태였던 경우에만 알림 발생
          if (oldStatus != null &&
              oldStatus == GroupStatus.matching &&
              group.status == GroupStatus.matched) {
            onMatchingCompleted?.call();
          }
        } else {
          _groupMembers.clear();
        }
        _setLoading(false);
        notifyListeners();
      },
      onError: (error) async {
        // 에러 처리 로직 유지
        final userId = _firebaseService.currentUserId;
        if (userId != null) {
          final user = await _userService.getUserById(userId);
          if (user?.currentGroupId != groupId) {
            return;
          }
        }
        _setError('그룹 정보 스트림 오류: $error');
      },
    );
  }

  Future<void> _loadGroupMembers() async {
    if (_currentGroup == null) return;
    try {
      _groupMembers = await _groupService.getGroupMembers(_currentGroup!.id);
    } catch (e) {
      _setError('그룹 멤버 로드 실패: $e');
    }
  }

  Future<void> _loadInvitations() async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return;

    _receivedInvitationsSubscription?.cancel();
    _receivedInvitationsSubscription =
        _invitationService.getReceivedInvitationsStream(userId).listen(
              (invitations) {
            _receivedInvitations = invitations;
            notifyListeners();
          },
          onError: (error) => _setError('받은 초대 로드 실패: $error'),
        );

    _sentInvitationsSubscription?.cancel();
    _sentInvitationsSubscription =
        _invitationService.getSentInvitationsStream(userId).listen(
              (invitations) {
            _sentInvitations = invitations;
            notifyListeners();
          },
          onError: (error) => _setError('보낸 초대 로드 실패: $error'),
        );
  }

  Future<void> refreshData() async {
    // [FIX] Clear error message on refresh so UI can recover from error state
    _errorMessage = null;
    _setLoading(true);

    final userId = _firebaseService.currentUserId;
    if (userId == null) {
      _clearData();
      _setLoading(false);
      return;
    }

    try {
      final user = await _userService.getUserById(userId);
      final groupId = user?.currentGroupId;
      if (groupId == null) {
        _clearGroupData();
        _setLoading(false);
        notifyListeners();
      } else {
        _startGroupStream(groupId);
      }
      await _loadInvitations();
    } catch (e) {
      _setError('새로고침 실패: $e');
    }
  }

  Future<bool> createGroup() async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) {
      _setError('로그인이 필요합니다.');
      return false;
    }
    try {
      _setLoading(true);
      final user = await _userService.getUserById(userId);
      if(user == null || !_isProfileCompleteForGroupCreation(user)) {
        _setError('그룹을 생성하려면 프로필을 완성해야 합니다.');
        return false;
      }
      await _groupService.createGroup(userId);
      return true;
    } catch (e) {
      _setError('그룹 생성 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

// 필터 설정 저장 메서드
  Future<bool> saveMatchFilters({
    required String preferredGender,
    required int minAge,
    required int maxAge,
    required int minHeight,
    required int maxHeight,
    required int maxDistance,
  }) async {
    if (_currentGroup == null) return false;

    try {
      // 안정성을 위해 필터 저장 시점에 그룹 멤버 정보를 새로 가져옵니다.
      final members = await _groupService.getGroupMembers(_currentGroup!.id);

      // 그룹 통계 다시 계산
      int totalAge = 0;
      int totalHeight = 0;
      int maleCount = 0;
      int femaleCount = 0;

      for (var member in members) {
        totalAge += member.age;
        totalHeight += member.height;
        if (member.gender == '남' || member.gender == '남자') {
          maleCount++;
        } else {
          femaleCount++;
        }
      }

      int averageAge = members.isEmpty ? 0 : (totalAge / members.length).round();
      int averageHeight = members.isEmpty ? 0 : (totalHeight / members.length).round();

      String groupGender = '혼성';
      if (maleCount > 0 && femaleCount == 0) {
        groupGender = '남자';
      } else if (femaleCount > 0 && maleCount == 0) {
        groupGender = '여자';
      }

      // Firebase에 필터 및 그룹 통계 업데이트
      await _groupService.updateGroupSettings(_currentGroup!.id, {
        'preferredGender': preferredGender,
        'minAge': minAge,
        'maxAge': maxAge,
        'minHeight': minHeight,
        'maxHeight': maxHeight,
        'maxDistance': maxDistance,
        'averageHeight': averageHeight,
        'groupGender': groupGender,
        'averageAge': averageAge,
      });

      return true;

    } catch (e) {
      debugPrint('필터 저장 실패: $e');
      return false;
    }
  }

  Future<bool> startMatching() async {
    if (_currentGroup == null) return false;
    _setLoading(true);
    try {
      // Calculate group stats on client-side before starting match
      final members = _groupMembers;
      
      // Calculate stats (only if we have members, which we should)
      Map<String, dynamic>? stats;
      
      if (members.isNotEmpty) {
        int totalAge = 0;
        int totalHeight = 0;
        int maleCount = 0;
        int femaleCount = 0;

        for (var member in members) {
          totalAge += member.age;
          totalHeight += member.height;
          if (member.gender == '남' || member.gender == '남자') {
            maleCount++;
          } else {
            femaleCount++;
          }
        }

        int averageAge = (totalAge / members.length).round();
        int averageHeight = (totalHeight / members.length).round();

        String groupGender = '혼성';
        if (maleCount > 0 && femaleCount == 0) {
          groupGender = '남자';
        } else if (femaleCount > 0 && maleCount == 0) {
          groupGender = '여자';
        }

        stats = {
          'averageAge': averageAge,
          'averageHeight': averageHeight,
          'groupGender': groupGender,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      await _groupService.startMatching(_currentGroup!.id, stats: stats);
      return true;
    } catch (e) {
      _setError('매칭 시작 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelMatching() async {
    if (_currentGroup == null) return false;
    _setLoading(true);
    try {
      await _groupService.cancelMatching(_currentGroup!.id);
      return true;
    } catch (e) {
      _setError('매칭 취소 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> leaveGroup() async {
    final userId = _firebaseService.currentUserId;
    if (_currentGroup == null || userId == null) return false;
    _setLoading(true);
    try {
      await _groupService.leaveGroup(_currentGroup!.id, userId);
      return true;
    } catch (e) {
      _setError('그룹 나가기 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> inviteFriend({required String phoneNumber, String? message}) async {
    if (currentGroup == null) return;

    try {
      await _invitationService.sendInvitation(
          groupId: currentGroup!.id,
          toUserPhoneNumber: phoneNumber,
          message: message
      );
      // Success: Function completes normally
    } catch(e) {
      // [FIX] Do NOT call _setError() here. It blocks the HomeView.
      // Instead, rethrow the friendly message so the UI can show a SnackBar.
      throw _getFriendlyErrorMessage(e.toString());
    }
  }

  Future<bool> cancelSentInvitation(String invitationId) async {
    try {
      return await _invitationService.cancelInvitation(invitationId);
    } catch (e) {
      _setError("초대 취소 실패: $e");
      return false;
    }
  }

  Future<bool> acceptInvitation(String invitationId) async {
    _setLoading(true);
    try {
      final invitation = await _invitationService.getInvitationById(invitationId);
      if (invitation == null) {
        // Logic error: throw to catch block
        throw "초대 정보를 찾을 수 없습니다.";
      }
      final success = await _invitationService.respondToInvitation(invitationId, true);
      if (success) {
        _startGroupStream(invitation.groupId);
      } else {
        _setLoading(false);
      }
      return success;
    } catch (e) {
      _setLoading(false);
      // [FIX] Do NOT set global _setError here.
      // Setting _errorMessage blocks the HomeView.
      // Instead, we rethrow the error so the UI (InvitationListView) can show a SnackBar.
      rethrow;
    }
  }

  Future<bool> rejectInvitation(String invitationId) async {
    try {
      return await _invitationService.respondToInvitation(invitationId, false);
    } catch (e) {
      // Reuse logic: simple return false or set error.
      // For rejection, it's less critical, but consistent behavior is good.
      _setError("초대 거절 실패: $e");
      return false;
    }
  }

  UserModel? getMemberById(String userId) {
    try {
      return _groupMembers.firstWhere((member) => member.uid == userId);
    } catch (e) {
      return null;
    }
  }

  void onAppResumed() {
    refreshData();
  }

  void onSignOut() {
    _clearData();
  }

  void _clearData() {
    _userStreamSubscription?.cancel();
    _groupStreamSubscription?.cancel();
    _receivedInvitationsSubscription?.cancel();
    _sentInvitationsSubscription?.cancel();
    _clearGroupData();
  }

  void _clearGroupData() {
    _currentGroup = null;
    _groupMembers.clear();
    _targetGroupId = null; // [FIX] Clear target ID
  }

  @override
  void dispose() {
    _clearData();
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    _setLoading(false);
    notifyListeners();
  }

  String _getFriendlyErrorMessage(String error) {
    if (error.contains('해당 사용자는 이미 다른 그룹에 속해있습니다')) {
      return '이미 다른 그룹에 참여 중인 친구예요';
    } else if (error.contains('해당 전화번호의 사용자를 찾을 수 없습니다')) {
      return '가입되지 않은 전화번호예요';
    } else if (error.contains('자기 자신에게는 초대를 보낼 수 없습니다')) {
      return '본인은 초대할 수 없어요';
    } else if (error.contains('그룹 인원이 가득 찼습니다')) {
      return '그룹 인원이 가득 찼어요 (최대 5명)';
    } else if (error.contains('그룹 방장만 초대를 보낼 수 있습니다')) {
      return '방장만 친구를 초대할 수 있어요';
    } else if (error.contains('이미 초대를 보냈습니다')) {
      return '이미 초대를 보낸 친구예요';
    } else {
      return '초대 전송에 실패했어요. 잠시 후 다시 시도해주세요.';
    }
  }

  bool _isProfileCompleteForGroupCreation(UserModel user) {
    return user.isProfileComplete &&
        user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty &&
        user.nickname.isNotEmpty &&
        user.introduction.isNotEmpty &&
        user.height > 0 &&
        user.activityArea.isNotEmpty &&
        user.profileImages.isNotEmpty;
  }
}

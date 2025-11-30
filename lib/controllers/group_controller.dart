import 'dart:async';
import 'package:flutter/material.dart';
import 'package:groupting/models/group_model.dart';
import 'package:groupting/models/invitation_model.dart';
import 'package:groupting/models/user_model.dart';
import 'package:groupting/services/firebase_service.dart';
import 'package:groupting/services/group_service.dart';
import 'package:groupting/services/invitation_service.dart';
import 'package:groupting/services/user_service.dart';

class GroupController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final GroupService _groupService = GroupService();
  final InvitationService _invitationService = InvitationService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _errorMessage;
  GroupModel? _currentGroup;
  List<UserModel> _groupMembers = [];
  List<InvitationModel> _receivedInvitations = [];
  List<InvitationModel> _sentInvitations = [];

  StreamSubscription<UserModel?>? _userStreamSubscription;
  StreamSubscription<GroupModel?>? _groupStreamSubscription;
  StreamSubscription<List<InvitationModel>>? _receivedInvitationsSubscription;
  StreamSubscription<List<InvitationModel>>? _sentInvitationsSubscription;

  VoidCallback? onMatchingCompleted;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GroupModel? get currentGroup => _currentGroup;
  List<UserModel> get groupMembers => _groupMembers;
  List<InvitationModel> get receivedInvitations => _receivedInvitations;
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
          _groupStreamSubscription?.cancel();
          _currentGroup = null;
          _groupMembers.clear();
          _setLoading(false);
          notifyListeners();
          return;
        }

        if (newGroupId != _currentGroup?.id) {
          _setLoading(true);
          _startGroupStream(newGroupId);
        } else {
          // CRITICAL FIX: If the group ID hasn't changed (e.g., already loaded via acceptInvitation),
          // we must manually turn off the loading state set by initialize().
          _setLoading(false);
        }
      },
      onError: (error) => _setError('사용자 정보 스트림 오류: $error'),
    );
  }

  void _startGroupStream(String groupId) {
    _groupStreamSubscription?.cancel();
    _groupStreamSubscription = _groupService.getGroupStream(groupId).listen(
          (group) async {
        final oldStatus = _currentGroup?.status;
        _currentGroup = group;
        if (group != null) {
          await _loadGroupMembers();

          // [FIX] Added (oldStatus != null) check.
          // This prevents the "Success" dialog from showing every time you open the app
          // if you are already matched. It will only show if you were previously
          // in a different state (like 'matching').
          if (oldStatus != null &&
              oldStatus != GroupStatus.matched &&
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
        // [Existing race condition fix preserved]
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
  
  Future<bool> startMatching() async {
    if (_currentGroup == null) return false;
    _setLoading(true);
    try {
      await _groupService.startMatching(_currentGroup!.id);
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
  
  Future<bool> inviteFriend({required String nickname, String? message}) async {
    if (currentGroup == null) return false;
    try {
      await _invitationService.sendInvitation(
        groupId: currentGroup!.id,
        toUserNickname: nickname,
        message: message
      );
      return true;
    } catch(e) {
      _setError(_getFriendlyErrorMessage(e.toString()));
      return false;
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
        _setError("초대 정보를 찾을 수 없습니다.");
        return false;
      }
      final success = await _invitationService.respondToInvitation(invitationId, true);
      if (success) {
        _startGroupStream(invitation.groupId);
      } else {
        _setLoading(false);
      }
      return success;
    } catch (e) {
      _setError("초대 수락 실패: $e");
      _setLoading(false);
      return false;
    }
  }
  
  Future<bool> rejectInvitation(String invitationId) async {
    try {
       return await _invitationService.respondToInvitation(invitationId, false);
    } catch (e) {
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

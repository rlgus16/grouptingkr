import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../services/firebase_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../services/realtime_chat_service.dart';

class ChatController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final MessageService _messageService = MessageService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final RealtimeChatService _realtimeChatService = RealtimeChatService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<MessageModel> _messages = [];
  List<UserModel> _matchedGroupMembers = [];
  Map<String, bool> _onlineUsers = {};
  final TextEditingController _messageController = TextEditingController();

  // Subscriptions
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  StreamSubscription<Map<String, bool>>? _onlineUsersSubscription;
  StreamSubscription<GroupModel?>? _groupSubscription;
  String? _currentGroupId;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MessageModel> get messages => _messages;
  List<UserModel> get matchedGroupMembers => _matchedGroupMembers;
  Map<String, bool> get onlineUsers => _onlineUsers;
  TextEditingController get messageController => _messageController;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 실시간 메시지 스트림 시작
  void startMessageStream(String groupId) {
    // print('ChatController: 메시지 스트림 시작 - groupId: $groupId');
    _setLoading(true);
    _currentGroupId = groupId;

    _startMessageStreamAsync(groupId);
  }

  // 비동기 메시지 스트림 시작
  Future<void> _startMessageStreamAsync(String groupId) async {
    try {
      // 기존 구독 해제
      _messagesSubscription?.cancel();
      _onlineUsersSubscription?.cancel();
      _groupSubscription?.cancel();

      // 채팅방 초기화
      // print('ChatController: 채팅방 초기화');
      await _realtimeChatService.initializeChatRoom(groupId);
      // print('ChatController: 채팅방 초기화 완료');

      // 그룹 상태 실시간 감지 시작
      _startGroupStatusListener(groupId);

      // 그룹 멤버 로드 (매칭 전/후 구분)
      await _loadGroupMembers();

      // 메시지 스트림 구독
      // print('ChatController: 메시지 스트림 구독 시작');
      _messagesSubscription = _realtimeChatService
          .getMessagesStream(groupId)
          .listen(
            (messages) {
              // print('ChatController: 메시지 수신됨 - ${messages.length}개');
              for (final msg in messages) {
                // print('- ${msg.senderNickname}: ${msg.content}');
              }
              _messages = messages;
              _setLoading(false);
              notifyListeners();
            },
            onError: (error) {
              // print('ChatController: 메시지 스트림 오류 - $error');
              _setError('메시지 로드에 실패했습니다: $error');
              _setLoading(false);
            },
          );

      // 온라인 사용자 기능 임시 비활성화
      // _onlineUsersSubscription = _realtimeChatService
      //     .getOnlineUsersStream(groupId)
      //     .listen(
      //       (onlineUsers) {
      //         _onlineUsers = onlineUsers;
      //         notifyListeners();
      //       },
      //       onError: (error) {
      //         print('온라인 사용자 로드 실패: $error');
      //       },
      //     );

      // // 현재 사용자를 온라인 상태로 설정
      // final currentUserId = _firebaseService.currentUserId;
      // if (currentUserId != null) {
      //   _realtimeChatService.setUserOnline(groupId, currentUserId);
      // }
    } catch (e) {
      _setError('메시지 스트림 시작에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 실시간 메시지 전송
  Future<bool> sendMessage() async {
    final content = _messageController.text.trim();
    // print('sendMessage 호출됨');
    // print('메시지 내용: "$content"');
    // print('현재 그룹 ID: $_currentGroupId');

    if (content.isEmpty) {
      // print('메시지 내용이 비어있음');
      return false;
    }

    if (_currentGroupId == null) {
      // print('현재 그룹 ID가 null');
      return false;
    }

    try {
      _setError(null);

      // print('메시지 전송 시도: $content');

      await _realtimeChatService.sendMessage(
        groupId: _currentGroupId!,
        content: content,
      );

      _messageController.clear();

      // 마지막 활동 시간 업데이트
      await _realtimeChatService.updateLastActivity(_currentGroupId!);

      // print('메시지 전송 성공');

      return true;
    } catch (e) {
      // print('메시지 전송 실패: $e');
      _setError('메시지 전송에 실패했습니다: $e');
      return false;
    }
  }

  // 내 메시지인지 확인
  bool isMyMessage(MessageModel message) {
    final currentUserId = _firebaseService.currentUserId;
    return currentUserId != null && message.senderId == currentUserId;
  }



  // 정리
  void clearData() {
    try {
      _messages.clear();
      _matchedGroupMembers.clear();
      _onlineUsers.clear();
      _messageController.clear();

      // 구독 해제
      _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _onlineUsersSubscription?.cancel();
      _onlineUsersSubscription = null;
      _groupSubscription?.cancel();
      _groupSubscription = null;

      // 오프라인 상태로 변경 (임시 비활성화)
      // if (_currentGroupId != null) {
      //   final currentUserId = _firebaseService.currentUserId;
      //   if (currentUserId != null) {
      //     _realtimeChatService.setUserOffline(_currentGroupId!, currentUserId);
      //   }
      // }

      _currentGroupId = null;
      notifyListeners();
    } catch (e) {
      // print('ChatController clearData 중 에러: $e');
    }
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 그룹 나가기/앱 종료 시 호출
  void stopMessageStream() {
    try {
      _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _onlineUsersSubscription?.cancel();
      _onlineUsersSubscription = null;
      _groupSubscription?.cancel();
      _groupSubscription = null;

      if (_currentGroupId != null) {
        final currentUserId = _firebaseService.currentUserId;
        if (currentUserId != null) {
          _realtimeChatService.setUserOffline(_currentGroupId!, currentUserId);
        }
      }
    } catch (e) {
      // print('ChatController stopMessageStream 중 에러: $e');
    }
  }

  // 그룹 상태 실시간 감지
  void _startGroupStatusListener(String groupId) {
    try {
      // print('ChatController: 그룹 상태 실시간 감지 시작');
      
      _groupSubscription = _groupService.getGroupStream(groupId).listen(
        (group) {
          if (group != null) {
            // print('ChatController: 그룹 상태 변경 감지 - 멤버수: ${group.memberCount}');
            
            // 그룹 멤버 변경 감지 시 멤버 목록 다시 로드
            _loadGroupMembers();
          } else {
            // print('ChatController: 그룹이 삭제되었거나 존재하지 않음');
            // 그룹이 삭제된 경우 채팅 종료
            clearData();
          }
        },
        onError: (error) {
          // print('ChatController: 그룹 상태 감지 오류 - $error');
        },
      );
    } catch (e) {
      // print('ChatController: 그룹 상태 리스너 시작 실패 - $e');
    }
  }

  // 그룹 멤버 로드 (매칭 전/후 구분)
  Future<void> _loadGroupMembers() async {
    try {
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) return;

      // 현재 사용자의 그룹 찾기
      final currentGroup = await _groupService.getUserCurrentGroup(
        currentUserId,
      );
      if (currentGroup == null) return;

      // print(
      //   'ChatController: 현재 그룹 - ${currentGroup.id}, 매칭 상태: ${currentGroup.status}',
      // );

      // 매칭 상태에 따라 다른 멤버 로드
      if (currentGroup.status == GroupStatus.matched) {
        // 매칭된 경우: 모든 그룹 멤버 로드 (자신 그룹 + 상대방 그룹)
        final allMembers = await _groupService.getGroupMembers(currentGroup.id);
        _matchedGroupMembers = allMembers;
        // print('ChatController: 매칭된 그룹 멤버 ${_matchedGroupMembers.length}명 로드');
        for (final member in _matchedGroupMembers) {
          // print('- ${member.nickname}');
        }
      } else {
        // 매칭 전: 현재 그룹 멤버만 로드
        final groupMembers = await Future.wait(
          currentGroup.memberIds.map((id) => _userService.getUserById(id)),
        );
        _matchedGroupMembers = groupMembers.whereType<UserModel>().toList();
        // print('ChatController: 현재 그룹 멤버 ${_matchedGroupMembers.length}명 로드');
        for (final member in _matchedGroupMembers) {
          // print('- ${member.nickname}');
        }
      }
      
      notifyListeners();
    } catch (e) {
      // print('ChatController: 그룹 멤버 로드 실패 - $e');
    }
  }

  // 로그아웃 시 모든 스트림 정리
  void onSignOut() {
    // print('로그아웃: ChatController 모든 스트림과 데이터 정리');
    stopMessageStream();
    _messages.clear();
    _matchedGroupMembers.clear();
    _onlineUsers.clear();
    _currentGroupId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopMessageStream();
    _messageController.dispose();
    super.dispose();
  }
}

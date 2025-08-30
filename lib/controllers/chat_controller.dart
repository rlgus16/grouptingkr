import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../services/chatroom_service.dart';
import '../models/chatroom_model.dart';

class ChatController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final ChatroomService _chatroomService = ChatroomService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<ChatMessage> _messages = [];
  List<UserModel> _matchedGroupMembers = [];
  final TextEditingController _messageController = TextEditingController();
  bool _disposed = false;

  // Subscriptions
  StreamSubscription<ChatroomModel?>? _chatroomSubscription;
  StreamSubscription<GroupModel?>? _groupSubscription;
  String? _currentGroupId;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => _messages;
  List<UserModel> get matchedGroupMembers => _matchedGroupMembers;
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
    _setLoading(true);
    _currentGroupId = groupId;

    _startMessageStreamAsync(groupId);
  }

  // 비동기 메시지 스트림 시작
  Future<void> _startMessageStreamAsync(String groupId) async {
    try {
      // 기존 구독 해제
      _chatroomSubscription?.cancel();
      _groupSubscription?.cancel();

      // 그룹 상태 실시간 감지 시작
      _startGroupStatusListener(groupId);

      // 그룹 멤버 로드 (매칭 전/후 구분)
      await _loadGroupMembers();

      // 실제 채팅방 ID 결정 (매칭된 경우 복합 ID 사용)
      final chatRoomId = await _getChatRoomId(groupId);
      
      // 현재 그룹 ID를 채팅방 ID로 업데이트
      _currentGroupId = chatRoomId;

      // 채팅방 스트림 구독 (새로운 구조)
      _chatroomSubscription = _chatroomService
          .getChatroomStream(chatRoomId)
          .listen(
            (chatroom) {
              if (!_disposed) {
                if (chatroom != null) {
                  _messages = chatroom.messages;
                } else {
                  _messages = [];
                }
                _setLoading(false);
              }
            },
            onError: (error) {
              if (!_disposed) {
                _setError('채팅방 로드에 실패했습니다: $error');
                _setLoading(false);
              }
            },
            );
    } catch (e) {
      _setError('채팅방 스트림 시작에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 실시간 메시지 전송
  Future<bool> sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return false;
    }

    if (_currentGroupId == null) {
      return false;
    }

    try {
      _setError(null);

      // 채팅방 서비스를 사용한 메시지 전송
      await _chatroomService.sendMessage(
        chatRoomId: _currentGroupId!,
        content: content,
      );

      _messageController.clear();

      return true;
    } catch (e) {
      _setError('메시지 전송에 실패했습니다: $e');
      return false;
    }
  }

  // 내 메시지인지 확인
  bool isMyMessage(ChatMessage message) {
    final currentUserId = _firebaseService.currentUserId;
    return currentUserId != null && message.senderId == currentUserId;
  }



  // 정리
  void clearData() {
    try {
      _messages.clear();
      _matchedGroupMembers.clear();
      // _onlineUsers.clear(); // Deprecated: 온라인 상태 관리 비활성화
      _messageController.clear();

      // 구독 해제
      _chatroomSubscription?.cancel();
      _chatroomSubscription = null;
      _groupSubscription?.cancel();
      _groupSubscription = null;

      _currentGroupId = null;
      
      // 즉시 UI 업데이트
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      // ChatController clearData 중 에러
    }
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 그룹 나가기/앱 종료 시 호출
  void stopMessageStream() {
    try {
      _chatroomSubscription?.cancel();
      _chatroomSubscription = null;
      _groupSubscription?.cancel();
      _groupSubscription = null;

      // Firestore에서는 온라인 상태 관리를 별도로 처리하지 않음
      // (필요 시 별도 구현)
      if (_currentGroupId != null) {
        final currentUserId = _firebaseService.currentUserId;
        if (currentUserId != null) {
          // _realtimeChatService.setUserOffline(_currentGroupId!, currentUserId); // Deprecated: Firestore로 전환됨
        }
      }
    } catch (e) {
      // ChatController stopMessageStream 중 에러
    }
  }

  // 그룹 상태 실시간 감지
  void _startGroupStatusListener(String groupId) {
    try {
      _groupSubscription = _groupService.getGroupStream(groupId).listen(
        (group) {
          if (!_disposed) {
            if (group != null) {
              // 그룹 멤버 변경 감지 시 멤버 목록 다시 로드
              _loadGroupMembers();
            } else {
              // 그룹이 삭제된 경우 채팅 종료
              clearData();
            }
          }
        },
        onError: (error) {
          debugPrint('ChatController: 그룹 상태 감지 오류 - $error');
        },
      );
    } catch (e) {
      debugPrint('ChatController: 그룹 상태 리스너 시작 실패 - $e');
    }
  }

  // 채팅방 ID 결정 (매칭된 경우 복합 ID 사용)
  Future<String> _getChatRoomId(String groupId) async {
    try {
      
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        return groupId;
      }

      // 현재 사용자의 그룹 찾기
      final currentGroup = await _groupService.getUserCurrentGroup(currentUserId);
      if (currentGroup == null) {
        return groupId;
      }

      // 매칭된 경우: 두 그룹 ID를 결합한 채팅방 ID 사용
      if (currentGroup.status == GroupStatus.matched && currentGroup.matchedGroupId != null) {
        final groupId1 = currentGroup.id;
        final groupId2 = currentGroup.matchedGroupId!;
        
        // 알파벳순으로 정렬하여 일관된 채팅방 ID 생성
        final chatRoomId = groupId1.compareTo(groupId2) < 0 
            ? '${groupId1}_${groupId2}'
            : '${groupId2}_${groupId1}';
        return chatRoomId;
      }
      
      // 매칭되지 않은 경우: 원래 그룹 ID 사용
      return groupId;
    } catch (e) {
      // 에러 발생 시 원래 그룹 ID 사용
      return groupId;
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

      // 매칭 상태에 따라 다른 멤버 로드
      if (currentGroup.status == GroupStatus.matched) {
        // 매칭된 경우: 모든 그룹 멤버 로드 (자신 그룹 + 상대방 그룹)
        final allMembers = await _groupService.getGroupMembers(currentGroup.id);
        _matchedGroupMembers = allMembers;
      } else {
        // 매칭 전: 현재 그룹 멤버만 로드
        final groupMembers = await Future.wait(
          currentGroup.memberIds.map((id) => _userService.getUserById(id)),
        );
        _matchedGroupMembers = groupMembers.whereType<UserModel>().toList();
      }
      // 즉시 UI 업데이트
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      // ChatController: 그룹 멤버 로드 실패
    }
  }

  // 로그아웃 시 모든 스트림 정리
  void onSignOut() {
    stopMessageStream();
    _messages.clear();
    _matchedGroupMembers.clear();
    // _onlineUsers.clear(); // Deprecated: 온라인 상태 관리 비활성화
    _currentGroupId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopMessageStream();
    _messageController.dispose();
    super.dispose();
  }
}

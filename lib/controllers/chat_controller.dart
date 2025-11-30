import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/chatroom_model.dart'; // ChatMessage, ChatroomModel import
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../services/chatroom_service.dart';
import '../utils/performance_monitor.dart';

class ChatController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final ChatroomService _chatroomService = ChatroomService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<ChatMessage> _messages = [];
  List<UserModel> _matchedGroupMembers = [];
  final TextEditingController _messageController = TextEditingController();
  bool _disposed = false;

  // 성능 최적화: 메시지 캐싱
  final Map<String, List<ChatMessage>> _messageCache = {};
  final Map<String, DateTime> _lastUpdateTime = {};
  Timer? _debounceTimer;

  // 성능 최적화 설정
  static const int _maxCachedMessages = 50;
  static const int _maxDisplayMessages = 100;
  static const Duration _updateDebounceDelay = Duration(milliseconds: 100);

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
  ChatroomService get chatroomService => _chatroomService;

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

  // 비동기 메시지 스트림 시작 - 성능 최적화 버전
  Future<void> _startMessageStreamAsync(String groupId) async {
    try {
      debugPrint('채팅방 스트림 시작: $groupId');

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

      debugPrint('채팅방 ID 결정: $chatRoomId');

      // [FIX START] 채팅방 문서가 없거나 참여자 목록이 최신이 아닐 경우를 대비해 동기화
      // 보안 규칙이 업데이트되었으므로, 그룹 멤버라면 이 쓰기 작업이 허용됩니다.
      if (_matchedGroupMembers.isNotEmpty) {
        final participantIds = _matchedGroupMembers.map((m) => m.uid).toList();
        await _chatroomService.getOrCreateChatroom(
          chatRoomId: chatRoomId,
          groupId: chatRoomId,
          participants: participantIds,
        );
      }
      // [FIX END]

      // 1. 먼저 기존 채팅방 데이터 즉시 로드 (캐시된 데이터) - 제한된 개수
      try {
        final existingChatroom = await _chatroomService.getChatroomStream(chatRoomId).first;
        if (!_disposed && existingChatroom != null) {
          // 최근 30개 메시지만 로드 (성능 최적화)
          final recentMessages = existingChatroom.messages.length > 30
              ? existingChatroom.messages.sublist(existingChatroom.messages.length - 30)
              : existingChatroom.messages;
          _messages = recentMessages;
          _setLoading(false);
          debugPrint('기존 메시지 즉시 로드: ${_messages.length}개 (최근 30개)');
        }
      } catch (initialLoadError) {
        debugPrint('초기 메시지 로드 실패 (스트림으로 재시도): $initialLoadError');
      }

      // 2. 실시간 스트림 구독 (새로운 메시지 업데이트) - 성능 최적화
      _startChatroomStream(chatRoomId);

      debugPrint('채팅방 스트림 구독 완료');
    } catch (e) {
      debugPrint('채팅방 스트림 시작 실패: $e');
      _setError('채팅방 스트림 시작에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 채팅방 스트림 시작 (성능 최적화된 버전)
  void _startChatroomStream(String chatRoomId) {
    debugPrint('채팅방 스트림 시작: $chatRoomId');

    _chatroomSubscription = _chatroomService
        .getChatroomStream(chatRoomId)
        .listen(
          (chatroom) {
        if (!_disposed) {
          _handleChatroomUpdate(chatroom, chatRoomId);
        }
      },
      onError: (error) {
        if (!_disposed) {
          debugPrint('채팅방 스트림 에러: $error');
          _setError('채팅방 로드에 실패했습니다: $error');
          _setLoading(false);
        }
      },
    );
  }

  // 채팅방 업데이트 처리 (디바운싱 적용)
  void _handleChatroomUpdate(ChatroomModel? chatroom, String chatRoomId) {
    if (chatroom == null) {
      _messages = [];
      _setLoading(false);
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final lastUpdate = _lastUpdateTime[chatRoomId];

    // 너무 빈번한 업데이트 방지 (100ms 디바운싱)
    if (lastUpdate != null && now.difference(lastUpdate) < _updateDebounceDelay) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_updateDebounceDelay, () {
        if (!_disposed) {
          _processChatroomUpdate(chatroom, chatRoomId);
        }
      });
      return;
    }

    _processChatroomUpdate(chatroom, chatRoomId);
  }

  // 실제 채팅방 업데이트 처리 (성능 최적화 포함)
  void _processChatroomUpdate(ChatroomModel chatroom, String chatRoomId) {
    final now = DateTime.now();
    _lastUpdateTime[chatRoomId] = now;

    // 성능 모니터링: UI 업데이트 기록
    _performanceMonitor.recordUIUpdate('ChatController_Update');

    final newMessageCount = chatroom.messages.length;
    final oldMessageCount = _messages.length;

    // 새 메시지 수신 시 성능 측정 (안전한 범위 체크)
    if (newMessageCount > oldMessageCount && oldMessageCount >= 0) {
      try {
        final newMessages = chatroom.messages.length > oldMessageCount
            ? chatroom.messages.sublist(oldMessageCount)
            : <ChatMessage>[];

        for (final message in newMessages) {
          _performanceMonitor.recordMessageReceived(message.id, message.createdAt);
        }
      } catch (e) {
        // 오류 로그
      }
    }

    // 성능 최적화: 표시할 메시지 수 제한
    final messagesToDisplay = chatroom.messages.length > _maxDisplayMessages
        ? chatroom.messages.sublist(chatroom.messages.length - _maxDisplayMessages)
        : chatroom.messages;

    // 캐시 업데이트 (안전한 범위 체크)
    try {
      final messagesToCache = chatroom.messages.length > _maxCachedMessages
          ? chatroom.messages.sublist(chatroom.messages.length - _maxCachedMessages)
          : chatroom.messages;
      _messageCache[chatRoomId] = messagesToCache;
    } catch (e) {
      // 오류 로그
    }

    _messages = messagesToDisplay;

    if (newMessageCount > oldMessageCount) {
      debugPrint('새 메시지 수신: ${newMessageCount - oldMessageCount}개 (표시: ${_messages.length}개)');
    }

    // 성능 모니터링: 메모리 사용량 체크 (안전하게)
    try {
      _performanceMonitor.checkMemoryUsage();
    } catch (e) {
      // 오류 로그
    }

    _setLoading(false);
    notifyListeners();
  }

  // 실시간 메시지 전송 (성능 모니터링 포함)
  Future<bool> sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return false;
    }

    if (_currentGroupId == null) {
      return false;
    }

    // 성능 모니터링: 메시지 전송 시간 측정 시작
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final stopwatch = _performanceMonitor.startMessageSend(messageId);

    try {
      _setError(null);

      // 채팅방 서비스를 사용한 메시지 전송
      await _chatroomService.sendMessage(
        chatRoomId: _currentGroupId!,
        content: content,
      );

      // 성능 모니터링: 메시지 전송 완료 기록
      _performanceMonitor.recordMessageSent(messageId, stopwatch);

      _messageController.clear();

      return true;
    } catch (e) {
      // 전송 실패 시에도 시간 기록 (디버깅용)
      stopwatch.stop();
      // 오류 로그

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
  void clearData({bool fromDispose = false}) {
    try {
      _messages.clear();
      _matchedGroupMembers.clear();
      _messageController.clear();

      // 구독 해제
      _chatroomSubscription?.cancel();
      _chatroomSubscription = null;
      _groupSubscription?.cancel();
      _groupSubscription = null;

      _currentGroupId = null;

      // dispose 중이 아닐 때만 UI 업데이트
      if (!_disposed && !fromDispose) {
        // 위젯 트리가 안정된 후 UI 업데이트
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) {
            notifyListeners();
          }
        });
      }
    } catch (e) {
      // 오류 로그
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

      if (_currentGroupId != null) {
        final currentUserId = _firebaseService.currentUserId;
        if (currentUserId != null) {
          // 오프라인 상태 처리 (필요시 구현)
        }
      }
    } catch (e) {
      // ChatController stopMessageStream 중 에러
    }
  }

  // 그룹 상태 실시간 감지 - 매칭 상태 변경 감지 개선
  void _startGroupStatusListener(String groupId) {
    try {
      _groupSubscription = _groupService.getGroupStream(groupId).listen(
            (group) async {
          if (!_disposed && group != null) {

            // 매칭 상태 변경 감지 - 채팅방 ID 재계산 및 스트림 재시작
            final newChatRoomId = await _getChatRoomId(groupId);

            if (_currentGroupId != newChatRoomId) {
              // 기존 채팅방 스트림 중단
              _chatroomSubscription?.cancel();
              _currentGroupId = newChatRoomId;

              // 새로운 채팅방 스트림 시작
              _startChatroomStream(newChatRoomId);
            }

            // 그룹 멤버 변경 감지 시 멤버 목록 다시 로드
            await _loadGroupMembers();
          } else if (!_disposed && group == null) {
            // 그룹이 삭제된 경우 채팅 종료
            clearData();
          }
        },
        onError: (error) {
          // 오류 로그
        },
      );
    } catch (e) {
      // 오류 로그
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

  // 그룹 멤버 로드 (매칭 전/후 구분) - 개선된 버전
  Future<void> _loadGroupMembers() async {
    try {
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) return;

      // 현재 사용자의 그룹 찾기
      final currentGroup = await _groupService.getUserCurrentGroup(currentUserId);
      if (currentGroup == null) return;

      // 매칭 상태에 따라 다른 멤버 로드
      if (currentGroup.status == GroupStatus.matched && currentGroup.matchedGroupId != null) {
        // 매칭된 경우: 두 그룹의 모든 멤버 로드

        // 현재 그룹 멤버들
        final currentGroupMembers = await Future.wait(
          currentGroup.memberIds.map((id) => _userService.getUserById(id)),
        );

        // 매칭된 그룹 멤버들
        final matchedGroup = await _groupService.getGroupById(currentGroup.matchedGroupId!);
        List<UserModel> matchedGroupMembers = [];

        if (matchedGroup != null) {
          final matchedMembers = await Future.wait(
            matchedGroup.memberIds.map((id) => _userService.getUserById(id)),
          );
          matchedGroupMembers = matchedMembers.whereType<UserModel>().toList();
        }

        // 두 그룹의 모든 멤버 합치기 (중복 제거)
        final allMemberIds = <String>{
          ...currentGroup.memberIds,
          ...?matchedGroup?.memberIds,
        };

        final allMembers = [
          ...currentGroupMembers.whereType<UserModel>(),
          ...matchedGroupMembers,
        ];

        // 중복 제거 (UID 기준)
        final uniqueMembers = <String, UserModel>{};
        for (final member in allMembers) {
          uniqueMembers[member.uid] = member;
        }

        _matchedGroupMembers = uniqueMembers.values.toList();

        debugPrint('매칭된 그룹 멤버 로드 완료: ${_matchedGroupMembers.length}명');
      } else {
        // 매칭 전: 현재 그룹 멤버만 로드
        final groupMembers = await Future.wait(
          currentGroup.memberIds.map((id) => _userService.getUserById(id)),
        );
        _matchedGroupMembers = groupMembers.whereType<UserModel>().toList();
        debugPrint('현재 그룹 멤버 로드: ${_matchedGroupMembers.length}명 (매칭 전)');
      }

      // 즉시 UI 업데이트
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      // 오류 로그
    }
  }

  // 성능 통계 출력 (개발 모드에서만)
  void printPerformanceStats() {
    if (_currentGroupId != null) {
      _performanceMonitor.printChatPerformanceStats(_currentGroupId!);

      final warnings = _performanceMonitor.getPerformanceWarnings();
      if (warnings.isNotEmpty) {
        // 오류 로그
      }
    }
  }

  // 로그아웃 시 모든 스트림 정리 + 캐시 청소
  void onSignOut() {
    // 성능 통계 출력
    printPerformanceStats();

    stopMessageStream();
    _messages.clear();
    _matchedGroupMembers.clear();
    _messageCache.clear(); // 캐시 청소
    _performanceMonitor.reset(); // 성능 모니터 초기화
    _currentGroupId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel(); // 디바운스 타이머 정리
    stopMessageStream();
    _messageController.dispose();
    _messageCache.clear(); // 메모리 누수 방지
    _lastUpdateTime.clear(); // 업데이트 시간 캐시 정리
    super.dispose();
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/chatroom_model.dart';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../services/chatroom_service.dart';
import '../utils/performance_monitor.dart';

class ChatController extends ChangeNotifier {
  // Services
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final ChatroomService _chatroomService = ChatroomService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  // Constants
  static const int _maxCachedMessages = 50;
  static const int _maxDisplayMessages = 100;
  static const Duration _updateDebounceDelay = Duration(milliseconds: 100);

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<ChatMessage> _messages = [];
  List<UserModel> _matchedGroupMembers = [];
  final TextEditingController _messageController = TextEditingController();
  bool _disposed = false;
  String? _currentGroupId;

  // Cache & Performance
  final Map<String, List<ChatMessage>> _messageCache = {};
  final Map<String, DateTime> _lastUpdateTime = {};
  Timer? _debounceTimer;

  // Subscriptions
  StreamSubscription<ChatroomModel?>? _chatroomSubscription;
  StreamSubscription<GroupModel?>? _groupSubscription;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => _messages;
  List<UserModel> get matchedGroupMembers => _matchedGroupMembers;
  TextEditingController get messageController => _messageController;
  ChatroomService get chatroomService => _chatroomService;

  // --- Initialization & Stream Management ---

  void startMessageStream(String groupId) {
    _setLoading(true);
    _currentGroupId = groupId;
    _startMessageStreamAsync(groupId);
  }

  Future<void> _startMessageStreamAsync(String groupId) async {
    try {
      debugPrint('Chat stream started: $groupId');
      _cancelSubscriptions();

      // 1. Listen for group status changes (e.g. matching completed)
      _startGroupStatusListener(groupId);

      // 2. Load members based on current group status
      await _loadGroupMembers();

      // 3. Resolve the actual ChatRoom ID (handles matched groups)
      final chatRoomId = await _getChatRoomId(groupId);
      _currentGroupId = chatRoomId;
      debugPrint('ChatRoom ID resolved: $chatRoomId');

      // 4. Ensure chatroom document exists and participant list is up-to-date
      await _syncChatroomParticipants(chatRoomId);

      // 5. Load initial data from cache or single fetch for speed
      await _loadInitialMessages(chatRoomId);

      // 6. Start real-time stream
      _startChatroomStream(chatRoomId);

      debugPrint('Chat stream setup completed');
    } catch (e) {
      debugPrint('Failed to start chat stream: $e');
      _setError('Failed to load chat room: $e');
      _setLoading(false);
    }
  }

  void _startChatroomStream(String chatRoomId) {
    _chatroomSubscription = _chatroomService
        .getChatroomStream(chatRoomId)
        .listen(
          (chatroom) {
        if (!_disposed) _handleChatroomUpdate(chatroom, chatRoomId);
      },
      onError: (error) {
        if (!_disposed) {
          debugPrint('Chatroom stream error: $error');
          _setError('Failed to load chat room data: $error');
          _setLoading(false);
        }
      },
    );
  }

  Future<void> _syncChatroomParticipants(String chatRoomId) async {
    if (_matchedGroupMembers.isEmpty) return;

    try {
      final participantIds = _matchedGroupMembers.map((m) => m.uid).toList();
      await _chatroomService.getOrCreateChatroom(
        chatRoomId: chatRoomId,
        groupId: chatRoomId,
        participants: participantIds,
      );
    } catch (e) {
      // Log warning but don't block UI; read permissions might still work
      debugPrint('Participant sync warning: $e');
    }
  }

  Future<void> _loadInitialMessages(String chatRoomId) async {
    try {
      final existingChatroom = await _chatroomService.getChatroomStream(chatRoomId).first;
      if (!_disposed && existingChatroom != null) {
        // Optimization: Load only recent messages initially
        final allMsgs = existingChatroom.messages;
        _messages = allMsgs.length > 30
            ? allMsgs.sublist(allMsgs.length - 30)
            : allMsgs;
        _setLoading(false);
        debugPrint('Initial messages loaded: ${_messages.length}');
      }
    } catch (e) {
      debugPrint('Initial load failed (will rely on stream): $e');
    }
  }

  void _handleChatroomUpdate(ChatroomModel? chatroom, String chatRoomId) {
    if (chatroom == null) {
      _messages = [];
      _setLoading(false);
      notifyListeners();
      return;
    }

    // Debounce updates to prevent UI stutter on rapid messages
    final now = DateTime.now();
    final lastUpdate = _lastUpdateTime[chatRoomId];

    if (lastUpdate != null && now.difference(lastUpdate) < _updateDebounceDelay) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_updateDebounceDelay, () {
        if (!_disposed) _processChatroomUpdate(chatroom, chatRoomId);
      });
      return;
    }

    _processChatroomUpdate(chatroom, chatRoomId);
  }

  void _processChatroomUpdate(ChatroomModel chatroom, String chatRoomId) {
    final now = DateTime.now();
    _lastUpdateTime[chatRoomId] = now;
    _performanceMonitor.recordUIUpdate('ChatController_Update');

    // Performance: Limit displayed messages
    final messagesToDisplay = chatroom.messages.length > _maxDisplayMessages
        ? chatroom.messages.sublist(chatroom.messages.length - _maxDisplayMessages)
        : chatroom.messages;

    // Cache recent messages
    try {
      final messagesToCache = chatroom.messages.length > _maxCachedMessages
          ? chatroom.messages.sublist(chatroom.messages.length - _maxCachedMessages)
          : chatroom.messages;
      _messageCache[chatRoomId] = messagesToCache;
    } catch (e) {
      // Ignore cache errors
    }

    _messages = messagesToDisplay;
    _setLoading(false);
    notifyListeners();
  }

  // --- Group & Member Management ---

  Future<void> _loadGroupMembers() async {
    try {
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) return;

      final currentGroup = await _groupService.getUserCurrentGroup(currentUserId);
      if (currentGroup == null) return;

      if (currentGroup.status == GroupStatus.matched && currentGroup.matchedGroupId != null) {
        await _loadMatchedGroupMembers(currentGroup);
      } else {
        await _loadSingleGroupMembers(currentGroup);
      }

      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('Error loading group members: $e');
    }
  }

  Future<void> _loadMatchedGroupMembers(GroupModel currentGroup) async {
    // 1. Load current group members
    final currentGroupMembers = await _fetchUsers(currentGroup.memberIds);

    // 2. Load matched group members
    final matchedGroup = await _groupService.getGroupById(currentGroup.matchedGroupId!);
    final matchedGroupMembers = matchedGroup != null
        ? await _fetchUsers(matchedGroup.memberIds)
        : <UserModel>[];

    // 3. Combine and deduplicate
    final uniqueMembers = <String, UserModel>{};
    for (var m in [...currentGroupMembers, ...matchedGroupMembers]) {
      uniqueMembers[m.uid] = m;
    }

    _matchedGroupMembers = uniqueMembers.values.toList();
    debugPrint('Loaded ${_matchedGroupMembers.length} members (Matched Mode)');
  }

  Future<void> _loadSingleGroupMembers(GroupModel currentGroup) async {
    _matchedGroupMembers = await _fetchUsers(currentGroup.memberIds);
    debugPrint('Loaded ${_matchedGroupMembers.length} members (Single Mode)');
  }

  Future<List<UserModel>> _fetchUsers(List<String> ids) async {
    final users = await Future.wait(ids.map((id) => _userService.getUserById(id)));
    return users.whereType<UserModel>().toList();
  }

  void _startGroupStatusListener(String groupId) {
    _groupSubscription = _groupService.getGroupStream(groupId).listen(
          (group) async {
        if (!_disposed && group != null) {
          final newChatRoomId = await _getChatRoomId(groupId);

          // Restart stream if chat room ID changes (e.g. Matched)
          if (_currentGroupId != newChatRoomId) {
            _chatroomSubscription?.cancel();
            _currentGroupId = newChatRoomId;
            _startChatroomStream(newChatRoomId);
          }
          await _loadGroupMembers();
        } else if (!_disposed && group == null) {
          clearData(); // Group deleted
        }
      },
      onError: (e) => debugPrint('Group status stream error: $e'),
    );
  }

  Future<String> _getChatRoomId(String groupId) async {
    try {
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) return groupId;

      final currentGroup = await _groupService.getUserCurrentGroup(currentUserId);
      if (currentGroup == null) return groupId;

      // Logic for composite ID when matched
      if (currentGroup.status == GroupStatus.matched && currentGroup.matchedGroupId != null) {
        final id1 = currentGroup.id;
        final id2 = currentGroup.matchedGroupId!;
        return id1.compareTo(id2) < 0 ? '${id1}_$id2' : '${id2}_$id1';
      }
      return groupId;
    } catch (e) {
      return groupId;
    }
  }

  // --- Messaging Actions ---

  Future<bool> sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentGroupId == null) return false;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final stopwatch = _performanceMonitor.startMessageSend(messageId);

    try {
      _setError(null);
      await _chatroomService.sendMessage(
        chatRoomId: _currentGroupId!,
        content: content,
      );

      _performanceMonitor.recordMessageSent(messageId, stopwatch);
      _messageController.clear();
      return true;
    } catch (e) {
      stopwatch.stop();
      _setError('Failed to send message: $e');
      return false;
    }
  }

  bool isMyMessage(ChatMessage message) {
    return _firebaseService.currentUserId != null &&
        message.senderId == _firebaseService.currentUserId;
  }

  // --- Cleanup & Helpers ---

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() => _setError(null);

  void _cancelSubscriptions() {
    _chatroomSubscription?.cancel();
    _chatroomSubscription = null;
    _groupSubscription?.cancel();
    _groupSubscription = null;
  }

  void clearData({bool fromDispose = false}) {
    _messages.clear();
    _matchedGroupMembers.clear();
    _messageController.clear();
    _cancelSubscriptions();
    _currentGroupId = null;

    if (!_disposed && !fromDispose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  void stopMessageStream() => _cancelSubscriptions();

  void onSignOut() {
    if (_currentGroupId != null) {
      _performanceMonitor.printChatPerformanceStats(_currentGroupId!);
    }
    stopMessageStream();
    _messages.clear();
    _matchedGroupMembers.clear();
    _messageCache.clear();
    _performanceMonitor.reset();
    _currentGroupId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    stopMessageStream();
    _messageController.dispose();
    _messageCache.clear();
    _lastUpdateTime.clear();
    super.dispose();
  }
}
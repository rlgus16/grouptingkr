import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/custom_toast.dart';
import '../widgets/member_avatar.dart';
import '../widgets/message_bubble.dart';
import '../models/user_model.dart';
import '../models/chatroom_model.dart';
import '../models/message_model.dart';
import 'profile_detail_view.dart';

class OpentingView extends StatefulWidget {
  const OpentingView({super.key});

  @override
  State<OpentingView> createState() => _OpentingViewState();
}

class _OpentingViewState extends State<OpentingView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _joiningRooms = <String>{};
  int _selectedMaxParticipants = 10;
  
  // Current chatroom state
  String? _currentChatroomId;
  Map<String, dynamic>? _currentChatroomData;
  List<UserModel> _chatroomMembers = [];
  bool _isLoadingMembers = false;
  
  // Chat state
  List<ChatMessage> _messages = [];
  Map<String, UserModel> _userProfiles = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentChatroom();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showCreateRoomDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Create Open Chatroom'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room Title',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter room title',
                        hintStyle: const TextStyle(color: AppTheme.gray400),
                        filled: true,
                        fillColor: AppTheme.gray50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Max Participants',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMaxParticipants,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.gray600),
                          items: List.generate(9, (index) => index + 2)
                              .map((number) => DropdownMenuItem<int>(
                                    value: number,
                                    child: Text(
                                      '$number participants',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMaxParticipants = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () {
                    _titleController.clear();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppTheme.gray600),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () async {
                    if (_titleController.text.trim().isEmpty) {
                      CustomToast.showError(context, 'Please enter a room title');
                      return;
                    }
                    Navigator.pop(context);
                    await _createOpenChatroom();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createOpenChatroom() async {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;

    if (currentUser == null) {
      if (mounted) {
        CustomToast.showError(context, 'Please login first');
      }
      return;
    }

    // Leave current chatroom if in one
    if (_currentChatroomId != null) {
      await _leaveChatroom();
      // Wait a bit for the leave operation to complete
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      final now = DateTime.now();
      final chatroomData = {
        'title': _titleController.text.trim(),
        'creatorId': currentUser.uid,
        'creatorNickname': currentUser.nickname ?? 'Unknown',
        'participants': [currentUser.uid],
        'participantCount': 1,
        'maxParticipants': _selectedMaxParticipants,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isActive': true,
      };

      await _firestore.collection('openChatrooms').add(chatroomData);

      _titleController.clear();

      // Reload current chatroom to show the newly created one
      await _loadCurrentChatroom();

      if (mounted) {
        CustomToast.showSuccess(context, 'Open chatroom created successfully!');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, 'Failed to create chatroom: $e');
      }
    }
  }

  Future<void> _joinChatroom(String roomId, List<dynamic> participants, String title, int participantCount, int maxParticipants) async {
    if (_joiningRooms.contains(roomId)) return;

    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;

    if (currentUser == null) {
      if (mounted) {
        CustomToast.showError(context, 'Please login first');
      }
      return;
    }

    if (participants.contains(currentUser.uid)) {
      // Already joined, reload current chatroom view
      if (mounted) {
        await _loadCurrentChatroom();
      }
      return;
    }

    // Check if chatroom is full
    if (participantCount >= maxParticipants) {
      if (mounted) {
        CustomToast.showError(context, 'Chatroom is full ($maxParticipants/$maxParticipants)');
      }
      return;
    }

    // Leave current chatroom if in one
    if (_currentChatroomId != null) {
      await _leaveChatroom();
      // Wait a bit for the leave operation to complete
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _joiningRooms.add(roomId);
    });

    try {
      await _firestore.collection('openChatrooms').doc(roomId).update({
        'participants': FieldValue.arrayUnion([currentUser.uid]),
        'participantCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        CustomToast.showSuccess(context, 'Joined chatroom successfully!');
        
        // Reload current chatroom to show member view
        await _loadCurrentChatroom();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, 'Failed to join chatroom: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _joiningRooms.remove(roomId);
        });
      }
    }
  }

  Future<void> _loadCurrentChatroom() async {
    final authController = context.read<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    if (currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('openChatrooms')
          .where('participants', arrayContains: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final doc = snapshot.docs.first;
        setState(() {
          _currentChatroomId = doc.id;
          _currentChatroomData = doc.data();
        });
        await _loadChatroomMembers();
        _listenToMessages(); // Start listening to messages
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadChatroomMembers() async {
    if (_currentChatroomData == null) return;

    setState(() {
      _isLoadingMembers = true;
    });

    try {
      final participants = List<String>.from(_currentChatroomData!['participants'] ?? []);
      final List<UserModel> members = [];

      for (final participantId in participants) {
        try {
          final userDoc = await _firestore.collection('users').doc(participantId).get();
          if (userDoc.exists) {
            members.add(UserModel.fromFirestore(userDoc));
          }
        } catch (e) {
          // Skip failed user loads
        }
      }

      if (mounted) {
        setState(() {
          _chatroomMembers = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  void _listenToMessages() {
    if (_currentChatroomId == null) return;
    
    _firestore
        .collection('openChatrooms')
        .doc(_currentChatroomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null && data['messages'] != null) {
          final messagesData = List<Map<String, dynamic>>.from(data['messages']);
          setState(() {
            _messages = messagesData
                .map((msgData) => ChatMessage.fromMap(
                      msgData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      msgData,
                    ))
                .toList();
          });
          
          // Fetch profiles for message senders
          _fetchUserProfiles();
          
          // Auto scroll to bottom when new message arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  Future<void> _fetchUserProfiles() async {
    final senderIds = _messages.map((m) => m.senderId).toSet();
    
    for (final senderId in senderIds) {
      if (!_userProfiles.containsKey(senderId) && senderId != 'system') {
        try {
          final userDoc = await _firestore.collection('users').doc(senderId).get();
          if (userDoc.exists && mounted) {
            setState(() {
              _userProfiles[senderId] = UserModel.fromFirestore(userDoc);
            });
          }
        } catch (e) {
          // Ignore profile fetch errors
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentChatroomId == null) return;

    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;

    if (currentUser == null) return;

    try {
      final newMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: currentUser.uid,
        senderNickname: currentUser.nickname,
        content: messageText,
        type: MessageType.text,
        createdAt: DateTime.now(),
        readBy: [currentUser.uid],
        senderProfileImage: currentUser.mainProfileImage,
      );

      await _firestore.collection('openChatrooms').doc(_currentChatroomId).update({
        'messages': FieldValue.arrayUnion([newMessage.toMap()]),
        'lastMessage': newMessage.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, 'Failed to send message: $e');
      }
    }
  }

  Future<void> _leaveChatroom() async {
    if (_currentChatroomId == null) return;

    final authController = context.read<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    if (currentUserId == null) return;

    try {
      final chatroomRef = _firestore.collection('openChatrooms').doc(_currentChatroomId);
      final chatroomDoc = await chatroomRef.get();
      
      if (!chatroomDoc.exists) return;

      final data = chatroomDoc.data()!;
      final participantCount = data['participantCount'] ?? 0;

      // If user is the last participant, delete the chatroom entirely
      if (participantCount <= 1) {
        await chatroomRef.delete();
      } else {
        // Otherwise, just remove the user from participants
        await chatroomRef.update({
          'participants': FieldValue.arrayRemove([currentUserId]),
          'participantCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        setState(() {
          _currentChatroomId = null;
          _currentChatroomData = null;
          _chatroomMembers = [];
          _messages = [];
          _userProfiles = {};
        });
        CustomToast.showSuccess(context, 'Left chatroom successfully!');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, 'Failed to leave chatroom: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.watch<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: const Text('오픈팅'),
        backgroundColor: AppTheme.gray50,
        scrolledUnderElevation: 0,
      ),
      body: _currentChatroomId != null
          ? _buildCurrentChatroomView(l10n, authController)
          : _buildChatroomListView(l10n, currentUserId),
      floatingActionButton: _currentChatroomId == null
          ? FloatingActionButton.extended(
              onPressed: _showCreateRoomDialog,
              backgroundColor: AppTheme.primaryColor,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Create Room',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard',
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildChatroomListView(AppLocalizations l10n, String? currentUserId) {
    return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('openChatrooms')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState('Error loading chatrooms');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          }

          final chatrooms = snapshot.data?.docs ?? [];

          if (chatrooms.isEmpty) {
            return _buildEmptyState(l10n);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: chatrooms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final chatroom = chatrooms[index];
              final data = chatroom.data() as Map<String, dynamic>;
              final roomId = chatroom.id;
              final title = data['title'] ?? 'Untitled';
              final creatorNickname = data['creatorNickname'] ?? 'Unknown';
              final participantCount = data['participantCount'] ?? 0;
              final maxParticipants = data['maxParticipants'] ?? 10;
              final participants = List<dynamic>.from(data['participants'] ?? []);
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final isJoining = _joiningRooms.contains(roomId);
              final hasJoined = currentUserId != null && participants.contains(currentUserId);
              final isFull = participantCount >= maxParticipants;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.softShadow,
                  border: Border.all(color: AppTheme.gray100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    fontFamily: 'Pretendard',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: AppTheme.gray500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      creatorNickname,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.group_outlined,
                                      size: 14,
                                      color: AppTheme.gray500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$participantCount/$maxParticipants',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              _formatTime(createdAt, l10n),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.gray500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                      ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (hasJoined || isJoining)
                              ? (hasJoined
                                  ? () async {
                                      // Reload current chatroom to show chat view
                                      await _loadCurrentChatroom();
                                    }
                                  : null)
                              : () => _joinChatroom(roomId, participants, title, participantCount, maxParticipants),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasJoined
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isJoining
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  hasJoined ? 'Open Chat' : 'Join Chatroom',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
  }

  Widget _buildCurrentChatroomView(AppLocalizations l10n, AuthController authController) {
    final title = _currentChatroomData?['title'] ?? 'Open Chatroom';
    final participantCount = _currentChatroomData?['participantCount'] ?? 0;
    final maxParticipants = _currentChatroomData?['maxParticipants'] ?? 10;
    final currentUserId = authController.currentUserModel?.uid;
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Column(
      children: [
        // Fixed top section with chatroom info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.gray200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$participantCount/$maxParticipants participants',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _leaveChatroom,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Leave', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Compact horizontal members list
              SizedBox(
                height: 60,
                child: _isLoadingMembers
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _chatroomMembers.isEmpty
                        ? const Center(child: Text('No members', style: TextStyle(fontSize: 12)))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _chatroomMembers.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final member = _chatroomMembers[index];
                              final isBlocked = authController.blockedUserIds.contains(member.uid);
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileDetailView(user: member),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    MemberAvatar(
                                      imageUrl: isBlocked ? null : member.mainProfileImage,
                                      name: member.nickname,
                                      isOwner: false,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        member.nickname,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.gray700),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        // Expandable chat messages section
        Expanded(
          child: Container(
            color: const Color(0xFFF5F6F8),
            child: _messages.isEmpty
                ? _buildEmptyMessageView(l10n)
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      final isMe = message.senderId == currentUserId;
                      final senderProfile = _userProfiles[message.senderId];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: MessageBubble(
                          message: message,
                          isMe: isMe,
                          senderProfile: senderProfile,
                          onTap: message.senderId != 'system' && senderProfile != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileDetailView(user: senderProfile),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ),
        // Fixed message input at bottom
        _buildMessageInput(isKeyboardVisible, l10n),
      ],
    );
  }

  Widget _buildMessageInput(bool isKeyboardVisible, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isKeyboardVisible ? 12 : 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: InputDecoration(
                  hintText: l10n.chatInputHint,
                  hintStyle: const TextStyle(color: AppTheme.gray500, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.arrow_upward_rounded, size: 24),
              color: Colors.white,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessageView(AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to the chatroom!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a conversation with other participants',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Open Chatrooms',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to create an open chatroom!',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final locale = Localizations.localeOf(context);
    final isKorean = locale.languageCode == 'ko';

    if (difference.inMinutes < 1) {
      return l10n.timeJustNow;
    } else if (difference.inHours < 1) {
      return isKorean ? '${difference.inMinutes}분 전' : '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return isKorean ? '${difference.inHours}시간 전' : '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return isKorean ? '${difference.inDays}일 전' : '${difference.inDays}d ago';
    } else {
      return isKorean ? '${date.month}월 ${date.day}일' : '${date.month}/${date.day}';
    }
  }
}

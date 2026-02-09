import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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

class OpenChatroomChatView extends StatefulWidget {
  final String chatroomId;

  const OpenChatroomChatView({
    super.key,
    required this.chatroomId,
  });

  @override
  State<OpenChatroomChatView> createState() => _OpenChatroomChatViewState();
}

class _OpenChatroomChatViewState extends State<OpenChatroomChatView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _currentChatroomData;
  List<UserModel> _chatroomMembers = [];
  bool _isLoadingMembers = false;

  List<ChatMessage> _messages = [];
  Map<String, UserModel> _userProfiles = {};
  StreamSubscription<DocumentSnapshot>? _messageSubscription;
  StreamSubscription<DocumentSnapshot>? _chatroomSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatroomData();
      _listenToMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _chatroomSubscription?.cancel();
    super.dispose();
  }

  void _loadChatroomData() {
    _chatroomSubscription = _firestore
        .collection('openChatrooms')
        .doc(widget.chatroomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _currentChatroomData = snapshot.data();
        });
        _loadChatroomMembers();
      }
    });
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
    // Cancel existing subscription before creating new one
    _messageSubscription?.cancel();

    // Clear messages when setting up new listener
    setState(() {
      _messages = [];
      _userProfiles = {};
    });

    _messageSubscription = _firestore
        .collection('openChatrooms')
        .doc(widget.chatroomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        // Always update messages, even if null or empty
        if (data != null) {
          final messagesData = data['messages'] != null
              ? List<Map<String, dynamic>>.from(data['messages'])
              : <Map<String, dynamic>>[];

          setState(() {
            _messages = messagesData
                .map((msgData) => ChatMessage.fromMap(
                      msgData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      msgData,
                    ))
                .toList();
          });

          // Fetch profiles for message senders if messages exist
          if (_messages.isNotEmpty) {
            _fetchUserProfiles();
          }

          // Auto scroll to bottom when new message arrives
          if (_messages.isNotEmpty) {
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
        } else {
          // Data is null, clear messages
          setState(() {
            _messages = [];
            _userProfiles = {};
          });
        }
      } else if (!snapshot.exists && mounted) {
        // Chatroom doesn't exist, clear messages
        setState(() {
          _messages = [];
          _userProfiles = {};
        });
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
    if (messageText.isEmpty) return;

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

      await _firestore.collection('openChatrooms').doc(widget.chatroomId).update({
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
    final authController = context.read<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    if (currentUserId == null) return;

    try {
      final chatroomRef = _firestore.collection('openChatrooms').doc(widget.chatroomId);
      final chatroomDoc = await chatroomRef.get();

      if (!chatroomDoc.exists) return;

      final data = chatroomDoc.data()!;
      final participantCount = data['participantCount'] ?? 0;

      // If user is the last participant, delete the chatroom entirely
      if (participantCount <= 1) {
        await chatroomRef.delete();
      } else {
        // Check if the leaving user is the owner
        final creatorId = data['creatorId'];
        final participants = List<dynamic>.from(data['participants'] ?? []);

        // Remove current user from participants list
        participants.remove(currentUserId);

        // Prepare update data
        final Map<String, dynamic> updateData = {
          'participants': FieldValue.arrayRemove([currentUserId]),
          'participantCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // If the leaving user is the owner, transfer ownership
        if (creatorId == currentUserId && participants.isNotEmpty) {
          // Transfer to the first remaining participant
          final newOwnerId = participants.first;

          // Fetch new owner's profile to get nickname
          try {
            final newOwnerDoc = await _firestore.collection('users').doc(newOwnerId).get();
            if (newOwnerDoc.exists) {
              final newOwnerData = newOwnerDoc.data()!;
              updateData['creatorId'] = newOwnerId;
              updateData['creatorNickname'] = newOwnerData['nickname'] ?? 'Unknown';
            }
          } catch (e) {
            // Failed to fetch new owner, just update creatorId
            updateData['creatorId'] = newOwnerId;
          }
        }

        await chatroomRef.update(updateData);
      }

      if (mounted) {
        CustomToast.showSuccess(context, 'Left chatroom successfully!');
        // Pop back to list view (OpentingView will handle navigation)
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, 'Failed to leave chatroom: $e');
      }
    }
  }

  void _showChatroomOptionsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppTheme.errorColor),
                title: Text(
                  l10n.opentingLeaveChat,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _leaveChatroom();
                },
              ),
            ],
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.watch<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;
    final isOwner = _currentChatroomData?['creatorId'] == currentUserId;
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              l10n.opentingTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.group_rounded,
                  size: 13,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_currentChatroomData?['participantCount'] ?? 0}/${_currentChatroomData?['maxParticipants'] ?? 10}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppTheme.gray50,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatroomOptionsDialog,
          ),
        ],
      ),
      body: Column(
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
                // Compact horizontal members list
                SizedBox(
                  height: 60,
                  child: _isLoadingMembers
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _chatroomMembers.isEmpty
                          ? Center(child: Text(l10n.opentingNoMembers, style: const TextStyle(fontSize: 12)))
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
                                        builder: (context) => ProfileDetailView(
                                          user: member,
                                          openChatroomId: widget.chatroomId,
                                          isChatRoomOwner: currentUserId == _currentChatroomData?['creatorId'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      MemberAvatar(
                                        imageUrl: isBlocked ? null : member.mainProfileImage,
                                        name: member.nickname,
                                        isOwner: member.uid == _currentChatroomData?['creatorId'],
                                        gender: member.gender,
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
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        final isMe = message.senderId == currentUserId;
                        final senderProfile = _userProfiles[message.senderId];
                        
                        // Hide messages from blocked users
                        final authController = context.read<AuthController>();
                        final isBlocked = authController.blockedUserIds.contains(message.senderId);
                        if (isBlocked && !isMe) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: MessageBubble(
                            message: message,
                            isMe: isMe,
                            senderProfile: senderProfile,
                            openChatroomId: widget.chatroomId,
                            isChatRoomOwner: isOwner,
                            isSenderInChatroom: _currentChatroomData?['participants']?.contains(message.senderId) ?? false,
                            onTap: message.senderId != 'system' && senderProfile != null
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileDetailView(
                                          user: senderProfile,
                                          openChatroomId: widget.chatroomId,
                                          isChatRoomOwner: isOwner,
                                          isTargetUserInChatroom: _currentChatroomData?['participants']?.contains(message.senderId) ?? false,
                                        ),
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
      ),
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
              Text(
                l10n.opentingWelcome,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.opentingStartConversation,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
}

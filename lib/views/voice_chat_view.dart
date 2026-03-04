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
import '../models/message_model.dart';
import 'profile_detail_view.dart';
import '../utils/user_action_helper.dart';
import '../widgets/chat_input_area.dart';
import 'openting_view.dart';
import '../services/voice_chat_service.dart';

class VoiceChatView extends StatefulWidget {
  final String chatroomId;

  const VoiceChatView({
    super.key,
    required this.chatroomId,
  });

  @override
  State<VoiceChatView> createState() => _VoiceChatViewState();
}

class _VoiceChatViewState extends State<VoiceChatView> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _currentChatroomData;
  List<UserModel> _chatroomMembers = [];
  bool _isLoadingMembers = false;
  bool _isLeaving = false;

  List<MessageModel> _messages = [];
  Map<String, UserModel> _userProfiles = {};
  MessageModel? _replyMessage;
  StreamSubscription<DocumentSnapshot>? _messageSubscription;
  StreamSubscription<DocumentSnapshot>? _chatroomSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatroomData();
      _listenToMessages();
      _initAgoraAsListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _chatroomSubscription?.cancel();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && !_isLeaving) {
      _leaveChatroom();
    }
  }

  void _loadChatroomData() {
    _chatroomSubscription = _firestore
        .collection('openChatrooms')
        .doc(widget.chatroomId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final data = snapshot.data();
      final authController = context.read<AuthController>();
      final currentUserId = authController.currentUserModel?.uid;

      if (!snapshot.exists || data == null) {
        if (mounted && !_isLeaving) {
          CustomToast.showError(context, AppLocalizations.of(context)!.voiceChatClosedByOwner);
          _leaveChatroom(showSuccessToast: false);
        }
        return;
      }

      if (mounted) {
        final participants = List<String>.from(data['participants'] ?? []);
        final isBanned = data['bannedUsers']?.contains(currentUserId) ?? false;
        
        if (!participants.contains(currentUserId) && !isBanned) {
          if (!_isLeaving) {
            _leaveChatroom(showSuccessToast: false);
          }
          return;
        }

        if (isBanned && !_isLeaving) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.opentingBannedMessage),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          _leaveChatroom(showSuccessToast: false);
          return;
        }

        setState(() {
          _currentChatroomData = data;
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

        // Mute any already active remote users who are blocked
        final voiceService = context.read<VoiceChatService>();
        if (voiceService.activeChatroomId != null) {
          final authController = context.read<AuthController>();
          final blockedIds = authController.blockedUserIds;
          
          for (final member in members) {
            if (blockedIds.contains(member.uid) && voiceService.remoteUsers.containsKey(member.uid.hashCode)) {
              voiceService.muteRemoteUser(member.uid.hashCode);
            }
          }
        }
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
    _messageSubscription?.cancel();

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
        if (data != null) {
          final messagesData = data['messages'] != null
              ? List<Map<String, dynamic>>.from(data['messages'])
              : <Map<String, dynamic>>[];

          setState(() {
            _messages = messagesData
                .map((msgData) => MessageModel.fromMap(
                      msgData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      msgData,
                    ))
                .toList();
          });

          if (_messages.isNotEmpty) {
            _fetchUserProfiles();
          }

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
          setState(() {
            _messages = [];
            _userProfiles = {};
          });
        }
      } else if (!snapshot.exists && mounted) {
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
      final newMessage = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: widget.chatroomId,
        senderId: currentUser.uid,
        senderNickname: currentUser.nickname,
        content: messageText,
        type: MessageType.text,
        createdAt: DateTime.now(),
        readBy: [currentUser.uid],
        senderProfileImage: currentUser.mainProfileImage,
        replyToMessageId: _replyMessage?.id,
        replyToMessageSenderNickname: _replyMessage?.senderNickname,
        replyToMessageContent: _replyMessage?.content,
      );

      setState(() {
        _replyMessage = null;
      });

      await _firestore.collection('openChatrooms').doc(widget.chatroomId).update({
        'messages': FieldValue.arrayUnion([newMessage.toFirestore()]),
        'lastMessage': newMessage.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.opentingSendMessageFailed);
      }
    }
  }

  Future<void> _leaveChatroom({bool showSuccessToast = true}) async {
    final authController = context.read<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    if (currentUserId == null) return;

    _isLeaving = true;
    final voiceService = context.read<VoiceChatService>();
    final success = await voiceService.permanentlyLeaveChatroomDB(widget.chatroomId, currentUserId);

    if (success && mounted) {
      if (showSuccessToast) {
        CustomToast.showSuccess(context, AppLocalizations.of(context)!.opentingLeaveSuccess);
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const OpentingView()),
        (route) => route.isFirst,
      );
    } else if (mounted) {
      CustomToast.showError(context, AppLocalizations.of(context)!.opentingLeaveFailed);
      _isLeaving = false;
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

  void _showUserOptions(BuildContext context, UserModel user) {
    if (!mounted) return;
    
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;
    if (currentUser == null) return;

    final isOwner = _currentChatroomData?['creatorId'] == currentUser.uid;
    final isTargetInChatroom = _currentChatroomData?['participants']?.contains(user.uid) ?? false;

    UserActionHelper.showUserOptionsBottomSheet(
      context: context,
      targetUser: user,
      openChatroomId: widget.chatroomId,
      isChatRoomOwner: isOwner,
      isTargetUserInChatroom: isTargetInChatroom,
    );
  }

  Future<void> _initAgoraAsListener() async {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;
    final actualUserId = currentUser?.uid ?? '';
    final agoraUid = actualUserId.hashCode;
    final blockedIds = authController.blockedUserIds;
    
    final voiceService = context.read<VoiceChatService>();
    await voiceService.initAgoraAsListener(widget.chatroomId, actualUserId, agoraUid, blockedIds);
  }

  Future<void> _joinAsBroadcaster(VoiceChatService service) async {
    final success = await service.joinAsBroadcaster();
    if (!success && mounted) {
      CustomToast.showError(context, AppLocalizations.of(context)!.voiceChatJoinFailed(''));
    }
  }

  void _toggleVoiceChat(VoiceChatService service) {
    if (service.isVoiceChatActive) {
      service.revertToListener();
    } else {
      _joinAsBroadcaster(service);
    }
  }

  Widget _buildVoiceChatPanel(VoiceChatService service) {
    if (!service.isVoiceChatActive) {
      return GestureDetector(
        onTap: () => _toggleVoiceChat(service),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.record_voice_over, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.voiceChatTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.voiceChatJoinPrompt,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gray900,
            const Color(0xFF1A1D24),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.voiceChatActive,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_rounded, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${service.remoteUsers.length + 1}', // 1 (self) + active remote users
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildVoiceControlButton(
                icon: service.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                label: AppLocalizations.of(context)!.voiceChatSpeaker,
                isActive: service.isSpeakerOn,
                activeColor: Colors.white,
                inactiveColor: Colors.white54,
                onTap: service.toggleSpeaker,
              ),
              const SizedBox(width: 32),
              _buildVoiceControlButton(
                icon: service.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: AppLocalizations.of(context)!.voiceChatMic,
                isActive: !service.isMuted,
                activeColor: Colors.white,
                inactiveColor: AppTheme.errorColor,
                isLarge: true,
                onTap: service.toggleMute,
              ),
              const SizedBox(width: 32),
              _buildVoiceControlButton(
                icon: Icons.call_end_rounded,
                label: AppLocalizations.of(context)!.voiceChatLeave,
                isActive: false,
                activeColor: Colors.white,
                inactiveColor: AppTheme.errorColor,
                isDestructive: true,
                onTap: () => _toggleVoiceChat(service),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
    bool isLarge = false,
    bool isDestructive = false,
  }) {
    final color = isActive ? activeColor : inactiveColor;
    final size = isLarge ? 64.0 : 52.0;
    final iconSize = isLarge ? 28.0 : 24.0;
    
    Color bgColor;
    if (isDestructive) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.15);
    } else if (isActive) {
      bgColor = Colors.white.withValues(alpha: 0.15);
    } else {
      bgColor = isLarge ? AppTheme.errorColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDestructive ? AppTheme.errorColor.withValues(alpha: 0.5) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? AppTheme.errorColor : (isActive ? Colors.white : Colors.white70),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
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
              l10n.opentingTitle, // Or "Voice Chat" if there was a localized string
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
      body: Consumer<VoiceChatService>(
        builder: (context, voiceChatService, _) {
          return Column(
            children: [
              // Fixed top section: member list + voice panel
              _buildMemberList(voiceChatService.remoteUsers),
              _buildVoiceChatPanel(voiceChatService),
              // Expandable messages section
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
                                onAvatarLongPress: message.senderId != 'system' && senderProfile != null
                                    ? () => _showUserOptions(context, senderProfile)
                                    : null,
                                onReply: message.senderId != 'system'
                                    ? () {
                                        setState(() {
                                          _replyMessage = message;
                                        });
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ),
              ChatInputArea(
                controller: _messageController,
                isKeyboardVisible: isKeyboardVisible,
                replyMessage: _replyMessage,
                onCancelReply: () {
                  setState(() {
                    _replyMessage = null;
                  });
                },
                onSend: _sendMessage,
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildMemberList(Map<int, bool> remoteUsersData) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.read<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    if (_isLoadingMembers) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.gray200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 70,
            child: _chatroomMembers.isEmpty
                ? Center(child: Text(l10n.opentingNoMembers, style: const TextStyle(fontSize: 12)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _chatroomMembers.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final member = _chatroomMembers[index];
                      final isBlocked = authController.blockedUserIds.contains(member.uid);
                      final isVoiceJoined = (member.uid == currentUserId && context.read<VoiceChatService>().isVoiceChatActive) || remoteUsersData.containsKey(member.uid.hashCode);
                      
                      return GestureDetector(
                        onLongPress: () => _showUserOptions(context, member),
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
                              isVoiceChatJoined: isVoiceJoined,
                              gender: member.gender,
                              size: 50,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 60,
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

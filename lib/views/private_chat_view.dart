import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../models/user_model.dart';
import '../services/fcm_service.dart';
import '../services/chatroom_service.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/message_bubble.dart';
import '../utils/user_action_helper.dart';
import '../widgets/chat_input_area.dart';

class PrivateChatView extends StatefulWidget {
  final String chatRoomId;
  final String targetUserNickname;
  final String targetUserId;

  const PrivateChatView({
    super.key,
    required this.chatRoomId,
    required this.targetUserNickname,
    required this.targetUserId,
  });

  @override
  State<PrivateChatView> createState() => _PrivateChatViewState();
}

class _PrivateChatViewState extends State<PrivateChatView> with WidgetsBindingObserver {
  ChatController? _chatController;
  final ChatroomService _chatroomService = ChatroomService();
  final UserService _userService = UserService();
  UserModel? _targetUserProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FCMService().setCurrentChatRoom(widget.chatRoomId);

    _loadTargetUserProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatroomService.markAsRead(widget.chatRoomId);

      if (mounted) {
        try {
          final chatController = context.read<ChatController>();
          _chatController = chatController;
          chatController.startMessageStream(widget.chatRoomId, isPrivate: true);
        } catch (e) {
          debugPrint('PrivateChatView initState Error: $e');
        }
      }
    });
  }

  Future<void> _loadTargetUserProfile() async {
    try {
      final user = await _userService.getUserById(widget.targetUserId);
      if (mounted && user != null) {
        setState(() {
          _targetUserProfile = user;
        });
      }
    } catch (e) {
      debugPrint('Failed to load target user profile: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chatController == null) {
      try {
        _chatController = context.read<ChatController>();
      } catch (e) {
        // ChatController ref failed
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FCMService().clearCurrentChatRoom();
    try {
      _chatController?.clearData(fromDispose: true);
    } catch (e) {
      debugPrint('ChatController dispose error: $e');
    }
    _chatController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      FCMService().clearCurrentChatRoom();
    } else if (state == AppLifecycleState.resumed) {
      FCMService().setCurrentChatRoom(widget.chatRoomId);
    }
  }

  void _showUserOptions(BuildContext context, UserModel user) {
    if (!mounted) return;

    UserActionHelper.showUserOptionsBottomSheet(
      context: context,
      targetUser: user,
      openChatroomId: null,
      isChatRoomOwner: false,
      isTargetUserInChatroom: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Consumer<ChatController>(
          builder: (context, chatController, _) {
            final memberCount = chatController.matchedGroupMembers.length;
            return Column(
              children: [
                  Text(
                  AppLocalizations.of(context)!.privateChatTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                if (memberCount > 0)
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
                        '$memberCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.gray200, height: 1),
        ),
        actions: [
          // Option to leave/report etc. could be added here
          // For now, maybe just "block" or "report" the user via avatar long press?
          // Or we can add an action button to show user options for the target user.
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              final l10n = AppLocalizations.of(context)!;
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(l10n.privateChatLeaveChat),
                    content: Text(l10n.privateChatLeaveConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l10n.commonCancel),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop(); // close dialog
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final chatroomService = ChatroomService();
                            await chatroomService.leavePrivateChatroom(widget.chatRoomId);
                            if (mounted) {
                              navigator.pop(); // go back
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(l10n.privateChatLeaveFailed)),
                              );
                            }
                          }
                        },
                        child: Text(
                          l10n.privateChatLeaveChat,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer2<ChatController, AuthController>(
        builder: (context, chatController, authController, _) {
          if (!authController.isLoggedIn) {
             return const Center(child: CircularProgressIndicator());
          }

          // Ensure blocked users are updated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            chatController.updateBlockedUsers(authController.blockedUserIds);
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: chatController.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatController.messages[
                    chatController.messages.length - 1 - index];

                    if (message.senderId == 'system') {
                      return _buildSystemMessage(message);
                    }


                    final isMe = chatController.isMyMessage(message);
                    final senderProfile = !isMe ? _targetUserProfile : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: MessageBubble(
                        message: message,
                        isMe: isMe,
                        senderProfile: senderProfile,
                        onAvatarLongPress: senderProfile != null
                            ? () => _showUserOptions(context, senderProfile)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              ChatInputArea(
                controller: chatController.messageController,
                onSend: () async => await chatController.sendMessage(),
                isKeyboardVisible: isKeyboardVisible,
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildSystemMessage(dynamic message) {
    final l10n = AppLocalizations.of(context)!;
    // Translate known system message keys
    String displayContent = message.content;
    if (message.content == '__private_chat_started__') {
      displayContent = l10n.privateChatStarted;
    } else if (message.content.toString().startsWith('__user_left__:')) {
      final nickname = message.content.toString().substring('__user_left__:'.length);
      displayContent = l10n.systemUserLeft(nickname);
    }

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          displayContent,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha:0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

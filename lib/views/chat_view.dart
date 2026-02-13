import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../controllers/chat_controller.dart';
import '../services/fcm_service.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/message_bubble.dart';
import 'profile_detail_view.dart';
import 'invite_friend_view.dart';
import '../services/chatroom_service.dart';
import '../models/user_model.dart';
import '../utils/user_action_helper.dart';

class ChatView extends StatefulWidget {
  final String groupId;

  const ChatView({super.key, required this.groupId});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  ChatController? _chatController;
  final ChatroomService _chatroomService = ChatroomService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FCMService().setCurrentChatRoom(widget.groupId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatroomService.markAsRead(widget.groupId);

      if (mounted) {
        try {
          final chatController = context.read<ChatController>();
          _chatController = chatController;
          chatController.startMessageStream(widget.groupId);
        } catch (e) {
          debugPrint('ChatView initState 에러: $e');
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chatController == null) {
      try {
        _chatController = context.read<ChatController>();
      } catch (e) {
        // ChatController 참조 저장 실패
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
      debugPrint('ChatController 정리 중 에러: $e');
    }
    _chatController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      FCMService().clearCurrentChatRoom();
    } else if (state == AppLifecycleState.resumed) {
      FCMService().setCurrentChatRoom(widget.groupId);
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
        title: Consumer<GroupController>(
          builder: (context, groupController, _) {
            if (groupController.currentGroup == null) {
              return Text(l10n.chatTitle);
            }
            return Column(
              children: [
                Text(
                  groupController.isMatched ? l10n.chatMatchingTitle : l10n.chatGroupTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                if (!groupController.isMatched)
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
                        '${groupController.groupMembers.length}',
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
      ),
      body: Consumer3<GroupController, ChatController, AuthController>(
        builder: (context, groupController, chatController, authController, _) {
          if (authController.isLoggedIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              chatController.updateBlockedUsers(authController.blockedUserIds);
            });
          }

          if (!authController.isLoggedIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (groupController.currentGroup != null && !groupController.isMatched)
                _buildStickyHeader(context, groupController, l10n),

              Expanded(
                child: chatController.messages.isEmpty
                    ? _buildEmptyMessageView(groupController, l10n)
                    : ListView.builder(
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

                    final senderProfile = message.senderId != 'system'
                        ? chatController.matchedGroupMembers
                        .where((member) => member.uid == message.senderId)
                        .firstOrNull
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: MessageBubble(
                        message: message,
                        isMe: chatController.isMyMessage(message),
                        senderProfile: senderProfile,
                        onTap: message.senderId != 'system'
                            ? () {
                          final member = groupController
                              .getMemberById(message.senderId);
                          if (member != null &&
                              member.uid.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileDetailView(user: member),
                              ),
                            );
                          }
                        }
                            : null,
                        onAvatarLongPress: message.senderId != 'system' && senderProfile != null
                            ? () => _showUserOptions(context, senderProfile)
                            : null,
                      ),
                    );
                  },
                ),
              ),

              _buildInputArea(isKeyboardVisible, chatController, l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context, GroupController groupController, AppLocalizations l10n) {
    final sentInvitations = groupController.sentInvitations;
    final pendingCount = sentInvitations
        .where((inv) => inv.status.toString().split('.').last == 'pending')
        .length;

    Widget? content;

    if (groupController.isMatching ||
        (groupController.isOwner &&
            pendingCount == 0 &&
            groupController.currentGroup!.memberIds.length < 5)) {
      content = GestureDetector(
        onTap: () {
          if (!groupController.isMatching) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InviteFriendView()),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              groupController.isMatching ? Icons.hourglass_top_rounded : Icons.person_add_rounded,
              size: 16,
              color: groupController.isMatching ? Colors.orange[700] : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              groupController.isMatching
                  ? l10n.chatFindingMatch
                  : '${l10n.chatInviteFriend} (${groupController.currentGroup!.memberIds.length}/5)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: groupController.isMatching ? Colors.orange[800] : AppTheme.primaryColor,
              ),
            ),
            if (!groupController.isMatching)
              const Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryColor),
          ],
        ),
      );
    }
    else if (pendingCount > 0) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text(
            l10n.chatWaitingResponse(pendingCount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
        ],
      );
    }

    if (content == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: groupController.isMatching || pendingCount > 0
            ? Colors.orange.withValues(alpha:0.08)
            : AppTheme.primaryColor.withValues(alpha:0.08),
        border: Border(
          bottom: BorderSide(
            color: groupController.isMatching || pendingCount > 0
                ? Colors.orange.withValues(alpha:0.1)
                : AppTheme.primaryColor.withValues(alpha:0.1),
          ),
        ),
      ),
      child: content,
    );
  }

  Widget _buildInputArea(bool isKeyboardVisible, ChatController chatController, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isKeyboardVisible ? 12 : 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
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
                controller: chatController.messageController,
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
              onPressed: () async {
                await chatController.sendMessage();
              },
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

  Widget _buildEmptyMessageView(GroupController groupController, AppLocalizations l10n) {
    final isMatched = groupController.isMatched;
    final memberCount = groupController.groupMembers.length;

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
                      color: AppTheme.primaryColor.withValues(alpha:0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Icon(
                  isMatched ? Icons.favorite_rounded : Icons.chat_bubble_rounded,
                  size: 48,
                  color: isMatched ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isMatched ? l10n.chatEmptyMatched : l10n.chatEmptyGroup,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMatched
                    ? l10n.chatEmptyMatchedDesc
                    : memberCount > 1
                    ? l10n.chatEmptyGroupWithFriends
                    : l10n.chatEmptyAlone,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              if (!isMatched && memberCount == 1 && groupController.isOwner) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InviteFriendView(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.chatInviteFriend,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(dynamic message) {
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
          message.content,
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
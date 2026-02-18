import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chatroom_model.dart';
import '../models/user_model.dart';
import '../services/chatroom_service.dart';
import '../services/user_service.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';
import '../widgets/member_avatar.dart';
import 'private_chat_view.dart';
import '../l10n/generated/app_localizations.dart';

class PrivateChatListView extends StatefulWidget {
  const PrivateChatListView({super.key});

  @override
  State<PrivateChatListView> createState() => _PrivateChatListViewState();
}

class _PrivateChatListViewState extends State<PrivateChatListView> {
  final ChatroomService _chatroomService = ChatroomService();
  final UserService _userService = UserService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) return const SizedBox();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          l10n.homeNavChat,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard',
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.gray200, height: 1),
        ),
      ),
      body: StreamBuilder<List<ChatroomModel>>(
        stream: _chatroomService.getPrivateChatroomsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.gray400),
                  const SizedBox(height: 12),
                  Text(
                    'Something went wrong',
                    style: TextStyle(color: AppTheme.gray500, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          final chatrooms = snapshot.data ?? [];

          if (chatrooms.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: chatrooms.length,
            itemBuilder: (context, index) {
              final chatroom = chatrooms[index];

              // Derive the other user's ID from the chatroom document ID (format: uid1_uid2)
              final idParts = chatroom.id.split('_');
              final otherUserId = idParts.length == 2
                  ? (idParts[0] == currentUser.uid ? idParts[1] : idParts[0])
                  : chatroom.participants.firstWhere(
                      (id) => id != currentUser.uid,
                      orElse: () => '',
                    );

              if (otherUserId.isEmpty) return const SizedBox();

              return FutureBuilder<UserModel?>(
                future: _userService.getUserById(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return _buildShimmerTile();
                  }

                  final otherUser = userSnapshot.data!;
                  final lastMessage = chatroom.lastMessage;
                  final unreadCount = _calculateUnreadCount(chatroom, currentUser.uid);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildChatTile(
                      context: context,
                      otherUser: otherUser,
                      chatroom: chatroom,
                      lastMessage: lastMessage,
                      unreadCount: unreadCount,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile({
    required BuildContext context,
    required UserModel otherUser,
    required ChatroomModel chatroom,
    dynamic lastMessage,
    required int unreadCount,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrivateChatView(
                chatRoomId: chatroom.id,
                targetUserId: otherUser.uid,
                targetUserNickname: otherUser.nickname,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unreadCount > 0
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.gray200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar with online-like accent ring for unread
              MemberAvatar(
                imageUrl: otherUser.mainProfileImage,
                name: otherUser.nickname,
                size: 48,
              ),
              const SizedBox(width: 14),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Time row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUser.nickname,
                            style: TextStyle(
                              fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Pretendard',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessage != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(lastMessage.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: unreadCount > 0
                                  ? AppTheme.warningColor
                                  : AppTheme.gray400,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Last message + unread badge row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage?.content ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: unreadCount > 0
                                  ? AppTheme.warningColor
                                  : AppTheme.gray500,
                              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                              fontFamily: 'Pretendard',
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'N',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation by\ninviting someone to chat!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
              fontFamily: 'Pretendard',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 180,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(4),
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

  int _calculateUnreadCount(ChatroomModel chatroom, String currentUserId) {
    if (chatroom.lastMessage != null) {
      final readBy = chatroom.lastMessage!.readBy;
      if (!readBy.contains(currentUserId)) {
        return 1;
      }
    }
    return 0;
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(date);
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }
}

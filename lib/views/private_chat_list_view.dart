import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chatroom_model.dart';
import '../models/user_model.dart';
import '../services/chatroom_service.dart';
import '../services/user_service.dart';
import '../services/firebase_service.dart';
import '../controllers/auth_controller.dart';
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
      appBar: AppBar(
        title: const Text(
          '1:1 Chat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<List<ChatroomModel>>(
        stream: _chatroomService.getPrivateChatroomsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final chatrooms = snapshot.data ?? [];

          if (chatrooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.gray300),
                  const SizedBox(height: 16),
                  Text(
                    'No private chats yet',
                    style: TextStyle(color: AppTheme.gray500, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: chatrooms.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final chatroom = chatrooms[index];
              
              // Find the other participant
              final otherUserId = chatroom.participants.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) return const SizedBox();

              return FutureBuilder<UserModel?>(
                future: _userService.getUserById(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox(height: 72); // Placeholder height
                  }

                  final otherUser = userSnapshot.data!;
                  final lastMessage = chatroom.lastMessage;
                  final unreadCount = _calculateUnreadCount(chatroom, currentUser.uid);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: MemberAvatar(
                      imageUrl: otherUser.mainProfileImage,
                      name: otherUser.nickname,
                      size: 50,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          otherUser.nickname,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (lastMessage != null)
                        Text(
                          _formatTime(lastMessage.createdAt),
                          style: const TextStyle(
                            color: AppTheme.gray500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage?.content ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unreadCount > 0 ? AppTheme.textPrimary : AppTheme.gray500,
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  int _calculateUnreadCount(ChatroomModel chatroom, String currentUserId) {
    // This is a simplified unread count. 
    // Ideally, we compare last read timestamp or message ID with chatroom's last message.
    // ChatroomModel doesn't have per-user unread count easily accessible without more logic or subcollections.
    // For now, let's use the 'readBy' field in the last message.
    // If I haven't read the last message, show a dot or 'N'.
    // Real unread count requires tracking 'lastReadMessageId' per user in the chatroom document.
    
    // Check if the last message exists and if I'm in its readBy list.
    if (chatroom.lastMessage != null) {
       final readBy = chatroom.lastMessage!.readBy;
       if (!readBy.contains(currentUserId)) {
         return 1; // At least one unread. Accurate count requires more data.
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
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }
}

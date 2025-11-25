import 'package:flutter/material.dart';
import '../models/chatroom_model.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../views/profile_detail_view.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final UserModel? senderProfile;
  final VoidCallback? onTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.senderProfile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            // 상대방 메시지일 때 프로필 이미지
            GestureDetector(
              onTap: () {
                if (senderProfile != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileDetailView(user: senderProfile!),
                    ),
                  );
                }
              },
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                child: senderProfile != null
                    ? MemberAvatar(user: senderProfile!, size: 32)
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.gray300,
                        child: Text(
                          message.senderNickname.isNotEmpty
                              ? message.senderNickname[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.primaryColor
                      : message.type == MessageType.system
                      ? AppTheme.gray200
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: message.type != MessageType.system
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 발신자 이름 (시스템 메시지가 아니고 내 메시지가 아닐 때)
                    if (!isMe && message.type != MessageType.system) ...[
                      Text(
                        message.senderNickname,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // 메시지 내용
                    Text(
                      message.content,
                      textAlign: isMe ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : message.type == MessageType.system
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontSize: message.type == MessageType.system ? 12 : 16,
                      ),
                    ),

                    // 시간 표시
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$period $displayHour:$minute';
  }
}

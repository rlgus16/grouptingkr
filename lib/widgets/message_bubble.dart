import 'package:flutter/material.dart';
import 'package:groupting/models/message_model.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../views/profile_detail_view.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final UserModel? senderProfile;
  final String? openChatroomId;
  final bool isChatRoomOwner;
  final bool isSenderInChatroom;
  final VoidCallback? onAvatarLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.senderProfile,
    this.openChatroomId,
    this.isChatRoomOwner = false,
    this.isSenderInChatroom = true,
    this.onAvatarLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showTime = false;

  void _toggleTime() {
    setState(() {
      _showTime = !_showTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: widget.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!widget.isMe) ...[
            // 상대방 메시지일 때 프로필 이미지
            GestureDetector(
              onLongPress: widget.onAvatarLongPress,
              onTap: () {
                if (widget.senderProfile != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileDetailView(
                        user: widget.senderProfile!,
                        openChatroomId: widget.openChatroomId,
                        isChatRoomOwner: widget.isChatRoomOwner,
                        isTargetUserInChatroom: widget.isSenderInChatroom,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                child: widget.senderProfile != null
                    ? MemberAvatar(user: widget.senderProfile!, size: 32)
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.gray300,
                        child: Text(
                          widget.message.senderNickname.isNotEmpty
                              ? widget.message.senderNickname[0].toUpperCase()
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
              onTap: _toggleTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? AppTheme.primaryColor
                      : widget.message.type == MessageType.system
                      ? AppTheme.gray200
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
                    bottomRight: Radius.circular(widget.isMe ? 4 : 20),
                  ),
                  boxShadow: widget.message.type != MessageType.system
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 발신자 이름 (시스템 메시지가 아니고 내 메시지가 아닐 때)
                    if (!widget.isMe && widget.message.type != MessageType.system) ...[
                      Text(
                        widget.message.senderNickname,
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
                      widget.message.content,
                      textAlign: widget.isMe ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: widget.isMe
                            ? Colors.white
                            : widget.message.type == MessageType.system
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontSize: widget.message.type == MessageType.system ? 12 : 16,
                      ),
                    ),

                    // 시간 표시 (탭했을 때만 보임)
                    if (_showTime) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(widget.message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe
                              ? Colors.white.withValues(alpha:0.8)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
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

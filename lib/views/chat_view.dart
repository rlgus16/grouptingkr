import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../controllers/chat_controller.dart';
import '../services/fcm_service.dart';
import '../utils/app_theme.dart';
import '../widgets/message_bubble.dart';
import 'profile_detail_view.dart';
import 'invite_friend_view.dart';

class ChatView extends StatefulWidget {
  final String groupId;

  const ChatView({super.key, required this.groupId});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  ChatController? _chatController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FCMService().setCurrentChatRoom(widget.groupId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8), // 부드러운 배경색
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Consumer<GroupController>(
          builder: (context, groupController, _) {
            if (groupController.currentGroup == null) {
              return const Text('채팅');
            }
            return Column(
              children: [
                Text(
                  groupController.isMatched ? '매칭 채팅' : '그룹 채팅',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                if (!groupController.isMatched)
                  Text(
                    '${groupController.groupMembers.length}명 참여 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha:0.8),
                      fontWeight: FontWeight.normal,
                    ),
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
              // 헤더 (초대/매칭 상태)
              if (groupController.currentGroup != null && !groupController.isMatched)
                _buildStickyHeader(context, groupController),

              // 메시지 리스트
              Expanded(
                child: chatController.messages.isEmpty
                    ? _buildEmptyMessageView(groupController)
                    : ListView.builder(
                  reverse: true,
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
                      padding: const EdgeInsets.only(bottom: 4.0), // 말풍선 간 간격 미세 조정
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
                      ),
                    );
                  },
                ),
              ),

              // 입력창 영역
              _buildInputArea(isKeyboardVisible, chatController),
            ],
          );
        },
      ),
    );
  }

  // 매칭 전 상단 상태 표시 (스티키 헤더 느낌)
  Widget _buildStickyHeader(BuildContext context, GroupController groupController) {
    final sentInvitations = groupController.sentInvitations;
    final pendingCount = sentInvitations
        .where((inv) => inv.status.toString().split('.').last == 'pending')
        .length;

    Widget? content;

    // 1. 매칭 중이거나 초대 가능 상태
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
                  ? '매칭 상대를 찾고 있어요...'
                  : '친구 초대하기 (${groupController.currentGroup!.memberIds.length}/5)',
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
    // 2. 초대 대기 중
    else if (pendingCount > 0) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text(
            '$pendingCount명의 친구가 응답 대기 중입니다',
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

  // 개선된 입력창 영역
  Widget _buildInputArea(bool isKeyboardVisible, ChatController chatController) {
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
                textInputAction: TextInputAction.newline, // 엔터로 줄바꿈 허용 시
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: const InputDecoration(
                  hintText: '메시지 보내기',
                  hintStyle: TextStyle(color: AppTheme.gray500, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 전송 버튼
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor,
              // 그라디언트를 원하면 아래 주석 해제
              /* gradient: AppTheme.primaryGradient, */
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

  Widget _buildEmptyMessageView(GroupController groupController) {
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
                isMatched ? '매칭 성공! 🎉' : '그룹 채팅 시작 👋',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMatched
                    ? '설레는 대화를 시작해보세요.\n서로에 대해 알아가는 시간이 되길 바래요!'
                    : memberCount > 1
                    ? '친구들과 자유롭게 대화를 나눠보세요!'
                    : '아직 그룹에 혼자 있어요.\n친구들을 초대 해보세요!',
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
                    child: const Text(
                      '친구 초대하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
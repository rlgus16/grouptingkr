import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../controllers/chat_controller.dart';
import '../services/fcm_service.dart';
import '../utils/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/member_avatar.dart';
import 'profile_detail_view.dart';
import 'invite_friend_view.dart';

class ChatView extends StatefulWidget {
  final String groupId;

  const ChatView({super.key, required this.groupId});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  ChatController? _chatController;

  @override
  void initState() {
    super.initState();
    // FCM 서비스에 현재 채팅방 설정
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
    // ChatController 참조를 안전하게 저장
    if (_chatController == null) {
      try {
        _chatController = context.read<ChatController>();
      } catch (e) {
        // ChatController 참조 저장 실패: $e
      }
    }
  }

  @override
  void dispose() {
    // FCM 서비스에서 현재 채팅방 해제
    FCMService().clearCurrentChatRoom();

    // 안전하게 ChatController 정리 (dispose 중임을 알림)
    try {
      _chatController?.clearData(fromDispose: true);
    } catch (e) {
      debugPrint('ChatController 정리 중 에러: $e');
    }
    _chatController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery로 키보드 높이 감지
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true, // 키보드가 올라올 때 화면 크기 조정
      appBar: AppBar(
        title: Consumer<GroupController>(
          builder: (context, groupController, _) {
            if (groupController.currentGroup == null) {
              return const Text('채팅');
            }
            return Text(
              groupController.isMatched ? '매칭 채팅' : '그룹 채팅',
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Consumer3<GroupController, ChatController, AuthController>(
        builder: (context, groupController, chatController, authController, _) {

          // 차단 목록 동기화
          if (authController.isLoggedIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              chatController.updateBlockedUsers(authController.blockedUserIds);
            });
          }

          // 로그인 상태 실시간 체크 (회원탈퇴 후 즉시 리다이렉트)
          if (!authController.isLoggedIn) {
            debugPrint('채팅 화면 - 로그인 상태 해제 감지, 로그인 화면으로 이동');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              }
            });
            // 로그인 화면 이동 중 빈 화면 표시
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('로그인 화면으로 이동 중...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 채팅 상태 헤더 (매칭 전/후에 따라 다른 UI)
              if (groupController.currentGroup != null)
                _buildChatHeader(context, groupController, chatController),

              // 채팅 메시지 영역
              Expanded(
                child: chatController.messages.isEmpty
                    ? _buildEmptyMessageView(groupController)
                    : ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    // 키보드가 보일 때는 하단 패딩을 줄여서 오버플로우 방지
                    bottom: isKeyboardVisible ? 4 : 16,
                  ),
                  itemCount: chatController.messages.length,
                  itemBuilder: (context, index) {
                    final message =
                    chatController.messages[chatController
                        .messages
                        .length -
                        1 -
                        index];
                    final senderProfile = message.senderId != 'system'
                        ? chatController.matchedGroupMembers
                        .where(
                          (member) =>
                      member.uid == message.senderId,
                    )
                        .firstOrNull
                        : null;

                    return MessageBubble(
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
                    );
                  },
                ),
              ),

              // 메시지 입력 영역 - SafeArea 적용으로 안전한 영역 확보
              SafeArea(
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: isKeyboardVisible ? 4 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.gray200)),
                    // 키보드가 올라올 때 약간의 그림자 추가로 분리감 제공
                    boxShadow: isKeyboardVisible
                        ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // 키보드가 올라올 때 TextField 높이 제한으로 오버플로우 방지
                            maxHeight: isKeyboardVisible ? 100 : 120,
                          ),
                          child: TextField(
                            controller: chatController.messageController,
                            decoration: InputDecoration(
                              hintText: '메시지를 입력하세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppTheme.gray100,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isKeyboardVisible ? 8 : 12, // 키보드 상태에 따라 패딩 조정
                              ),
                              // 키보드가 올라올 때 힌트 텍스트 크기 조정
                              hintStyle: TextStyle(
                                fontSize: isKeyboardVisible ? 14 : 16,
                              ),
                            ),
                            maxLines: isKeyboardVisible ? 3 : 5, // 키보드 상태에 따라 최대 줄 수 제한
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            style: TextStyle(
                              fontSize: isKeyboardVisible ? 14 : 16, // 키보드 상태에 따라 폰트 크기 조정
                            ),
                            onSubmitted: (_) async {
                              await chatController.sendMessage();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          await chatController.sendMessage();
                        },
                        icon: Icon(
                          Icons.send,
                          size: isKeyboardVisible ? 20 : 24, // 키보드 상태에 따라 아이콘 크기 조정
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.all(isKeyboardVisible ? 8 : 12), // 키보드 상태에 따라 패딩 조정
                          minimumSize: Size(
                            isKeyboardVisible ? 40 : 48,
                            isKeyboardVisible ? 40 : 48,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 채팅 헤더 (매칭 전/후 상태에 따라 다른 UI)
  Widget _buildChatHeader(
      BuildContext context,
      GroupController groupController,
      ChatController chatController,
      ) {
    final isMatched = groupController.isMatched;
    final groupMembers = groupController.groupMembers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.gray200)),
      ),
      child: Column(
        children: [
          // 헤더 타이틀
          Row(
            children: [
              Icon(
                isMatched ? Icons.favorite : Icons.group,
                color: isMatched ? AppTheme.successColor : AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isMatched ? '매칭된 상대방과 대화' : '그룹 채팅',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${groupController.groupMembers.length}명',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 매칭 전: 현재 그룹 멤버들 + 초대 상태
          if (!isMatched) ...[_buildInvitationStatus(context, groupController)],
        ],
      ),
    );
  }

  // 초대 상태 표시
  Widget _buildInvitationStatus(
      BuildContext context,
      GroupController groupController,
      ) {
    final sentInvitations = groupController.sentInvitations;
    final pendingCount = sentInvitations
        .where((inv) => inv.status.toString().split('.').last == 'pending')
        .length;

    // [UPDATED] 매칭 중이거나, (방장이고 + 대기중인 초대 없고 + 인원 미달일 때) 표시
    if (groupController.isMatching ||
        (groupController.isOwner && // 방장 권한 체크 추가
            pendingCount == 0 &&
            groupController.currentGroup!.memberIds.length < 5)) {
      return GestureDetector(
        onTap: () {
          // 매칭 중이 아닐 때만(즉, 초대 버튼일 때만) 클릭 허용
          if (!groupController.isMatching) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InviteFriendView(),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                groupController.isMatching
                    ? Icons.hourglass_empty
                    : Icons.person_add,
                color: groupController.isMatching
                    ? Colors.orange
                    : AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupController.isMatching
                      ? '매칭 중...'
                      : '친구를 더 초대해보세요! (${groupController.currentGroup!.memberIds.length}/5명)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: groupController.isMatching
                        ? Colors.orange
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 초대 대기 중인 경우
    if (pendingCount > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$pendingCount명의 친구가 초대 응답을 기다리고 있습니다',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 아무 상태도 아닐 때 빈 공간 반환 (필수)
    return const SizedBox.shrink();
  }

  // 빈 메시지 뷰 (매칭 전/후에 따라 다른 메시지)
  Widget _buildEmptyMessageView(GroupController groupController) {
    final isMatched = groupController.isMatched;
    final memberCount = groupController.groupMembers.length;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMatched ? Icons.chat_bubble_outline : Icons.group_outlined,
            size: 64,
            color: AppTheme.gray400,
          ),
          const SizedBox(height: 16),
          Text(
            isMatched
                ? '매칭이 성공했습니다!\n상대방과 대화를 시작해보세요!'
                : memberCount > 1
                ? '그룹 채팅이 시작되었습니다!\n친구들과 대화를 나누세요!'
                : '아직 그룹에 혼자 있습니다.\n친구들을 초대해보세요!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              height: 1.4,
            ),
          ),

          // [UPDATED] 방장 권한 체크 추가
          if (!isMatched && memberCount == 1 && groupController.isOwner) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InviteFriendView(),
                  ),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('친구 초대하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
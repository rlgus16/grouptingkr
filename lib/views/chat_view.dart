import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/group_controller.dart';
import '../controllers/chat_controller.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final chatController = context.read<ChatController>();
          _chatController = chatController;
          chatController.startMessageStream(widget.groupId);
        } catch (e) {
          // print('ChatView initState 에러: $e');
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
        // print('ChatController 참조 저장 실패: $e');
      }
    }
  }

  @override
  void dispose() {
    // 안전하게 ChatController 정리
    try {
      _chatController?.clearData();
    } catch (e) {
      // print('ChatController 정리 중 에러: $e');
    }
    _chatController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: Consumer2<GroupController, ChatController>(
        builder: (context, groupController, chatController, _) {
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
                        padding: const EdgeInsets.all(16),
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

              // 메시지 입력 영역
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.gray200)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) async {
                            await chatController.sendMessage();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          await chatController.sendMessage();
                        },
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
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
    final currentGroup = groupController.currentGroup!;
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
                '${groupMembers.length}명',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 매칭 전: 현재 그룹 멤버들 + 초대 상태
          if (!isMatched) ...[
            _buildPreMatchMembers(context, groupController),
            if (currentGroup.memberIds.length < 5)
              _buildInvitationStatus(context, groupController),
          ],
          
          // 매칭 후: 모든 참여자들
          if (isMatched)
            _buildMatchedMembers(context, chatController),
        ],
      ),
    );
  }

  // 매칭 전 그룹 멤버들 표시
  Widget _buildPreMatchMembers(
    BuildContext context,
    GroupController groupController,
  ) {
    final groupMembers = groupController.groupMembers;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              '현재 그룹 멤버',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: groupMembers.length,
            itemBuilder: (context, index) {
              final member = groupMembers[index];
              final isOwner = groupController.currentGroup!.isOwner(member.uid);
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileDetailView(user: member),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      MemberAvatar(
                        imageUrl: member.mainProfileImage,
                        name: member.nickname,
                        isOwner: isOwner,
                        size: 40,
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 초대 상태 표시
  Widget _buildInvitationStatus(
    BuildContext context,
    GroupController groupController,
  ) {
    final sentInvitations = groupController.sentInvitations;
    final pendingCount = sentInvitations.where((inv) => inv.status.toString().split('.').last == 'pending').length;
    
    if (pendingCount == 0 && groupController.currentGroup!.memberIds.length < 5) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '친구를 더 초대해보세요! (${groupController.currentGroup!.memberIds.length}/5명)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    if (pendingCount > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
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
    
    return const SizedBox.shrink();
  }

  // 매칭 후 모든 멤버들 표시
  Widget _buildMatchedMembers(
    BuildContext context,
    ChatController chatController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, size: 16, color: AppTheme.successColor),
            const SizedBox(width: 4),
            Text(
              '모든 참여자',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: chatController.matchedGroupMembers.length,
            itemBuilder: (context, index) {
              final member = chatController.matchedGroupMembers[index];
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileDetailView(user: member),
                      ),
                    );
                  },
                  child: MemberAvatar(
                    imageUrl: member.mainProfileImage,
                    name: member.nickname,
                    isMatched: true,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
          if (!isMatched && memberCount == 1) ...[
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}

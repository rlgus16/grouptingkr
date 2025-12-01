import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/group_controller.dart';
import '../models/invitation_model.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_toast.dart';

class InviteFriendView extends StatefulWidget {
  const InviteFriendView({super.key});

  @override
  State<InviteFriendView> createState() => _InviteFriendViewState();
}

class _InviteFriendViewState extends State<InviteFriendView> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _inviteFriend() async {
    if (!_formKey.currentState!.validate()) return;

    final groupController = context.read<GroupController>();
    final success = await groupController.inviteFriend(
      nickname: _nicknameController.text.trim(),
      message: _messageController.text.trim().isNotEmpty
          ? _messageController.text.trim()
          : null,
    );

    if (success && mounted) {
      CustomToast.showSuccess(context, '초대를 보냈어요!');
      // 입력 필드 초기화
      _nicknameController.clear();
      _messageController.clear();
      // 포커스 해제
      FocusScope.of(context).unfocus();
    } else if (mounted && groupController.errorMessage != null) {
      CustomToast.showError(context, groupController.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 초대')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 안내 메시지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '초대 안내',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• 친구의 닉네임을 정확히 입력해주세요\n'
                        '• 최대 5명까지 그룹을 구성할 수 있습니다',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 현재 그룹 인원 현황
                Consumer<GroupController>(
                  builder: (context, groupController, _) {
                    final currentCount =
                        groupController.currentGroup?.memberCount ?? 1;
                    final remainingSlots = 5 - currentCount;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '현재 그룹 인원',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '$currentCount / 5명',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 닉네임 입력
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: '친구 닉네임',
                    hintText: '초대할 친구의 닉네임을 입력하세요',
                    prefixIcon: Icon(Icons.person_search),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '닉네임을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 초대 메시지 (선택사항)
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: '초대 메시지 (선택사항)',
                    hintText: '친구에게 전할 메시지를 입력하세요',
                    prefixIcon: Icon(Icons.message_outlined),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  maxLength: 50,
                ),
                const SizedBox(height: 32),

                // 초대하기 버튼
                Consumer<GroupController>(
                  builder: (context, groupController, _) {
                    if (groupController.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ElevatedButton(
                      onPressed: _inviteFriend,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text('초대하기'),
                    );
                  },
                ),

                // 에러 메시지
                Consumer<GroupController>(
                  builder: (context, groupController, _) {
                    if (groupController.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          groupController.errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.errorColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 32),

                // 보낸 초대 목록
                Consumer<GroupController>(
                  builder: (context, groupController, _) {
                    if (groupController.sentInvitations.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          '보낸 초대',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...groupController.sentInvitations.map((invitation) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                child: Icon(
                                  Icons.mail_outline,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(invitation.toUserNickname),
                              subtitle: Text(
                                invitation.status == InvitationStatus.pending
                                    ? '응답 대기 중'
                                    : invitation.status ==
                                          InvitationStatus.accepted
                                    ? '수락됨'
                                    : invitation.status ==
                                          InvitationStatus.rejected
                                    ? '거절됨'
                                    : '만료됨',
                                style: TextStyle(
                                  color:
                                      invitation.status ==
                                          InvitationStatus.accepted
                                      ? AppTheme.successColor
                                      : invitation.status ==
                                            InvitationStatus.rejected
                                      ? AppTheme.errorColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              trailing:
                                  invitation.status == InvitationStatus.pending
                                  ? const Icon(
                                      Icons.access_time,
                                      color: AppTheme.textSecondary,
                                    )
                                  : invitation.status ==
                                        InvitationStatus.accepted
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.successColor,
                                    )
                                  : invitation.status ==
                                        InvitationStatus.rejected
                                  ? const Icon(
                                      Icons.cancel,
                                      color: AppTheme.errorColor,
                                    )
                                  : const Icon(
                                      Icons.timer_off,
                                      color: AppTheme.textSecondary,
                                    ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

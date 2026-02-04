import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/group_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/member_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../views/profile_detail_view.dart';
import '../widgets/custom_toast.dart';

class InvitationListView extends StatefulWidget {
  const InvitationListView({super.key});

  @override
  State<InvitationListView> createState() => _InvitationListViewState();
}

class _InvitationListViewState extends State<InvitationListView> {
  final Set<String> _processingInvitations = <String>{};

  Future<void> _handleInvitation(String invitationId, bool accept) async {
    if (_processingInvitations.contains(invitationId)) return;

    final l10n = AppLocalizations.of(context)!;
    final groupController = context.read<GroupController>();

    if (accept && groupController.currentGroup != null) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.invitationMoveGroupTitle),
          content: Text(l10n.invitationMoveGroupContent),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.gray600),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard',
                ),
              ),
              child: Text(l10n.invitationMoveAction),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _processingInvitations.add(invitationId);
    });

    try {
      final success = accept
          ? await groupController.acceptInvitation(invitationId)
          : await groupController.rejectInvitation(invitationId);

      if (mounted) {
        if (success) {
          if (accept) {
            CustomToast.showSuccess(context, l10n.invitationJoinedSuccess);
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            }
          } else {
            CustomToast.showInfo(context, l10n.invitationRejectedInfo);
          }
        } else if (groupController.errorMessage != null) {
          CustomToast.showError(context, groupController.errorMessage!);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingInvitations.remove(invitationId);
        });
      }
    }
  }
  
  Future<void> _navigateToUserProfile(String userId) async {
    if (userId.isEmpty) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final user = UserModel.fromFirestore(userDoc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileDetailView(user: user),
          ),
        );
      } else {
        if (mounted) {
           CustomToast.showError(context, AppLocalizations.of(context)!.errorUserNotFound);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.errorLoadProfile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: Text(l10n.invitationListTitle),
        backgroundColor: AppTheme.gray50,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<GroupController>(
        builder: (context, groupController, _) {
          if (groupController.receivedInvitations.isEmpty) {
            return _buildEmptyState(l10n);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: groupController.receivedInvitations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final invitation = groupController.receivedInvitations[index];
              final isProcessing = _processingInvitations.contains(invitation.id);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.softShadow,
                  border: Border.all(color: AppTheme.gray100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemberAvatar(
                            imageUrl: invitation.fromUserProfileImage,
                            name: invitation.fromUserNickname,
                            size: 52,
                            onTap: () => _navigateToUserProfile(invitation.fromUserId),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.invitationFrom(invitation.fromUserNickname),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                          fontFamily: 'Pretendard',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(invitation.createdAt, l10n),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.gray500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.invitationNewGroup,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (invitation.message != null &&
                          invitation.message!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '"${invitation.message}"',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.gray800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (!invitation.isValid) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.errorColor.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_off_outlined,
                                  size: 14,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.invitationExpiredLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: (invitation.canRespond && !isProcessing)
                                    ? () => _handleInvitation(invitation.id, false)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.gray300),
                                  foregroundColor: AppTheme.textSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isProcessing
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.textSecondary,
                                    ),
                                  ),
                                )
                                    : Text(l10n.invitationReject),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (invitation.canRespond && !isProcessing)
                                    ? () => _handleInvitation(invitation.id, true)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isProcessing
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                    : Text(
                                  l10n.invitationAccept,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.invitationEmptyTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.invitationEmptyDesc,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final locale = Localizations.localeOf(context);
    final isKorean = locale.languageCode == 'ko';

    if (difference.inMinutes < 1) {
      return l10n.timeJustNow;
    } else if (difference.inHours < 1) {
      return isKorean ? '${difference.inMinutes}분 전' : '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return isKorean ? '${difference.inHours}시간 전' : '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return isKorean ? '${difference.inDays}일 전' : '${difference.inDays}d ago';
    } else {
      return isKorean ? '${date.month}월 ${date.day}일' : '${date.month}/${date.day}';
    }
  }
}
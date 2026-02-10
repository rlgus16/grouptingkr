import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../controllers/auth_controller.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class UserActionHelper {
  static Future<void> showUserOptionsBottomSheet({
    required BuildContext context,
    required UserModel targetUser,
    required String? openChatroomId,
    required bool isChatRoomOwner,
    required bool isTargetUserInChatroom,
    Function(bool isExempted)? onExemptionChanged,
    Function(bool isBlocked)? onBlockChanged,
  }) async {
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null || currentUser.uid == targetUser.uid) return;

    // Check exemption and block status
    final authController = context.read<AuthController>();
    bool isBlocked = authController.blockedUserIds.contains(targetUser.uid);
    bool isExempted = false;

    try {
      final exemptDocId = '${currentUser.uid}_${targetUser.uid}';
      final exemptDoc = await FirebaseFirestore.instance.collection('matchExemptions').doc(exemptDocId).get();
      isExempted = exemptDoc.exists;
    } catch (e) {
      debugPrint('Error fetching user status: $e');
    }

    if (!context.mounted) return;
    
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isChatRoomOwner && isTargetUserInChatroom && openChatroomId != null)
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor),
                    title: Text(l10n.userActionRemove, style: const TextStyle(color: AppTheme.errorColor)),
                    onTap: () {
                      Navigator.pop(context);
                      showRemoveFromChatroomDialog(context, targetUser, openChatroomId);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                  title: Text(l10n.profileDetailReport),
                  onTap: () {
                    Navigator.pop(context);
                    showReportDialog(context, targetUser);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isExempted ? Icons.person_add_outlined : Icons.person_off_outlined,
                    color: isExempted ? AppTheme.primaryColor : Colors.orange,
                  ),
                  title: Text(isExempted ? l10n.profileDetailUnexempt : l10n.profileDetailExempt),
                  subtitle: isExempted ? null : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 12, color: AppTheme.warningColor),
                      const SizedBox(width: 4),
                      Text(l10n.costFiveTing, style: const TextStyle(color: AppTheme.warningColor, fontSize: 12)),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet first
                    if (isExempted) {
                      showUnexemptDialog(context, targetUser, () {
                        if (onExemptionChanged != null) onExemptionChanged(false);
                      });
                    } else {
                      showExemptFromMatchingDialog(context, targetUser, () {
                        if (onExemptionChanged != null) onExemptionChanged(true);
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                    color: isBlocked ? AppTheme.successColor : Colors.red,
                  ),
                  title: Text(isBlocked ? l10n.settingsUnblock : l10n.profileDetailBlock),
                  onTap: () {
                    Navigator.pop(context);
                    if (isBlocked) {
                      unblockUser(context, targetUser, () {
                         if (onBlockChanged != null) onBlockChanged(false);
                      });
                    } else {
                      showBlockDialog(context, targetUser, () {
                        if (onBlockChanged != null) onBlockChanged(true);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  static void showRemoveFromChatroomDialog(BuildContext context, UserModel user, String chatroomId) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.userActionRemove),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.userActionRemoveConfirm(user.nickname)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final chatroomRef = FirebaseFirestore.instance.collection('openChatrooms').doc(chatroomId);

                await chatroomRef.update({
                  'participants': FieldValue.arrayRemove([user.uid]),
                  'bannedUsers': FieldValue.arrayUnion([user.uid]),
                  'participantCount': FieldValue.increment(-1),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  // Check if we need to close another screen (like ProfileDetailView) - handled by caller if needed
                  // or just show snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.userActionRemoveSuccess(user.nickname))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.commonErrorWithValue(e.toString()))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.userActionBan),
          ),
        ],
      ),
    );
  }

  static void showReportDialog(BuildContext context, UserModel user) {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final reasons = [
      l10n.profileDetailReasonBadPhoto,
      l10n.profileDetailReasonAbuse,
      l10n.profileDetailReasonSpam,
      l10n.profileDetailReasonFraud,
      l10n.profileDetailReasonOther,
    ];
    String selectedReason = reasons[0];
    final ImagePicker picker = ImagePicker();
    XFile? attachedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.profileDetailReportTitle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profileDetailReportReason, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedReason = value);
                    }
                  },
                  child: Column(
                    children: reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppTheme.errorColor,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: l10n.profileDetailReportContent,
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) setState(() => attachedImage = image);
                    } catch (e) {
                      debugPrint('Image selection error: $e');
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(attachedImage == null ? l10n.profileDetailReportPhoto : l10n.profileDetailReportPhotoChange),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.gray300),
                  ),
                ),
                if (attachedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.successColor, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            attachedImage!.name,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailReportEnterContent)),
                  );
                  return;
                }
                try {
                  final currentUser = context.read<AuthController>().currentUserModel;
                  if (currentUser == null) return;
                  Navigator.pop(context);

                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': currentUser.uid,
                    'reportedUserId': user.uid,
                    'category': selectedReason,
                    'description': reasonController.text.trim(),
                    'hasImage': attachedImage != null,
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  await _sendReportEmail(
                    context: context,
                    reporter: currentUser,
                    targetUser: user,
                    category: selectedReason,
                    description: reasonController.text.trim(),
                    imagePath: attachedImage?.path,
                  );
                } catch (e) {
                  debugPrint('Report failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.profileDetailReportSubmit),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _sendReportEmail({
    required BuildContext context,
    required UserModel reporter,
    required UserModel targetUser,
    required String category,
    required String description,
    String? imagePath,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    const String developerEmail = 'sprt.groupting@gmail.com';
    final String body = '''
[User Report]
- Reporter: ${reporter.nickname} (${reporter.uid})
- Target: ${targetUser.nickname} (${targetUser.uid})
- Reason: $category
- Content: $description
--------------------------------
App Version: 1.0.0
Platform: ${Theme.of(context).platform}
''';

    final Email email = Email(
      body: body,
      subject: '[Groupting Report] ${targetUser.nickname} User Report',
      recipients: [developerEmail],
      attachmentPaths: imagePath != null ? [imagePath] : null,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDetailEmailFailed)),
        );
      }
    }
  }

  static void showExemptFromMatchingDialog(BuildContext context, UserModel user, VoidCallback onSuccess) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;

    const int exemptionCost = 5;
    if (currentUser.tingBalance < exemptionCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileEditInsufficientTings)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDetailExemptTitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.profileDetailExemptConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authController = context.read<AuthController>();
                
                // Deduct Ting first
                final userService = UserService();
                final deducted = await userService.deductTings(currentUser.uid, exemptionCost);
                if (!deducted) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.profileEditInsufficientTings)),
                    );
                  }
                  return;
                }

                final exemptDocId = '${currentUser.uid}_${user.uid}';

                await FirebaseFirestore.instance.collection('matchExemptions').doc(exemptDocId).set({
                  'exempterId': currentUser.uid,
                  'exempterNickname': currentUser.nickname,
                  'exemptedId': user.uid,
                  'exemptedNickname': user.nickname,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  await authController.refreshCurrentUser();
                  Navigator.pop(context);
                  onSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailExempted)),
                  );
                }
              } catch (e) {
                debugPrint('Exempt from matching failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.profileDetailExempt),
          ),
        ],
      ),
    );
  }

  static void showUnexemptDialog(BuildContext context, UserModel user, VoidCallback onSuccess) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDetailUnexempt),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.profileDetailUnexemptConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = context.read<AuthController>().currentUserModel;
                if (currentUser == null) return;
                final exemptDocId = '${currentUser.uid}_${user.uid}';

                await FirebaseFirestore.instance.collection('matchExemptions').doc(exemptDocId).delete();

                if (context.mounted) {
                  Navigator.pop(context);
                  onSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailUnexempted)),
                  );
                }
              } catch (e) {
                debugPrint('Unexempt failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.profileDetailUnexempt),
          ),
        ],
      ),
    );
  }

  static void showBlockDialog(BuildContext context, UserModel user, VoidCallback onSuccess) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDetailBlockTitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.profileDetailBlockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authController = context.read<AuthController>();
                final currentUser = authController.currentUserModel;
                if (currentUser == null) return;
                final blockDocId = '${currentUser.uid}_${user.uid}';

                await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).set({
                  'blockerId': currentUser.uid,
                  'blockerNickname': currentUser.nickname,
                  'blockedId': user.uid,
                  'blockedNickname': user.nickname,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  onSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailBlocked)),
                  );
                }
              } catch (e) {
                debugPrint('Block failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.profileDetailBlock),
          ),
        ],
      ),
    );
  }

  static Future<void> unblockUser(BuildContext context, UserModel user, VoidCallback onSuccess) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final authController = context.read<AuthController>();
      final currentUser = authController.currentUserModel;
      if (currentUser == null) return;
      final blockDocId = '${currentUser.uid}_${user.uid}';

      await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).delete();
      
      if (context.mounted) {
        onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDetailUnblocked)),
        );
      }
    } catch (e) {
      debugPrint('Unblock failed: $e');
    }
  }
}

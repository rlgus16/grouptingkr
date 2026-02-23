import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../views/profile_detail_view.dart';
import '../utils/user_action_helper.dart';
import 'member_avatar.dart';
import 'story_comments_sheet.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryCard extends StatelessWidget {
  final StoryModel story;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback? onDelete; // null if not author

  const StoryCard({
    super.key,
    required this.story,
    required this.currentUserId,
    required this.onLike,
    this.onDelete,
  });

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 7) {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLiked = story.likes.contains(currentUserId);
    final isAuthor = story.authorId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Author Info + Options)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                MemberAvatar(
                  imageUrl: story.authorProfileUrl,
                  name: story.authorNickname,
                  size: 40,
                  onTap: () async {
                    try {
                      final doc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(story.authorId)
                          .get();
                      if (doc.exists && context.mounted) {
                        final userModel = UserModel.fromFirestore(doc);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileDetailView(user: userModel),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error fetching user profile: $e');
                    }
                  },
                  onLongPress: () async {
                    if (isAuthor) return; // Don't show options for own avatar

                    try {
                      final doc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(story.authorId)
                          .get();
                      if (doc.exists && context.mounted) {
                        final userModel = UserModel.fromFirestore(doc);
                        UserActionHelper.showUserOptionsBottomSheet(
                          context: context,
                          targetUser: userModel,
                          openChatroomId: null,
                          isChatRoomOwner: false,
                          isTargetUserInChatroom: false,
                        );
                      }
                    } catch (e) {
                      debugPrint('Error fetching user profile for options: $e');
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.authorNickname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _formatTime(story.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAuthor)
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppTheme.gray500),
                    onPressed: () {
                      _showOptionsMenu(context, l10n);
                    },
                  ),
              ],
            ),
          ),
          
          // 2. Text Content (if any)
          if (story.text != null && story.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                story.text!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            
          const SizedBox(height: 8),

          // 3. Image Content (if any)
          if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
            Container(
              constraints: const BoxConstraints(
                minHeight: 200,
                maxHeight: 400,
              ),
              width: double.infinity,
              color: AppTheme.gray100,
              child: CachedNetworkImage(
                imageUrl: story.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.error_outline,
                  color: AppTheme.errorColor,
                ),
              ),
            ),

          // 4. Footer (Likes)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppTheme.secondaryColor : AppTheme.gray500,
                  ),
                  onPressed: onLike,
                ),
                Text(
                  '${story.likes.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Add Comments Icon
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined, color: AppTheme.gray500),
                  onPressed: () {
                    final currentUser = context.read<AuthController>().currentUserModel;
                    if (currentUser != null) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent, // transparent to see rounded corners of sheet
                        builder: (context) => StoryCommentsSheet(
                          storyId: story.id,
                          currentUser: currentUser,
                        ),
                      );
                    }
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stories')
                      .doc(story.id)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final commentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Text(
                      '$commentCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                title: Text(
                  l10n.commonDelete,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                onTap: () async {
                  Navigator.pop(context); // close bottom sheet
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.commonDelete),
                      content: Text(l10n.storyDeleteConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.commonCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            l10n.commonDelete,
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && onDelete != null) {
                    onDelete!();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

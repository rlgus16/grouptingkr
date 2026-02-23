import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/story_controller.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/story_card.dart';
import 'create_story_view.dart';

class StoryView extends StatelessWidget {
  const StoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.watch<AuthController>();
    final currentUser = authController.currentUserModel;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Consumer<StoryController>(
        builder: (context, controller, child) {
          final filteredStories = controller.stories.where((story) {
            return !authController.blockedUserIds.contains(story.authorId);
          }).toList();

          if (filteredStories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: AppTheme.gray400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.storyEmpty,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // The stream handles real-time updates automatically,
              // but we can provide a dummy delay for UX if desired.
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredStories.length,
              itemBuilder: (context, index) {
                final story = filteredStories[index];
                return StoryCard(
                  story: story,
                  currentUserId: currentUser?.uid ?? '',
                  onLike: () {
                    if (currentUser != null) {
                      controller.toggleLike(story.id, currentUser.uid);
                    }
                  },
                  onDelete: story.authorId == currentUser?.uid
                      ? () => controller.deleteStory(story.id, story.imageUrl)
                      : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (currentUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateStoryView(),
              ),
            );
          }
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/story_controller.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/story_card.dart';
import 'create_story_view.dart';

class StoryView extends StatefulWidget {
  const StoryView({super.key});

  @override
  State<StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends State<StoryView> {
  String _genderFilter = 'any'; // 'any', 'male', 'female'

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.gray700,
      ),
    );
  }

  Widget _buildGenderChip(String label, String value, String currentSelection, Function(String) onSelected) {
    final bool isSelected = value == currentSelection;
    final double fontSize = label.length > 3 ? 12 : 13;

    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.gray300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha:0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.gray600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: fontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, AppLocalizations l10n) {
    String tempGenderFilter = _genderFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.gray300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.storyFilterTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gray800,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.gray600),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Gender Section
                  _buildFilterSectionTitle(l10n.homeFilterGender),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildGenderChip(l10n.storyFilterAny, 'any', tempGenderFilter, (val) => setModalState(() => tempGenderFilter = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderChip(l10n.storyFilterMale, '남', tempGenderFilter, (val) => setModalState(() => tempGenderFilter = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderChip(l10n.storyFilterFemale, '여', tempGenderFilter, (val) => setModalState(() => tempGenderFilter = val))),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Apply Button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _genderFilter = tempGenderFilter;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.homeFilterApply,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.watch<AuthController>();
    final currentUser = authController.currentUserModel;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(l10n.mainTabStory),
        backgroundColor: AppTheme.surfaceColor,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            iconSize: 28,
            onPressed: () => _showFilterDialog(context, l10n),
          ),
        ],
      ),
      body: Consumer<StoryController>(
        builder: (context, controller, child) {
          final filteredStories = controller.stories.where((story) {
            // Block check
            if (authController.blockedUserIds.contains(story.authorId)) return false;
            
            // Gender filter check
            if (_genderFilter != 'any') {
              if (story.authorGender != _genderFilter) return false;
            }
            
            return true;
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

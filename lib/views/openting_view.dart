import 'package:flutter/material.dart';
import 'openting_list_view.dart';
import 'story_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/profile_incomplete_card.dart';
import 'home_view.dart';

class OpentingView extends StatelessWidget {
  const OpentingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 0, // Hide the standard appbar space, we just want the TabBar
          bottom: TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: AppTheme.gray400,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: l10n.opentingTabList),
              Tab(text: l10n.opentingTabStory),
            ],
          ),
        ),
        body: Consumer<AuthController>(
          builder: (context, authController, _) {
            final user = authController.currentUserModel;
            final bool isProfileIncomplete = user != null && 
                (user.nickname.isEmpty || 
                 user.height <= 0 || 
                 user.activityArea.isEmpty || 
                 user.introduction.isEmpty);

            if (isProfileIncomplete) {
              return Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeView()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: ProfileIncompleteCard(),
                  ),
                ],
              );
            }

            return const TabBarView(
              children: [
                OpenChatroomListView(),
                StoryView(),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'openting_list_view.dart';
import 'story_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/app_theme.dart';

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
        body: const TabBarView(
          children: [
            OpenChatroomListView(),
            StoryView(),
          ],
        ),
      ),
    );
  }
}

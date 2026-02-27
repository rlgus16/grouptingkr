import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../views/profile_edit_view.dart';

class ProfileIncompleteCard extends StatelessWidget {
  const ProfileIncompleteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        final user = authController.currentUserModel;
        final firebaseUser = authController.firebaseService.currentUser;

        // 디버깅용 로그
        if (user != null) {
          debugPrint('홈 화면 - 사용자 정보: uid=${user.uid}, email=${firebaseUser?.email ?? ""}, phone=${user.phoneNumber}, isComplete=${user.isProfileComplete}');
        } else {
          debugPrint('홈 화면 - 사용자 정보 없음 (currentUserModel이 null)');
          debugPrint('홈 화면 - Firebase Auth 상태: ${authController.isLoggedIn}');
        }
        
        final l10n = AppLocalizations.of(context)!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.orange.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.homeProfileComplete,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.homeProfileCompleteDesc,
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.homeProfileCompleteLong,
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (user == null) return;
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditView()));
                        },
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(l10n.homeProfileNow),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
  }
}

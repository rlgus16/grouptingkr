import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../controllers/locale_controller.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // 설정 상태 변수들
  bool _matchingNotifications = true;
  bool _invitationNotifications = true;
  bool _messageNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final user = context.read<AuthController>().currentUserModel;
    if (user != null) {
      setState(() {
        _matchingNotifications = user.matchingNotification;
        _invitationNotifications = user.invitationNotification;
        _messageNotifications = user.chatNotification;
      });
    }
  }

  Future<void> _updateNotificationSetting({
    bool? matching,
    bool? invitation,
    bool? chat,
  }) async {
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;

    if (user == null) return;

    setState(() {
      if (matching != null) _matchingNotifications = matching;
      if (invitation != null) _invitationNotifications = invitation;
      if (chat != null) _messageNotifications = chat;
    });

    try {
      final Map<String, dynamic> updates = {};
      if (matching != null) updates['matchingNotification'] = matching;
      if (invitation != null) updates['invitationNotification'] = invitation;
      if (chat != null) updates['chatNotification'] = chat;

      if (updates.isNotEmpty) {
        await UserService().usersCollection.doc(user.uid).update(updates);
      }
      await authController.refreshCurrentUser();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.gray50,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // 1. 알림 설정 섹션
            _buildSectionHeader(l10n.settingsNotification),
            _buildSectionContainer(
              children: [
                _buildSwitchTile(
                  title: l10n.settingsNotiMatch,
                  subtitle: l10n.settingsNotiMatch,
                  icon: Icons.favorite_border,
                  value: _matchingNotifications,
                  onChanged: (v) => _updateNotificationSetting(matching: v),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  title: l10n.settingsNotiInvite,
                  subtitle: l10n.settingsNotiInvite,
                  icon: Icons.mail_outline,
                  value: _invitationNotifications,
                  onChanged: (v) => _updateNotificationSetting(invitation: v),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  title: l10n.settingsNotiChat,
                  subtitle: l10n.settingsNotiChat,
                  icon: Icons.chat_bubble_outline,
                  value: _messageNotifications,
                  onChanged: (v) => _updateNotificationSetting(chat: v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. 계정 관리 섹션
            _buildSectionHeader(l10n.settingsAccount),
            _buildSectionContainer(
              children: [
                _buildMenuTile(
                  icon: Icons.vpn_key_outlined,
                  title: l10n.settingsChangePw,
                  onTap: _showChangePasswordDialog,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.person_off_outlined,
                  title: l10n.settingsBlock,
                  onTap: _showBlockedUsersDialog,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.do_not_disturb_on_outlined,
                  title: l10n.settingsExemption,
                  onTap: _showExemptedUsersDialog,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.delete_outline,
                  title: l10n.settingsDeleteAccount,
                  textColor: AppTheme.errorColor,
                  iconColor: AppTheme.errorColor.withValues(alpha: 0.1),
                  iconDataColor: AppTheme.errorColor,
                  onTap: _showAccountDeletionDialog,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. 고객지원 및 정보 섹션
            _buildSectionHeader(l10n.settingsInfo),
            _buildSectionContainer(
              children: [
                Consumer<LocaleController>(
                  builder: (context, localeController, _) {
                    return _buildMenuTile(
                      icon: Icons.language,
                      title: '언어 / Language',
                      trailing: Text(
                        localeController.currentLanguageName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () => _showLanguageDialog(),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.verified_user_outlined,
                  title: l10n.settingsPrivacy,
                  onTap: _showPrivacyPolicy,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.description_outlined,
                  title: l10n.settingsTerms,
                  onTap: _showTermsOfService,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.star_outline,
                  title: '⭐ Rate App',
                  onTap: _rateApp,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.info_outline,
                  title: l10n.settingsAppVersion,
                  trailing: const Text(
                    '1.0.0',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _checkForUpdates,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.gray600,
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: AppTheme.gray100),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppTheme.primaryColor,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: AppTheme.gray300,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
    Color? iconDataColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor ?? AppTheme.gray100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconDataColor ?? AppTheme.gray700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor ?? AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.gray400,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Actions & Dialogs ---

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<LocaleController>(
          builder: (context, localeController, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        '언어 선택 / Select Language',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // Korean option
                    _buildLanguageOption(
                      locale: const Locale('ko'),
                      name: '한국어',
                      isSelected: localeController.locale.languageCode == 'ko',
                      onTap: () {
                        localeController.setLocale(const Locale('ko'));
                        Navigator.pop(context);
                      },
                    ),
                    // English option
                    _buildLanguageOption(
                      locale: const Locale('en'),
                      name: 'English',
                      isSelected: localeController.locale.languageCode == 'en',
                      onTap: () {
                        localeController.setLocale(const Locale('en'));
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required Locale locale,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyPolicy() async {
    const url = 'https://flossy-sword-5a1.notion.site/2bee454bf6f580ad8c6df10d571c93a9';
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _showTermsOfService() async {
    const url = 'https://www.notion.so/2c0e454bf6f5805f8d5efdc00ba53bdb';
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // ignore
    }
  }

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Consumer<AuthController>(
        builder: (context, authController, child) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(l10n.settingsChangePw, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: authController.isLoading
                ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.commonLoading),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(currentPasswordController, 'Current Password'),
                const SizedBox(height: 12),
                _buildDialogTextField(newPasswordController, 'New Password'),
                const SizedBox(height: 12),
                _buildDialogTextField(confirmPasswordController, 'Confirm Password'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              if (!authController.isLoading)
                TextButton(
                  onPressed: () async {
                    final currentPassword = currentPasswordController.text.trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text.trim();

                    if (currentPassword.isEmpty || newPassword.isEmpty) return;
                    if (newPassword.length < 6 || newPassword != confirmPassword) return;

                    final success = await authController.changePassword(currentPassword, newPassword);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Password changed' : 'Failed: ${authController.errorMessage}'),
                          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.commonConfirm, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showBlockedUsersDialog() {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.settingsBlock, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('blocks')
                .where('blockerId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text(l10n.settingsBlockEmpty, style: const TextStyle(color: AppTheme.textSecondary)));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['blockedNickname'] ?? 'Unknown'),
                    trailing: TextButton(
                      onPressed: () => FirebaseFirestore.instance.collection('blocks').doc(docs[index].id).delete(),
                      child: Text(l10n.settingsUnblock, style: const TextStyle(color: AppTheme.primaryColor)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose, style: const TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showExemptedUsersDialog() {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.settingsExemption, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matchExemptions')
                .where('exempterId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text(l10n.settingsExemptionEmpty, style: const TextStyle(color: AppTheme.textSecondary)));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['exemptedNickname'] ?? 'Unknown'),
                    trailing: TextButton(
                      onPressed: () => FirebaseFirestore.instance.collection('matchExemptions').doc(docs[index].id).delete(),
                      child: Text(l10n.settingsExemptionRemove, style: const TextStyle(color: AppTheme.primaryColor)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose, style: const TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showAccountDeletionDialog() {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.settingsDeleteAccount, style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
        content: const Text(
          'Deleting your account will permanently remove all data and cannot be undone.\nAre you sure?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              elevation: 0,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion() {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => Consumer<AuthController>(
        builder: (context, authController, child) {
          return AlertDialog(
            title: const Text('Final Confirmation'),
            content: authController.isLoading
                ? Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), const Text('Deleting...')])
                : Text(l10n.settingsDeleteAccountConfirm),
            actions: [
              if (!authController.isLoading)
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
              if (!authController.isLoading)
                ElevatedButton(
                  onPressed: () async {
                    final success = await authController.deleteAccount();
                    if (mounted) {
                      Navigator.pop(context);
                      if (success) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                  child: Text(l10n.commonDelete),
                ),
            ],
          );
        },
      ),
    );
  }

  void _checkForUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are using the latest version.')),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening app store... (Coming soon)')),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정 저장에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50, // 밝은 회색 배경
      appBar: AppBar(
        title: const Text('설정'),
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
            _buildSectionHeader('알림'),
            _buildSectionContainer(
              children: [
                _buildSwitchTile(
                  title: '매칭 알림',
                  subtitle: '새로운 매칭 알림 수신',
                  icon: Icons.favorite_border,
                  value: _matchingNotifications,
                  onChanged: (v) => _updateNotificationSetting(matching: v),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  title: '초대 알림',
                  subtitle: '그룹 초대 알림 수신',
                  icon: Icons.mail_outline,
                  value: _invitationNotifications,
                  onChanged: (v) => _updateNotificationSetting(invitation: v),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  title: '메세지 알림',
                  subtitle: '채팅 메세지 알림 수신',
                  icon: Icons.chat_bubble_outline,
                  value: _messageNotifications,
                  onChanged: (v) => _updateNotificationSetting(chat: v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. 계정 관리 섹션
            _buildSectionHeader('계정'),
            _buildSectionContainer(
              children: [
                _buildMenuTile(
                  icon: Icons.vpn_key_outlined,
                  title: '비밀번호 변경',
                  onTap: _showChangePasswordDialog,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.person_off_outlined,
                  title: '차단 관리',
                  onTap: _showBlockedUsersDialog,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.delete_outline,
                  title: '계정 삭제',
                  textColor: AppTheme.errorColor,
                  iconColor: AppTheme.errorColor.withValues(alpha: 0.1),
                  iconDataColor: AppTheme.errorColor,
                  onTap: _showAccountDeletionDialog,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. 고객지원 및 정보 섹션
            _buildSectionHeader('정보 및 지원'),
            _buildSectionContainer(
              children: [
                _buildMenuTile(
                  icon: Icons.verified_user_outlined,
                  title: '개인정보 처리방침',
                  onTap: _showPrivacyPolicy,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.description_outlined,
                  title: '서비스 이용약관',
                  onTap: _showTermsOfService,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.star_outline,
                  title: '앱 평가하기',
                  onTap: _rateApp,
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.info_outline,
                  title: '앱 버전',
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

  // --- Actions & Dialogs (기존 로직 유지) ---

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
            title: const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: authController.isLoading
                ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('처리 중입니다...'),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(currentPasswordController, '현재 비밀번호'),
                const SizedBox(height: 12),
                _buildDialogTextField(newPasswordController, '새 비밀번호'),
                const SizedBox(height: 12),
                _buildDialogTextField(confirmPasswordController, '새 비밀번호 확인'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              if (!authController.isLoading)
                TextButton(
                  onPressed: () async {
                    // (기존 로직 동일)
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
                          content: Text(success ? '비밀번호가 변경되었습니다.' : '변경 실패: ${authController.errorMessage}'),
                          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                  child: const Text('변경', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
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
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('차단 관리', style: TextStyle(fontWeight: FontWeight.bold)),
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
                return const Center(child: Text('차단한 사용자가 없습니다.', style: TextStyle(color: AppTheme.textSecondary)));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['blockedNickname'] ?? '알 수 없는 사용자'),
                    trailing: TextButton(
                      onPressed: () => FirebaseFirestore.instance.collection('blocks').doc(docs[index].id).delete(),
                      child: const Text('해제', style: TextStyle(color: AppTheme.primaryColor)),
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
            child: const Text('닫기', style: TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showAccountDeletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('계정 삭제', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
        content: const Text(
          '계정을 삭제하면 모든 데이터가 영구적으로 삭제되며 복구할 수 없습니다.\n정말 삭제하시겠습니까?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
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
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion() {
    showDialog(
      context: context,
      builder: (context) => Consumer<AuthController>(
        builder: (context, authController, child) {
          return AlertDialog(
            title: const Text('최종 확인'),
            content: authController.isLoading
                ? const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('삭제 중...')])
                : const Text('정말로 삭제합니다.'),
            actions: [
              if (!authController.isLoading)
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
                  child: const Text('최종 삭제'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _checkForUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 최신 버전을 사용 중입니다.')),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('앱스토어로 이동합니다... (준비중)')),
    );
  }
}
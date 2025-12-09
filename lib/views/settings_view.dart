import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../services/user_service.dart'; // [추가] UserService import
import '../utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 설정 페이지
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // 설정 상태 변수들
  bool _matchingNotifications = true;
  bool _invitationNotifications = true; // [수정] 별도 변수 분리
  bool _messageNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // [추가] 설정 불러오기
  }

  // [추가] 사용자 모델에서 설정 값 로드
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

  // [추가] 설정 업데이트 및 저장 로직
  Future<void> _updateNotificationSetting({
    bool? matching,
    bool? invitation,
    bool? chat,
  }) async {
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;

    if (user == null) return;

    // UI 선반영
    setState(() {
      if (matching != null) _matchingNotifications = matching;
      if (invitation != null) _invitationNotifications = invitation;
      if (chat != null) _messageNotifications = chat;
    });

    try {
      // 모델 업데이트
      final updatedUser = user.copyWith(
        matchingNotification: matching,
        invitationNotification: invitation,
        chatNotification: chat,
      );

      // DB 저장
      await UserService().updateUser(updatedUser);
      // 로컬 데이터 갱신
      await authController.refreshCurrentUser();
    } catch (e) {
      // 실패 시 롤백 (선택 사항, 여기서는 간단히 에러 메시지)
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
      appBar: AppBar(
        title: const Text('설정'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 알림 설정 섹션
            _buildSectionCard(
              title: '알림 설정',
              icon: Icons.notifications_outlined,
              children: [
                _buildSwitchTile(
                  title: '매칭 알림',
                  subtitle: '새로운 매칭 알림을 받습니다',
                  value: _matchingNotifications,
                  onChanged: (value) {
                    _updateNotificationSetting(matching: value);
                  },
                ),
                _buildSwitchTile(
                  title: '초대 알림',
                  subtitle: '새로운 초대 알림을 받습니다',
                  value: _invitationNotifications, // [수정] 변수 연결 수정
                  onChanged: (value) {
                    _updateNotificationSetting(invitation: value);
                  },
                ),
                _buildSwitchTile(
                  title: '메세지 알림',
                  subtitle: '새로운 메세지 알림을 받습니다',
                  value: _messageNotifications,
                  onChanged: (value) {
                    _updateNotificationSetting(chat: value);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 개인정보 보호 섹션
            _buildSectionCard(
              title: '개인정보 보호',
              icon: Icons.security_outlined,
              children: [
                _buildMenuTile(
                  icon: Icons.lock_outline,
                  title: '개인정보 처리방침',
                  onTap: () {
                    _showPrivacyPolicy();
                  },
                ),
                _buildMenuTile(
                  icon: Icons.description_outlined,
                  title: '서비스 이용약관',
                  onTap: () {
                    _showTermsOfService();
                  },
                ),
              ],
            ),

            // ... (나머지 섹션들: 계정 관리, 앱 정보 등 기존 코드 유지)
            const SizedBox(height: 20),

            // 계정 관리 섹션
            _buildSectionCard(
              title: '계정 관리',
              icon: Icons.person_outline,
              children: [
                _buildMenuTile(
                  icon: Icons.vpn_key_outlined,
                  title: '비밀번호 변경',
                  onTap: () {
                    _showChangePasswordDialog();
                  },
                ),
                _buildMenuTile(
                  icon: Icons.person_off_outlined,
                  title: '차단 관리',
                  onTap: () {
                    _showBlockedUsersDialog();
                  },
                ),
                _buildMenuTile(
                  icon: Icons.delete_outline,
                  title: '계정 삭제',
                  textColor: AppTheme.errorColor,
                  onTap: () {
                    _showAccountDeletionDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 앱 정보 섹션
            _buildSectionCard(
              title: '앱 정보',
              icon: Icons.info_outline,
              children: [
                _buildMenuTile(
                  icon: Icons.update_outlined,
                  title: '앱 버전',
                  subtitle: '1.0.0',
                  onTap: () {
                    _checkForUpdates();
                  },
                ),
                _buildMenuTile(
                  icon: Icons.rate_review_outlined,
                  title: '앱 평가하기',
                  onTap: () {
                    _rateApp();
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ... (이하 _buildSectionCard, _buildSwitchTile 등 UI 헬퍼 및 다이얼로그 메서드들은 기존과 동일)

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? AppTheme.textSecondary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: textColor ?? AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  // ... (개인정보처리방침, 비밀번호 변경 등 나머지 메서드는 변경 없음)

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
    // 기존 코드 유지
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Consumer<AuthController>(
        builder: (context, authController, child) {
          return AlertDialog(
            title: const Text('비밀번호 변경'),
            content: authController.isLoading
                ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('비밀번호를 변경하고 있습니다...'),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '현재 비밀번호',
                    border: OutlineInputBorder(),
                    hintText: '현재 사용중인 비밀번호를 입력하세요',
                  ),
                  enabled: !authController.isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '새 비밀번호',
                    border: OutlineInputBorder(),
                    hintText: '6자 이상의 새 비밀번호를 입력하세요',
                  ),
                  enabled: !authController.isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '새 비밀번호 확인',
                    border: OutlineInputBorder(),
                    hintText: '새 비밀번호를 다시 입력하세요',
                  ),
                  enabled: !authController.isLoading,
                ),
              ],
            ),
            actions: authController.isLoading
                ? []
                : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final currentPassword = currentPasswordController.text.trim();
                  final newPassword = newPasswordController.text.trim();
                  final confirmPassword = confirmPasswordController.text.trim();

                  if (currentPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('현재 비밀번호를 입력해주세요.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (newPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('새 비밀번호를 입력해주세요.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (newPassword.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('새 비밀번호는 최소 6자 이상이어야 합니다.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (newPassword != confirmPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('새 비밀번호와 확인 비밀번호가 일치하지 않습니다.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final success = await authController.changePassword(currentPassword, newPassword);
                  if (mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('비밀번호가 성공적으로 변경되었습니다.'), backgroundColor: Colors.green),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(authController.errorMessage ?? '비밀번호 변경에 실패했습니다.'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('변경'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBlockedUsersDialog() {
    // 기존 코드 유지
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단 관리'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('blocks')
                .where('blockerId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('목록을 불러오는데 실패했습니다.'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('차단한 사용자가 없습니다.', style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final blockedName = data['blockedNickname'] ?? '알 수 없는 사용자';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: AppTheme.gray100, child: Icon(Icons.person_off, color: Colors.grey, size: 20)),
                    title: Text(blockedName),
                    trailing: TextButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('blocks').doc(docs[index].id).delete();
                      },
                      child: const Text('해제', style: TextStyle(color: AppTheme.primaryColor)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  void _showAccountDeletionDialog() {
    // 기존 코드 유지 (내용 생략)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text(
          '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.\n\n'
              '삭제되는 데이터:\n'
              '- 프로필 정보\n'
              '- 매칭 기록\n'
              '- 메세지 기록\n'
              '- 기타 모든 활동 기록\n\n'
              '이 작업은 되돌릴 수 없습니다. 정말로 계정을 삭제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion() {
    // 기존 코드 유지 (내용 생략)
    showDialog(
      context: context,
      builder: (context) => Consumer<AuthController>(
        builder: (context, authController, child) {
          return AlertDialog(
            title: const Text('최종 확인'),
            content: authController.isLoading
                ? const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('계정을 삭제하고 있습니다...')])
                : const Text('정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
            actions: authController.isLoading
                ? []
                : [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: authController.isLoading ? null : () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정 삭제 중... 잠시만 기다려주세요.'), duration: Duration(seconds: 30), backgroundColor: Colors.orange));
                    final success = await authController.deleteAccount();
                    if (mounted) {
                      ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      Navigator.pop(context);
                      if (success) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정이 성공적으로 삭제되었습니다.'), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authController.errorMessage ?? '계정 삭제에 실패했습니다.'), backgroundColor: Colors.red));
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정 삭제 처리 중 오류가 발생했습니다.'), backgroundColor: Colors.red));
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
      const SnackBar(content: Text('앱스토어로 이동하여 평가해 주세요!')),
    );
  }
}
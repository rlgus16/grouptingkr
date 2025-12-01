import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';

// 설정 페이지
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // 설정 상태 변수들
  bool _pushNotifications = true;
  bool _matchingNotifications = true;
  bool _messageNotifications = true;
  bool _showProfileToOthers = true;
  bool _allowLocationAccess = true;

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
                  title: '푸시 알림',
                  subtitle: '앱의 모든 알림을 받습니다',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: '매칭 알림',
                  subtitle: '새로운 매칭 알림을 받습니다',
                  value: _matchingNotifications,
                  onChanged: (value) {
                    setState(() {
                      _matchingNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: '메시지 알림',
                  subtitle: '새로운 메시지 알림을 받습니다',
                  value: _messageNotifications,
                  onChanged: (value) {
                    setState(() {
                      _messageNotifications = value;
                    });
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
                _buildSwitchTile(
                  title: '위치 정보 접근',
                  subtitle: '활동지역 기반 매칭을 위해 위치 정보를 사용합니다',
                  value: _allowLocationAccess,
                  onChanged: (value) {
                    setState(() {
                      _allowLocationAccess = value;
                    });
                  },
                ),
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
                  icon: Icons.bug_report_outlined,
                  title: '버그 신고',
                  onTap: () {
                    _showBugReportDialog();
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
      activeColor: AppTheme.primaryColor,
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

  // 개인정보 처리방침 -> 여기에 스토어 등록에 맞춰 방침 구성하시고, 업로드 진행해 주시거나 url을 통해 연동해주시면 됩니다!
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보 처리방침'),
        content: const SingleChildScrollView(
          child: Text(
            '그룹팅 앱은 사용자의 개인정보를 보호하기 위해 다음과 같은 방침을 운영하고 있습니다.\n\n'
            '1. 수집하는 개인정보\n'
            '- 필수정보: 이메일, 닉네임, 전화번호, 생년월일, 성별\n'
            '- 선택정보: 프로필 사진, 자기소개, 활동지역\n\n'
            '2. 개인정보 이용목적\n'
            '- 서비스 제공 및 운영\n'
            '- 매칭 서비스 제공\n'
            '- 고객 지원\n\n'
            '3. 개인정보 보유기간\n'
            '- 회원 탈퇴 시까지\n\n'
            '자세한 내용은 앱 내 개인정보 처리방침을 참조해 주세요.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 서비스 이용약관
  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서비스 이용약관'),
        content: const SingleChildScrollView(
          child: Text(
            '그룹팅 서비스 이용약관\n\n'
            '제1조 (목적)\n'
            '이 약관은 그룹팅 서비스 이용과 관련하여 회사와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
            '제2조 (서비스의 제공)\n'
            '회사는 그룹 매칭 서비스를 제공합니다.\n\n'
            '제3조 (이용자의 의무)\n'
            '- 타인에게 피해를 주는 행위 금지\n'
            '- 허위 정보 등록 금지\n'
            '- 서비스의 안정적 운영에 지장을 주는 행위 금지\n\n'
            '자세한 내용은 앱 내 이용약관을 참조해 주세요.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 비밀번호 변경
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final authController = context.read<AuthController>();

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

                        // 입력 검증
                        if (currentPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('현재 비밀번호를 입력해주세요.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (newPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('새 비밀번호를 입력해주세요.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (newPassword.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('새 비밀번호는 최소 6자 이상이어야 합니다.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (newPassword != confirmPassword) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('새 비밀번호와 확인 비밀번호가 일치하지 않습니다.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // 비밀번호 변경 실행
                        final success = await authController.changePassword(
                          currentPassword,
                          newPassword,
                        );

                        if (mounted) {
                          Navigator.pop(context); // 다이얼로그 닫기

                          if (success) {
                            // 비밀번호 변경 성공
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('비밀번호가 성공적으로 변경되었습니다.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            // 비밀번호 변경 실패
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  authController.errorMessage ?? '비밀번호 변경에 실패했습니다.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                      child: const Text('변경'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  // 데이터 다운로드
  void _showDataDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 데이터 다운로드'),
        content: const Text(
          '내가 그룹팅에서 생성한 모든 데이터를 다운로드할 수 있습니다.\n\n'
          '포함되는 데이터:\n'
          '- 프로필 정보\n'
          '- 매칭 기록\n'
          '- 메시지 기록\n\n'
          '다운로드를 요청하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('데이터 다운로드 요청이 접수되었습니다. 이메일로 전송됩니다.'),
                ),
              );
            },
            child: const Text('다운로드 요청'),
          ),
        ],
      ),
    );
  }

  // 계정 삭제
  void _showAccountDeletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text(
          '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.\n\n'
          '삭제되는 데이터:\n'
          '- 프로필 정보\n'
          '- 매칭 기록\n'
          '- 메시지 기록\n'
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
    final authController = context.read<AuthController>();
    
    showDialog(
      context: context,
      builder: (context) => Consumer<AuthController>(
        builder: (context, authController, child) {
          return AlertDialog(
            title: const Text('최종 확인'),
            content: authController.isLoading
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('계정을 삭제하고 있습니다...'),
                    ],
                  )
                : const Text('정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
            actions: authController.isLoading
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: authController.isLoading ? null : () async {
                        // 계정 삭제 실행
                        try {
                          // 진행 상태 표시를 위한 스낵바
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('계정 삭제 중... 잠시만 기다려주세요.'),
                                ],
                              ),
                              duration: Duration(seconds: 30), // 충분한 시간 제공
                              backgroundColor: Colors.orange,
                            ),
                          );
                          
                          final success = await authController.deleteAccount();
                          
                          if (mounted) {
                            // 진행 상태 스낵바 제거
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            Navigator.pop(context); // 다이얼로그 닫기
                            
                            if (success) {
                              // 계정 삭제 성공
                              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('계정이 성공적으로 삭제되었습니다.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              // 계정 삭제 실패
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(authController.errorMessage ?? '계정 삭제에 실패했습니다.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint('계정 삭제 UI 처리 중 오류: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('계정 삭제 처리 중 오류가 발생했습니다.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                      ),
                      child: const Text('최종 삭제'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  // 업데이트 확인
  void _checkForUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 최신 버전을 사용 중입니다.')),
    );
  }

  // 버그 신고
  void _showBugReportDialog() {
    final bugReportController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('버그 신고'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('발견한 버그나 문제점을 알려주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: bugReportController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '버그 내용을 자세히 설명해 주세요...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('버그 신고가 접수되었습니다.')),
              );
            },
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
  }

  // 앱 평가
  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('앱스토어로 이동하여 평가해 주세요!')),
    );
  }
} 
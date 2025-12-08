import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
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
  bool _messageNotifications = true;

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
                    setState(() {
                      _matchingNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: '초대 알림',
                  subtitle: '새로운 초대 알림을 받습니다',
                  value: _matchingNotifications,
                  onChanged: (value) {
                    setState(() {
                      _matchingNotifications = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: '메세지 알림',
                  subtitle: '새로운 메세지 알림을 받습니다',
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
                // [추가됨] 차단 관리 탭
                _buildMenuTile(
                  icon: Icons.person_off_outlined, // 차단 관련 아이콘
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

// 개인정보 처리방침 - 웹페이지 연결
  Future<void> _showPrivacyPolicy() async {
    const url = 'https://flossy-sword-5a1.notion.site/2bee454bf6f580ad8c6df10d571c93a9';

    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('페이지를 열 수 없습니다.')),
        );
      }
    }
  }
// 서비스 이용약관 - 웹페이지 연결
  Future<void> _showTermsOfService() async {
    const url = 'https://www.notion.so/2c0e454bf6f5805f8d5efdc00ba53bdb';

    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('페이지를 열 수 없습니다.')),
        );
      }
    }
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

  // 차단 관리 다이얼로그
  void _showBlockedUsersDialog() {
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단 관리'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300, // 리스트가 길어질 수 있으므로 높이 제한
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('blocks')
                .where('blockerId', isEqualTo: currentUser.uid) // 내가 차단한 내역만 조회
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('목록을 불러오는데 실패했습니다.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    '차단한 사용자가 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final blockedName = data['blockedNickname'] ?? '알 수 없는 사용자';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.gray100,
                      child: Icon(Icons.person_off, color: Colors.grey, size: 20),
                    ),
                    title: Text(blockedName),
                    trailing: TextButton(
                      onPressed: () async {
                        // 차단 해제 로직 (DB 문서 삭제)
                        await FirebaseFirestore.instance
                            .collection('blocks')
                            .doc(docs[index].id)
                            .delete();
                      },
                      child: const Text(
                        '해제',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
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
            child: const Text('닫기'),
          ),
        ],
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
    final ImagePicker picker = ImagePicker();
    XFile? attachedImage; // 첨부된 이미지 상태 관리

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // 다이얼로그 내부 상태(이미지 첨부 여부)를 갱신하기 위해 StatefulBuilder 사용
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('버그 신고'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 16),
                  // 사진 첨부 버튼 및 미리보기
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              setState(() {
                                attachedImage = image;
                              });
                            }
                          } catch (e) {
                            debugPrint('이미지 선택 오류: $e');
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('사진 첨부'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 첨부된 파일명 표시
                      if (attachedImage != null)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  attachedImage!.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    attachedImage = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (bugReportController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('내용을 입력해주세요.')),
                    );
                    return;
                  }

                  Navigator.pop(context); // 다이얼로그 닫기

                  // 이메일 발송 함수 호출
                  await _sendBugReportEmail(
                    bugReportController.text,
                    attachedImage?.path,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('보내기'),
              ),
            ],
          );
        },
      ),
    );
  }

  // [추가됨] 이메일 발송 로직
  Future<void> _sendBugReportEmail(String body, String? attachmentPath) async {
    // 개발자 이메일 주소 입력
    const String developerEmail = 'sprt.groupting@gmail.com';

    final Email email = Email(
      body: '내용:\n$body\n\n----------------\n앱 버전: 1.0.0\n기기: ${Theme.of(context).platform}',
      subject: '[그룹팅 버그 신고]',
      recipients: [developerEmail],
      attachmentPaths: attachmentPath != null ? [attachmentPath] : null,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이메일 앱을 열 수 없습니다. ($error)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 앱 평가
  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('앱스토어로 이동하여 평가해 주세요!')),
    );
  }
} 
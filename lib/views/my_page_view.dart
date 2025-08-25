import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../utils/app_theme.dart';
import 'profile_edit_view.dart';
import 'settings_view.dart';
import 'help_view.dart';

class MyPageView extends StatefulWidget {
  const MyPageView({super.key});

  @override
  State<MyPageView> createState() => _MyPageViewState();
}

class _MyPageViewState extends State<MyPageView> {
  @override
  void initState() {
    super.initState();
    // 페이지 로드 후 즉시 로그인 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthenticationStatus();
    });
  }

  void _checkAuthenticationStatus() {
    final authController = context.read<AuthController>();
    
    // 로그인되지 않은 상태면 즉시 로그인 페이지로 이동
    if (!authController.isLoggedIn) {
      debugPrint('마이페이지 - 로그인되지 않은 상태 감지, 로그인 페이지로 이동');
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Consumer2<AuthController, ProfileController>(
        builder: (context, authController, profileController, _) {
          // 로그인 상태 변경 감지 및 즉시 처리
          if (!authController.isLoggedIn) {
            debugPrint('마이페이지 - Consumer에서 로그아웃 상태 감지');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            });
            // 로그인 페이지로 이동하는 동안 로딩 표시
            return const Center(child: CircularProgressIndicator());
          }

          final user = authController.currentUserModel;

          // 사용자 문서가 없는 경우 (완전히 프로필이 없음)
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 80,
                      color: AppTheme.gray400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '프로필이 없습니다',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '프로필을 만들어 그룹에 참여해보세요!',
                      style: TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile-create');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('프로필 만들기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 로그아웃 버튼 추가
                    OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context, authController),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('로그아웃'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // 사용자 문서는 있지만 프로필이 미완성인 경우
          if (!user.isProfileComplete) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 80,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '프로필을 완성해주세요',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '기본 정보는 등록되었지만\n닉네임, 키, 소개 등을 추가로 입력해주세요.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // 기본 정보 요약 표시
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '등록된 기본 정보',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBasicInfoRow('전화번호', user.phoneNumber),
                          _buildBasicInfoRow('성별', user.gender == '남' ? '남성' : '여성'),
                          if (user.birthDate.isNotEmpty)
                            _buildBasicInfoRow('나이', '${user.age}세'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile-create');
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('프로필 완성하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 로그아웃 버튼
                    OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context, authController),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('로그아웃'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 프로필 섹션
                Container(
                  padding: const EdgeInsets.all(24),
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
                    children: [
                      // 프로필 이미지
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.gray200,
                        ),
                        child: ClipOval(
                          child: user.mainProfileImage != null
                              ? _buildProfileImage(user.mainProfileImage!, 100)
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppTheme.textSecondary,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 닉네임
                      Text(
                        user.nickname,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // 나이
                      Text(
                        '${user.age}세',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 프로필 편집 버튼
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileEditView(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('프로필 편집'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 내 정보 섹션
                Container(
                  padding: const EdgeInsets.all(20),
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
                      Text(
                        '내 정보',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 16),

                      _buildInfoRow('전화번호', user.phoneNumber),
                      _buildInfoRow('성별', user.gender == '남' ? '남성' : '여성'),
                      _buildInfoRow('키', '${user.height}cm'),
                      _buildInfoRow('활동지역', user.activityArea),

                      if (user.introduction.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '소개',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.introduction,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 설정 섹션
                Container(
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
                    children: [
                      _buildMenuTile(
                        icon: Icons.settings_outlined,
                        title: '설정',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsView(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        icon: Icons.help_outline,
                        title: '도움말',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpView(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        icon: Icons.info_outline,
                        title: '앱 정보',
                        onTap: () {
                          _showAppInfo(context);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 로그아웃 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(context, authController),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('로그아웃'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary, size: 24),
      title: Text(
        title,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthController authController) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await authController.signOut();
                  // AuthWrapper가 자동으로 LoginView로 전환하므로 수동 네비게이션 제거
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('앱 정보'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('그룹팅 앱'),
              SizedBox(height: 8),
              Text('버전: 1.0.0'),
              SizedBox(height: 8),
              Text('친구들과 함께하는 소개팅 플랫폼'),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage(String imageUrl, double size) {
    // 로컬 이미지인지 확인 (local:// 또는 temp://)
    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      if (kIsWeb) {
        // 웹에서는 로컬 이미지 표시 불가
        return Icon(
          Icons.person,
          size: size * 0.5,
          color: AppTheme.textSecondary,
        );
      } else {
        // 모바일에서만 로컬 파일 접근
        String localPath;
        if (imageUrl.startsWith('local://')) {
          localPath = imageUrl.substring(8); // 'local://' 제거
        } else {
          localPath = imageUrl.substring(7); // 'temp://' 제거
        }
        
        return Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person,
            size: size * 0.5,
            color: AppTheme.textSecondary,
          ),
        );
      }
    } else {
      // 네트워크 이미지
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
            Icon(Icons.person, size: size * 0.5, color: AppTheme.textSecondary),
      );
    }
  }
}

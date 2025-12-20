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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthenticationStatus();
    });
  }

  void _checkAuthenticationStatus() {
    final authController = context.read<AuthController>();
    if (!authController.isLoggedIn) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50, // 전체 배경을 아주 연한 회색으로 변경
      appBar: AppBar(
        title: const Text('마이페이지'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.gray50, // 앱바도 배경색과 통일
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Consumer2<AuthController, ProfileController>(
        builder: (context, authController, profileController, _) {
          if (!authController.isLoggedIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          final user = authController.currentUserModel;

          if (user == null) {
            return _buildEmptyState(context, authController);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              children: [
                // 1. 프로필 헤더 섹션 (중앙 정렬 디자인)
                _buildProfileHeader(context, user),

                const SizedBox(height: 24),

                // 2. 내 정보 카드
                _buildInfoCard(context, user),

                const SizedBox(height: 20),

                // 3. 메뉴 카드
                _buildMenuCard(context),

                const SizedBox(height: 30),

                // 4. 로그아웃 버튼 (텍스트 형태)
                TextButton(
                  onPressed: () => _showLogoutDialog(context, authController),
                  child: Text(
                    '로그아웃',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 프로필 없음 상태
  Widget _buildEmptyState(BuildContext context, AuthController authController) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, size: 60, color: AppTheme.gray400),
          ),
          const SizedBox(height: 24),
          Text(
            '프로필을 만들어주세요',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            '새로운 인연을 만날 준비가 되셨나요?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditView()));
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('프로필 만들기'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _showLogoutDialog(context, authController),
            child: const Text('로그아웃', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  // 1. 프로필 헤더 위젯
  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            // 프로필 이미지
            Container(
              width: 110,
              height: 110,
              padding: const EdgeInsets.all(3), // 테두리 두께
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1),
                color: Colors.white,
              ),
              child: ClipOval(
                child: user.mainProfileImage != null
                    ? _buildProfileImage(user.mainProfileImage!, 110)
                    : Container(
                  color: AppTheme.gray100,
                  child: const Icon(Icons.person, size: 50, color: AppTheme.gray400),
                ),
              ),
            ),
            // 편집 버튼 (Floating Style)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileEditView()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.nickname,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            fontFamily: 'Pretendard',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTag('${user.age}세'),
            const SizedBox(width: 6),
            _buildTag(user.gender == '남' ? '남성' : '여성'),
          ],
        ),
      ],
    );
  }

  // 작은 태그 위젯
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gray300),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 2. 내 정보 카드 위젯
  Widget _buildInfoCard(BuildContext context, dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "기본 정보",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow(Icons.phone_iphone, '전화번호', user.phoneNumber),
          _buildDetailRow(Icons.height, '키', '${user.height}cm'),
          _buildDetailRow(Icons.location_on_outlined, '위치', '${user.activityArea}'),
          if (user.introduction.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: AppTheme.gray100, thickness: 1),
            ),
            const Text(
              "자기소개",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.introduction,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // 3. 메뉴 카드 위젯
  Widget _buildMenuCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: '설정',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsView())),
          ),
          _buildMenuItem(
            icon: Icons.help_outline_rounded,
            title: '도움말',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpView())),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: AppTheme.gray100),
          ),
          _buildMenuItem(
            icon: Icons.info_outline_rounded,
            title: '앱 정보',
            onTap: () => _showAppInfo(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(20))
          : const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.gray500, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: AppTheme.gray400, size: 20),
          ],
        ),
      ),
    );
  }

  // ... (나머지 헬퍼 메서드들은 기존과 동일하거나 약간 수정)

  void _showLogoutDialog(BuildContext context, AuthController authController) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: const Text('정말 로그아웃 하시겠습니까?', style: TextStyle(color: AppTheme.textSecondary)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소', style: TextStyle(color: AppTheme.gray600)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await authController.signOut();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('로그아웃 중 오류: $e')),
                    );
                  }
                }
              },
              child: const Text('로그아웃', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: AppTheme.primaryColor, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Groupting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Version 1.0.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              const Text('친구들과 함께하는 소개팅 플랫폼', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage(String imageUrl, double size) {
    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      if (kIsWeb) {
        return Icon(Icons.person, size: size * 0.5, color: AppTheme.textSecondary);
      } else {
        String localPath = imageUrl.startsWith('local://')
            ? imageUrl.substring(8)
            : imageUrl.substring(7);
        return Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person, size: size * 0.5, color: AppTheme.textSecondary),
        );
      }
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.5, color: AppTheme.textSecondary),
      );
    }
  }
}
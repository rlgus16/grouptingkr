import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class ProfileDetailView extends StatelessWidget {
  final UserModel user;

  const ProfileDetailView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${user.nickname}님의 프로필'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프로필 이미지 갤러리
            SizedBox(
              height: 400,
              child: user.profileImages.isNotEmpty
                  ? PageView.builder(
                      itemCount: user.profileImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.gray100,
                          ),
                          child: _buildProfileImage(user.profileImages[index]),
                        );
                      },
                    )
                  : Container(
                      color: AppTheme.gray100,
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 100,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
            ),

            // 프로필 이미지 개수 표시
            if (user.profileImages.length > 1) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.gray50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '사진 ${user.profileImages.length}장',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '← 스와이프하여 사진 보기',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 프로필 정보
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 닉네임과 나이
                  Row(
                    children: [
                      Text(
                        user.nickname,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${user.age}세',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 기본 정보
                  _buildInfoSection(context, '기본 정보', [
                    _InfoItem('성별', user.gender),
                    _InfoItem('키', '${user.height}cm'),
                    _InfoItem('활동지역', user.activityArea),
                  ]),

                  const SizedBox(height: 24),

                  // 소개
                  if (user.introduction.isNotEmpty) ...[
                    _buildInfoSection(context, '소개', [
                      _InfoItem('', user.introduction, isDescription: true),
                    ]),
                    const SizedBox(height: 24,),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<_InfoItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
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
            children: items.map((item) => _buildInfoRow(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(_InfoItem item) {
    if (item.isDescription) {
      return Text(
        item.value,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          height: 1.5,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              item.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String imageUrl) {
    // 로컬 이미지인지 확인 (local:// 또는 temp://)
    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      if (kIsWeb) {
        // 웹에서는 로컬 이미지 표시 불가
        return const Center(
          child: Icon(Icons.person, size: 100, color: AppTheme.textSecondary),
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
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.person, size: 100, color: AppTheme.textSecondary),
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
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.person, size: 100, color: AppTheme.textSecondary),
        ),
      );
    }
  }
}

class _InfoItem {
  final String label;
  final String value;
  final bool isDescription;

  _InfoItem(this.label, this.value, {this.isDescription = false});
}

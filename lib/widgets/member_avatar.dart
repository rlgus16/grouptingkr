import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class MemberAvatar extends StatelessWidget {
  // 기존 방식 (UserModel 사용)
  final UserModel? user;

  // 새로운 방식 (개별 필드 사용)
  final String? imageUrl;
  final String? name;
  final bool? isOwner;
  final bool? isMatched;

  final double size;
  final VoidCallback? onTap;

  const MemberAvatar({
    super.key,
    this.user,
    this.imageUrl,
    this.name,
    this.isOwner,
    this.isMatched,
    this.size = 50,
    this.onTap,
  });

  // UserModel을 사용하는 생성자
  const MemberAvatar.fromUser({
    super.key,
    required UserModel user,
    this.size = 50,
    this.onTap,
  }) : user = user,
       imageUrl = null,
       name = null,
       isOwner = null,
       isMatched = null;

  @override
  Widget build(BuildContext context) {
    final profileImage = user?.mainProfileImage ?? imageUrl;
    final showOwnerBadge = isOwner ?? false;
    final showMatchedBadge = isMatched ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gray200,
              border: showMatchedBadge
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
            ),
            child: ClipOval(
              child: profileImage != null
                  ? _buildProfileImage(profileImage, size)
                  : Icon(
                      Icons.person,
                      size: size * 0.6,
                      color: AppTheme.textSecondary,
                    ),
            ),
          ),

          // 방장 뱃지
          if (showOwnerBadge)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star, size: size * 0.2, color: Colors.white),
              ),
            ),

          // 매칭된 그룹 표시
          if (showMatchedBadge)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  size: size * 0.15,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String imageUrl, double size) {
    // 로컬 이미지인지 확인 (local:// 또는 temp://)
    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      if (kIsWeb) {
        // 웹에서는 로컬 이미지 표시 불가 - 기본 아이콘 표시
        return Icon(
          Icons.person,
          size: size * 0.6,
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
            size: size * 0.6,
            color: AppTheme.textSecondary,
          ),
        );
      }
    } else {
      // 네트워크 이미지 (http, https URL)
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) =>
            Icon(Icons.person, size: size * 0.6, color: AppTheme.textSecondary),
      );
    }
  }
}

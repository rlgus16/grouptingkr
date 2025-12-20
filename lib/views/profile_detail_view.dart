import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../controllers/auth_controller.dart';

class ProfileDetailView extends StatefulWidget {
  final UserModel user;

  const ProfileDetailView({super.key, required this.user});

  @override
  State<ProfileDetailView> createState() => _ProfileDetailViewState();
}

class _ProfileDetailViewState extends State<ProfileDetailView> {
  int _currentImageIndex = 0;
  final ScrollController _scrollController = ScrollController();

  // 신고하기 기능
  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final reasons = ['부적절한 사진', '욕설/비하 발언', '스팸/홍보', '사칭/사기', '기타'];
    String selectedReason = reasons[0];
    final ImagePicker picker = ImagePicker();
    XFile? attachedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('사용자 신고'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('신고 사유를 선택해주세요.', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedReason = value);
                    }
                  },
                  child: Column(
                    children: reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      // RadioGroup 내부에서는 onChanged와 groupValue를 지정하지 않습니다.
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppTheme.errorColor,
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: '신고 내용을 자세히 적어주세요.',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) setState(() => attachedImage = image);
                    } catch (e) {
                      debugPrint('이미지 선택 오류: $e');
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(attachedImage == null ? '증거 사진 첨부' : '사진 변경'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.gray300),
                  ),
                ),
                if (attachedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.successColor, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            attachedImage!.name,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('신고 내용을 입력해주세요.')),
                  );
                  return;
                }
                try {
                  final currentUser = context.read<AuthController>().currentUserModel;
                  if (currentUser == null) return;
                  Navigator.pop(context);

                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': currentUser.uid,
                    'reportedUserId': widget.user.uid,
                    'category': selectedReason,
                    'description': reasonController.text.trim(),
                    'hasImage': attachedImage != null,
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  await _sendReportEmail(
                    reporter: currentUser,
                    targetUser: widget.user,
                    category: selectedReason,
                    description: reasonController.text.trim(),
                    imagePath: attachedImage?.path,
                  );
                } catch (e) {
                  debugPrint('신고 실패: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('신고하기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReportEmail({
    required UserModel reporter,
    required UserModel targetUser,
    required String category,
    required String description,
    String? imagePath,
  }) async {
    const String developerEmail = 'sprt.groupting@gmail.com';
    final String body = '''
[사용자 신고 접수]
- 신고자: ${reporter.nickname} (${reporter.uid})
- 대상자: ${targetUser.nickname} (${targetUser.uid})
- 사유: $category
- 내용: $description
--------------------------------
App Version: 1.0.0
Platform: ${Theme.of(context).platform}
''';

    final Email email = Email(
      body: body,
      subject: '[그룹팅 신고] ${targetUser.nickname} 사용자 신고',
      recipients: [developerEmail],
      attachmentPaths: imagePath != null ? [imagePath] : null,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일 앱을 실행할 수 없습니다.')),
        );
      }
    }
  }

  // 차단하기 기능
  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 차단'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('차단하면 서로의 프로필을 볼 수 없으며,\n채팅 및 초대를 받을 수 없습니다.\n정말 차단하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = context.read<AuthController>().currentUserModel;
                if (currentUser == null) return;
                final blockDocId = '${currentUser.uid}_${widget.user.uid}';

                await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).set({
                  'blockerId': currentUser.uid,
                  'blockerNickname': currentUser.nickname,
                  'blockedId': widget.user.uid,
                  'blockedNickname': widget.user.nickname,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('사용자를 차단했습니다.')),
                  );
                }
              } catch (e) {
                debugPrint('차단 실패: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('차단하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isBlocked = authController.blockedUserIds.contains(widget.user.uid);
    final isMe = authController.currentUserModel?.uid == widget.user.uid;
    final themeColor = widget.user.gender == '여' ? AppTheme.secondaryColor : AppTheme.primaryColor;

    if (isBlocked) {
      return Scaffold(
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 60, color: AppTheme.gray400),
              SizedBox(height: 16),
              Text('차단된 사용자입니다.', style: TextStyle(color: AppTheme.gray600, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. SliverAppBar로 유동적인 이미지 헤더 구현
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.55, // 화면의 55% 차지
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCircleButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: isMe ? [] : [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildCircleButton(
                  icon: Icons.more_vert,
                  onTap: () {
                    // 메뉴 표시
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                              title: const Text('신고하기'),
                              onTap: () {
                                Navigator.pop(context);
                                _showReportDialog(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.block, color: Colors.red),
                              title: const Text('차단하기'),
                              onTap: () {
                                Navigator.pop(context);
                                _showBlockDialog(context);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 이미지 슬라이더
                  PageView.builder(
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemCount: widget.user.profileImages.length,
                    itemBuilder: (context, index) {
                      return _buildProfileImage(widget.user.profileImages[index]);
                    },
                  ),
                  // 하단 그라디언트 (텍스트 가독성 및 디자인 용도)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha:0.4)],
                        ),
                      ),
                    ),
                  ),
                  // 페이지 인디케이터
                  if (widget.user.profileImages.length > 1)
                    Positioned(
                      bottom: 30, // 컨텐츠 오버랩을 고려해 위치 조정
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.user.profileImages.length,
                              (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index ? Colors.white : Colors.white.withValues(alpha:0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. 바텀 시트 느낌의 정보 컨테이너
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20), // 위로 살짝 겹치게
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 및 나이 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.user.nickname,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Pretender',
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: themeColor.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${widget.user.age}세',
                                      style: TextStyle(
                                        color: themeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: AppTheme.gray200),
                    const SizedBox(height: 32),

                    // 기본 정보 (칩 스타일)
                    const Text('기본 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInfoChip(Icons.height_rounded, '${widget.user.height}cm'),
                        _buildInfoChip(Icons.location_on_outlined, widget.user.activityArea),
                        // 추가 정보가 있다면 여기에 더 추가 가능
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 소개글
                    if (widget.user.introduction.isNotEmpty) ...[
                      const Text('소개', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.gray50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.user.introduction,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100), // 하단 여백
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 상단바 원형 버튼 위젯
  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }

  // 정보 칩 위젯
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 프로필 이미지 위젯 (Cover 모드 적용)
  Widget _buildProfileImage(String imageUrl) {
    // 배경은 블러 처리된 이미지, 전경은 Fit.contain 또는 cover
    // 여기서는 깔끔하게 Cover로 꽉 채우는 방식을 사용 (요즘 트렌드)

    ImageProvider? imageProvider;

    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      final path = imageUrl.startsWith('local://') ? imageUrl.substring(8) : imageUrl.substring(7);
      imageProvider = FileImage(File(path));
    } else {
      imageProvider = CachedNetworkImageProvider(imageUrl);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray200,
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover, // 꽉 차게 보여줌
        ),
      ),
    );
  }
}
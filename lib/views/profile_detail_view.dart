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
  // 현재 보고 있는 이미지 인덱스 상태 관리
  int _currentImageIndex = 0;

  // 신고하기 기능 (메시지 필수, 사진 첨부, 이메일 전송)
  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final reasons = ['부적절한 사진', '욕설/비하 발언', '스팸/홍보', '사칭/사기', '기타'];
    String selectedReason = reasons[0];

    // 사진 첨부를 위한 변수
    final ImagePicker picker = ImagePicker();
    XFile? attachedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('사용자 신고'),
          content: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: selectedReason, // 그룹 전체의 값을 여기서 관리합니다.
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedReason = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('신고 사유를 선택해주세요.'),
                  const SizedBox(height: 16),

                  // [2] 개별 버튼에서는 groupValue와 onChanged를 제거합니다.
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppTheme.errorColor,
                  )),

                  const SizedBox(height: 8),
                  // [3] 나머지 입력창과 버튼들은 그대로 유지됩니다.
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      hintText: '구체적인 신고 내용을 입력해주세요 (필수)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // 사진 첨부 버튼 영역 (기존 코드와 동일)
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
                        label: const Text('증거 사진 첨부'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (attachedImage != null)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  attachedImage!.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
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
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                // 유효성 검사
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('구체적인 신고 내용을 입력해주세요.')),
                  );
                  return;
                }

                try {
                  final currentUser = context.read<AuthController>().currentUserModel;
                  if (currentUser == null) return;

                  Navigator.pop(context); // 다이얼로그 닫기

                  // 1. Firestore에 기록 (백업용)
                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': currentUser.uid,
                    'reportedUserId': widget.user.uid,
                    'reportedUserNickname': widget.user.nickname,
                    'category': selectedReason,
                    'description': reasonController.text.trim(),
                    'hasImage': attachedImage != null,
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  // 2. 이메일 발송 실행
                  await _sendReportEmail(
                    reporter: currentUser,
                    targetUser: widget.user,
                    category: selectedReason,
                    description: reasonController.text.trim(),
                    imagePath: attachedImage?.path,
                  );

                } catch (e) {
                  debugPrint('신고 실패: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('신고 처리에 실패했습니다.')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              child: const Text('신고하기'),
            ),
          ],
        ),
      ),
    );
  }

  // 신고 이메일 발송 함수
  Future<void> _sendReportEmail({
    required UserModel reporter,
    required UserModel targetUser,
    required String category,
    required String description,
    String? imagePath,
  }) async {
    // 개발자 이메일 주소
    const String developerEmail = 'sprt.groupting@gmail.com';

    final String body = '''
[사용자 신고 접수]

1. 신고자 정보
- 닉네임: ${reporter.nickname}
- UID: ${reporter.uid}

2. 신고 대상 정보
- 닉네임: ${targetUser.nickname}
- UID: ${targetUser.uid}

3. 신고 내용
- 카테고리: $category
- 상세 내용: $description

--------------------------------
앱 버전: 1.0.0
기기: ${Theme.of(context).platform}
''';

    final Email email = Email(
      body: body,
      subject: '[그룹팅 신고]',
      recipients: [developerEmail],
      attachmentPaths: imagePath != null ? [imagePath] : null,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고 메일 작성 화면으로 이동합니다.')),
        );
      }
    } catch (error) {
      debugPrint('이메일 전송 오류: $error');
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
        content: Text(
          '서로의 프로필 차단\n서로의 채팅 메세지 차단\n서로의 초대 메세지 차단\n\n'
              '${widget.user.nickname}님을 차단하시겠습니까?\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = context.read<AuthController>().currentUserModel;
                if (currentUser == null) return;

                // 'blocks' 컬렉션에 저장 (양방향 차단 지원)
                final blockDocId = '${currentUser.uid}_${widget.user.uid}';

                await FirebaseFirestore.instance
                    .collection('blocks')
                    .doc(blockDocId)
                    .set({
                  'blockerId': currentUser.uid,      // 차단한 사람 (나)
                  'blockerNickname': currentUser.nickname,
                  'blockedId': widget.user.uid,      // 차단당한 사람 (상대)
                  'blockedNickname': widget.user.nickname,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context); // 다이얼로그 닫기
                  Navigator.pop(context); // 프로필 화면 닫기
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('사용자를 차단했습니다.')),
                  );
                }
              } catch (e) {
                debugPrint('차단 실패: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('차단 처리에 실패했습니다.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('차단하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 차단 여부 실시간 확인 (watch 사용)
    final authController = context.watch<AuthController>();
    final isBlocked = authController.blockedUserIds.contains(widget.user.uid);

    // 차단된 사용자일 경우 프로필 내용을 숨김
    if (isBlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('프로필'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 48, color: AppTheme.textSecondary),
              SizedBox(height: 16),
              Text(
                '정보를 확인할 수 없는 사용자입니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 현재 로그인한 유저인지 확인 (본인 프로필에는 차단/신고 버튼 숨김)
    final isMe = authController.currentUserModel?.uid == widget.user.uid;

    // 성별에 따른 색상 결정 (나이 태그 및 인디케이터에 사용)
    final themeColor = widget.user.gender == '여'
        ? AppTheme.secondaryColor
        : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.nickname}님의 프로필'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: isMe ? [] : [
          PopupMenuButton<String>(
            iconSize: 30,
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog(context);
              } else if (value == 'block') {
                _showBlockDialog(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report_problem_outlined, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('신고하기'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('차단하기'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프로필 이미지 갤러리
            SizedBox(
              height: 400,
              child: widget.user.profileImages.isNotEmpty
                  ? PageView.builder(
                // 페이지 변경 시 인덱스 업데이트
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemCount: widget.user.profileImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.gray100,
                    ),
                    child: _buildProfileImage(widget.user.profileImages[index]),
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

            // 이미지 페이지 인디케이터 (점)
            if (widget.user.profileImages.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.user.profileImages.length,
                        (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // 현재 페이지면 테마 색상, 아니면 회색
                        color: _currentImageIndex == index
                            ? themeColor
                            : AppTheme.gray300,
                      ),
                    ),
                  ),
                ),
              ),

            // 기존 프로필 이미지 개수 표시 (점 인디케이터 아래에 유지)
            if (widget.user.profileImages.length > 1) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0), // 상단 여백 조정
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
                        widget.user.nickname,
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
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.user.age}세',
                          style: TextStyle(
                            color: themeColor,
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
                    _InfoItem('성별', widget.user.gender),
                    _InfoItem('키', '${widget.user.height}cm'),
                    _InfoItem('활동지역', widget.user.activityArea),
                  ]),

                  const SizedBox(height: 24),

                  // 소개
                  if (widget.user.introduction.isNotEmpty) ...[
                    _buildInfoSection(context, '소개', [
                      _InfoItem('', widget.user.introduction, isDescription: true),
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
    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      if (kIsWeb) {
        return const Center(
          child: Icon(Icons.person, size: 100, color: AppTheme.textSecondary),
        );
      } else {
        String localPath;
        if (imageUrl.startsWith('local://')) {
          localPath = imageUrl.substring(8);
        } else {
          localPath = imageUrl.substring(7);
        }

        return Image.file(
          File(localPath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.person, size: 100, color: AppTheme.textSecondary),
          ),
        );
      }
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
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
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../utils/app_theme.dart';

class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _introductionController = TextEditingController();
  final _heightController = TextEditingController();
  final _activityAreaController = TextEditingController();
  
  // 이미지 관리 관련
  List<dynamic> _imageSlots = List.filled(6, null); // 통합 이미지 슬롯
  List<String> _imagesToDelete = []; // 삭제할 이미지 URL 저장
  final ImagePicker _picker = ImagePicker();
  bool _isPickerActive = false;
  int _mainProfileIndex = 0; // 메인 프로필 이미지 인덱스 (기본값: 0번)
  
  // 닉네임 중복 검증 관련
  bool _isCheckingNickname = false;
  String? _nicknameValidationMessage;
  String _originalNickname = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;

    if (user != null) {
      _nicknameController.text = user.nickname;
      _originalNickname = user.nickname; // 기존 닉네임 저장
      _introductionController.text = user.introduction;
      _heightController.text = user.height.toString();
      _activityAreaController.text = user.activityArea;
      
      // 기존 이미지들 로드 (유효한 URL만 필터링)
      List<String> _originalImages = user.profileImages.where((imageUrl) {
        return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
      }).toList();
      
      // 통합 이미지 슬롯에 기존 이미지 할당
      for (int i = 0; i < _imageSlots.length; i++) {
        if (i < _originalImages.length) {
          _imageSlots[i] = _originalImages[i];
        } else {
          _imageSlots[i] = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introductionController.dispose();
    _heightController.dispose();
    _activityAreaController.dispose();
    super.dispose();
  }

  // 닉네임 중복 검증 (실시간)
  Future<void> _checkNicknameDuplicate(String nickname) async {
    // 기존 닉네임과 같거나 조건 미달 시 검증 안함
    if (nickname.isEmpty || nickname.length < 2 || nickname.trim() == _originalNickname) {
      setState(() {
        _nicknameValidationMessage = null;
        _isCheckingNickname = false;
      });
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _nicknameValidationMessage = null;
    });

    try {
      final profileController = context.read<ProfileController>();
      final isDuplicate = await profileController.isNicknameDuplicate(nickname);
      
      if (mounted) {
        setState(() {
          _isCheckingNickname = false;
          _nicknameValidationMessage = isDuplicate ? '이미 사용 중인 닉네임입니다.' : '사용 가능한 닉네임입니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingNickname = false;
          _nicknameValidationMessage = '닉네임 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  // 이미지 선택 메서드
  Future<void> _selectSingleImage(int index) async {
    if (_isPickerActive) return;

    // 갤러리/저장소 권한 확인 로직
    if (!kIsWeb) { // 웹이 아닐 때만 권한 체크
      PermissionStatus status;

      if (Platform.isAndroid) {
        // Android 버전에 따라 권한 분기
        // (단순화를 위해 photos로 통합 요청, permission_handler가 버전에 맞춰 처리)
        status = await Permission.photos.request();

        // Android 12 이하 대응 (photos가 거부되면 storage 요청)
        if (status.isDenied || status.isPermanentlyDenied) {
          status = await Permission.storage.request();
        }
      } else {
        // iOS
        status = await Permission.photos.request();
      }

      // 권한이 거부되었거나 영구적으로 거부된 경우
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) _showPermissionDialog(); // 다이얼로그 띄우기
        return;
      }
    }

    try {
      _isPickerActive = true;
      final image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          // 기존 이미지가 URL(String)이었다면 삭제 목록에 추가
          if (_imageSlots[index] is String) {
            _imagesToDelete.add(_imageSlots[index] as String);
          }
          // 새 이미지로 슬롯 교체
          _imageSlots[index] = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      _isPickerActive = false;
    }
  }

// 권한 설정 유도 다이얼로그
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('권한 설정 필요'),
        content: const Text('프로필 사진을 등록하려면 갤러리 접근 권한이 필요합니다.\n설정에서 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // permission_handler 기능: 앱 설정 화면으로 이동
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  // 이미지 슬롯 삭제
  void _removeImageFromSlot(int index) {
    setState(() {
      final currentImage = _imageSlots[index];
      if (currentImage is String) {
        // 기존 이미지(URL)라면 삭제 목록에 추가
        _imagesToDelete.add(currentImage);
      }
      // 슬롯을 비움
      _imageSlots[index] = null;
      
      // 메인 프로필 인덱스 조정
      if (_mainProfileIndex == index) {
        // 첫 번째 유효한 이미지를 새 메인 프로필로 설정
        _mainProfileIndex = _imageSlots.indexWhere((img) => img != null);
        if (_mainProfileIndex == -1) _mainProfileIndex = 0; // 이미지가 없으면 0으로 초기화
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 편집'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          Consumer<ProfileController>(
            builder: (context, profileController, _) {
              return TextButton(
                onPressed: profileController.isLoading ? null : _saveProfile,
                child: profileController.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthController, ProfileController>(
        builder: (context, authController, profileController, _) {
          final user = authController.currentUserModel;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 프로필 사진 섹션
                  Text(
                    '프로필 사진',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '최대 6장 사진을 등록해주세요.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '이미지를 길게 눌러서 대표 프로필로 설정할 수 있습니다.',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 프로필 이미지 그리드 (3x2)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.gray300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // 첫 번째 줄 (1, 2, 3번)
                          Row(
                            children: [
                              Expanded(child: _buildImageGridSlot(0)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildImageGridSlot(1)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildImageGridSlot(2)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 두 번째 줄 (4, 5, 6번)
                          Row(
                            children: [
                              Expanded(child: _buildImageGridSlot(3)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildImageGridSlot(4)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildImageGridSlot(5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 닉네임 입력
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          labelText: '닉네임',
                          hintText: '닉네임을 입력하세요',
                          prefixIcon: const Icon(Icons.person_outline),
                          suffixIcon: _isCheckingNickname
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                        maxLength: 10,
                        onChanged: (value) {
                          // 디바운싱을 위해 타이머 사용
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_nicknameController.text == value) {
                              _checkNicknameDuplicate(value);
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '닉네임을 입력해주세요.';
                          }
                          if (value.trim().length < 2) {
                            return '닉네임은 2자 이상이어야 합니다.';
                          }
                          return null;
                        },
                      ),
                      if (_nicknameValidationMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            _nicknameValidationMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _nicknameValidationMessage == '사용 가능한 닉네임입니다.'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 키 입력
                  TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: '키 (cm)',
                      hintText: '키를 입력하세요',
                      prefixIcon: Icon(Icons.height),
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '키를 입력해주세요.';
                      }
                      final height = int.tryParse(value.trim());
                      if (height == null || height < 140 || height > 220) {
                        return '올바른 키를 입력해주세요. (140-220cm)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // 활동지역 입력
                  TextFormField(
                    controller: _activityAreaController,
                    decoration: const InputDecoration(
                      labelText: '활동지역',
                      hintText: '활동지역을 입력하세요',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '활동지역을 입력해주세요.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // 소개글 입력
                  TextFormField(
                    controller: _introductionController,
                    decoration: const InputDecoration(
                      labelText: '소개글',
                      prefixIcon: Icon(Icons.edit),
                      alignLabelWithHint: true,
                      helperText: '200자 이내',
                    ),
                    maxLines: 6,
                    maxLength: 200,
                    // [수정됨] validator 로직 변경
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '소개글을 입력해주세요.';
                      }
                      // 5자 미만 체크 추가
                      if (value.trim().length < 5) {
                        return '소개글은 5자 이상 작성해주세요.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // 수정 불가능한 정보 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.gray200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '수정 불가능한 정보',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyInfo('아이디', 
                          context.read<AuthController>().firebaseService.currentUser?.email ?? ''),
                        _buildReadOnlyInfo('전화번호', _formatPhoneNumber(user.phoneNumber)),
                        _buildReadOnlyInfo('생년월일', _formatBirthDate(user.birthDate)),
                        _buildReadOnlyInfo('성별', user.gender),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 에러 메시지
                  Consumer<ProfileController>(
                    builder: (context, profileController, _) {
                      if (profileController.errorMessage != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.errorColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            profileController.errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadOnlyInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
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

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length == 11) {
      return '${phoneNumber.substring(0, 3)}-${phoneNumber.substring(3, 7)}-${phoneNumber.substring(7)}';
    }
    return phoneNumber;
  }

  String _formatBirthDate(String birthDate) {
    if (birthDate.length == 8) {
      return '${birthDate.substring(0, 4)}-${birthDate.substring(4, 6)}-${birthDate.substring(6)}';
    }
    return birthDate;
  }

  Future<void> _saveProfile() async {
    // 1. 폼 유효성 검사
    if (!_formKey.currentState!.validate()) return;

    // 2. 닉네임 중복 체크 확인
    if (_nicknameValidationMessage == '이미 사용 중인 닉네임입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 닉네임입니다. 다른 닉네임을 사용해주세요.')),
      );
      return;
    }

    // 3. 이미지 최소 1장 필수 체크
    final hasImages = _imageSlots.any((image) => image != null);
    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 최소 1장 등록해주세요.')),
      );
      return;
    }

    final profileController = context.read<ProfileController>();
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;
    if (user == null) return;

    // 4. 삭제할 이미지들 Firebase Storage에서 삭제
    for (String imageUrl in _imagesToDelete) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (e) {
        // 이미지 삭제 실패는 무시하고 진행 (이미 없는 경우 등)
        debugPrint('이미지 삭제 실패: $e');
      }
    }

    // 5. 최종 이미지 목록 생성 및 업로드
    List<String> finalImages = [];
    List<dynamic> sortedImageSlots = List.from(_imageSlots);

    // 메인 프로필(대표 사진)을 목록의 맨 앞으로 이동
    if (_mainProfileIndex >= 0 && _mainProfileIndex < sortedImageSlots.length) {
      final mainImage = sortedImageSlots.removeAt(_mainProfileIndex);
      if (mainImage != null) {
        sortedImageSlots.insert(0, mainImage);
      }
    }

    // 이미지 리스트 순회하며 URL 수집 또는 업로드
    for (final image in sortedImageSlots) {
      if (image is String) {
        // 기존 이미지 URL
        finalImages.add(image);
      } else if (image is XFile) {
        // 새로 추가된 이미지 파일 -> 업로드 진행
        try {
          final fileName = '${user.uid}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = FirebaseStorage.instance.ref().child('profile_images').child(user.uid).child(fileName);

          late UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            uploadTask = ref.putData(bytes);
          } else {
            uploadTask = ref.putFile(File(image.path));
          }

          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          finalImages.add(downloadUrl);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
            );
          }
          return;
        }
      }
    }

    // 6. 컨트롤러를 통해 프로필 정보 업데이트 요청
    final success = await profileController.updateProfile(
      nickname: _nicknameController.text.trim(),
      introduction: _introductionController.text.trim(),
      height: int.parse(_heightController.text.trim()),
      activityArea: _activityAreaController.text.trim(),
      profileImages: finalImages,
    );

    // 7. 성공 시 처리
    if (success && mounted) {
      await authController.refreshCurrentUser(); // 현재 사용자 정보 새로고침
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')));
      Navigator.pop(context); // 화면 닫기
    } else if (mounted && profileController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileController.errorMessage!)),
      );
    }
  }

  Widget _buildImageWidget(dynamic imageData) {
    if (imageData is XFile) {
      // 새로 선택된 이미지 (XFile)
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: imageData.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      } else {
        return Image.file(File(imageData.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
    } else if (imageData is String) {
      // 기존 저장된 이미지 (URL)
      return _buildProfileImage(imageData);
    } else {
      // 빈 슬롯
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, color: AppTheme.gray300, size: 24),
          const SizedBox(height: 4),
          Text('${_imageSlots.indexOf(imageData) + 1}번', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      );
    }
  }

  Widget _buildProfileImage(String imageUrl) {
    // 유효한 네트워크 이미지만 표시
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.person, color: AppTheme.textSecondary),
      );
    } else {
      return const Icon(Icons.person, color: AppTheme.textSecondary);
    }
  }

  // 메인 프로필 설정 메서드
  void _setMainProfile(int index) {
    setState(() {
      _mainProfileIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${index + 1}번 이미지가 대표 프로필로 설정되었습니다.')),
    );
  }

  // 새로운 그리드 이미지 슬롯 빌더
  Widget _buildImageGridSlot(int index) {
    final imageData = _imageSlots[index];
    final hasImage = imageData != null;
    final isMainProfile = index == _mainProfileIndex && hasImage;
    
    return AspectRatio(
      aspectRatio: 1.0, // 정사각형 비율
      child: GestureDetector(
        onTap: !hasImage ? () => _selectSingleImage(index) : null,
        onLongPress: hasImage ? () => _setMainProfile(index) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isMainProfile 
                  ? AppTheme.primaryColor
                  : hasImage 
                      ? AppTheme.gray300 
                      : AppTheme.gray200,
              width: isMainProfile ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasImage
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildImageWidget(imageData),
                    ),
                    if (isMainProfile)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('대표', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: () => _removeImageFromSlot(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: () => _selectSingleImage(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: AppTheme.gray300, size: 24),
                      const SizedBox(height: 4),
                      Text('${index + 1}번', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

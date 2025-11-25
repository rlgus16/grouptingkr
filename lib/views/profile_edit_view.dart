import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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
  List<XFile?> _selectedImages = List.filled(6, null); // 6개 슬롯을 null로 초기화
  List<String> _originalImages = []; // 기존 저장된 이미지들
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
    _cleanupInvalidImages();
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
      _originalImages = user.profileImages.where((imageUrl) {
        // 로컬 경로 (local://, temp://)는 제외하고 Firebase Storage URL만 유지
        return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
      }).toList();
      
      // 기존 프로필 이미지들: $_originalImages

    }
  }

  // 무효한 이미지 경로들을 데이터베이스에서 정리
  Future<void> _cleanupInvalidImages() async {
    final profileController = context.read<ProfileController>();
    final authController = context.read<AuthController>();
    
    try {
      final success = await profileController.cleanupProfileImages();
      if (success) {
        // 정리 후 사용자 정보 새로고침
        await authController.refreshCurrentUser();
        // 컨트롤러 다시 초기화
        if (mounted) {
          _initializeControllers();
        }
      }
    } catch (e) {
      // 이미지 정리 중 오류: $e
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

  // 이미지 선택 메서드들
  Future<void> _selectSingleImage(int index) async {
    if (_isPickerActive) return; // 이미 활성화 중이면 리턴
    
    try {
      _isPickerActive = true;
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          // 해당 인덱스에 직접 이미지 저장
          _selectedImages[index] = image;
        });
      }
    } catch (e) {
      // 이미지 선택 오류: $e
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      _isPickerActive = false;
    }
  }

  // 해당 슬롯에 표시할 이미지 반환 (편집된 이미지 우선, 없으면 기존 이미지)
  dynamic _getImageForSlot(int index) {
    // 편집된 이미지가 있으면 우선 반환
    if (_selectedImages[index] != null) {
      return _selectedImages[index];
    }
    
    // 기존 이미지가 있으면 반환
    if (index < _originalImages.length) {
      return _originalImages[index];
    }
    
    return null;
  }

  // 이미지 슬롯 삭제 (편집된 이미지 또는 기존 이미지)
  void _removeImageFromSlot(int index) {
    setState(() {
      if (_selectedImages[index] != null) {
        // 편집된 이미지가 있으면 제거
        _selectedImages[index] = null;
      } else if (index < _originalImages.length) {
        // 기존 이미지를 삭제 표시 (빈 XFile로 설정)
        _selectedImages[index] = null;
        // 실제로는 저장 시 해당 인덱스를 제외하도록 처리
      }
      
      // 메인 프로필 인덱스 조정
      if (_mainProfileIndex == index) {
        // 삭제된 이미지가 메인 프로필이었다면 첫 번째 유효한 이미지로 변경
        int newMainIndex = -1;
        for (int i = 0; i < 6; i++) {
          if (_getImageForSlot(i) != null) {
            newMainIndex = i;
            break;
          }
        }
        _mainProfileIndex = newMainIndex >= 0 ? newMainIndex : 0;
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
                      hintText: '자신을 소개해주세요',
                      prefixIcon: Icon(Icons.edit_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: 100,
                    validator: (value) {
                      if (value != null && value.trim().length > 100) {
                        return '소개글은 100자 이하로 입력해주세요.';
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
    if (!_formKey.currentState!.validate()) return;

    // 닉네임 중복 검증
    if (_nicknameValidationMessage == '이미 사용 중인 닉네임입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 닉네임입니다. 다른 닉네임을 사용해주세요.')),
      );
      return;
    }

    final profileController = context.read<ProfileController>();
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;

    if (user == null) return;

    // 새로 선택된 이미지들과 기존 이미지들 분리
    List<XFile> newImages = [];
    List<String> finalImages = [];
    bool hasImageChanges = false;

    // 1. 새로 선택된 이미지들 수집
    for (int i = 0; i < 6; i++) {
      if (_selectedImages[i] != null) {
        newImages.add(_selectedImages[i]!);
        hasImageChanges = true;
      }
    }

    // 2. 새 이미지들 업로드 (있는 경우)
    List<String> uploadedUrls = [];
    if (newImages.isNotEmpty) {
      try {
        // 새 이미지 업로드 시작: ${newImages.length}개
        for (int i = 0; i < newImages.length; i++) {
          final file = newImages[i];
          final fileName = '${user.uid}_profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

          // Firebase Storage에 업로드
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child(user.uid)
              .child(fileName);

          // 플랫폼별 업로드 처리
          late UploadTask uploadTask;
          if (kIsWeb) {
            // 웹에서는 XFile에서 bytes 사용
            final bytes = await file.readAsBytes();
            uploadTask = ref.putData(bytes);
          } else {
            // 모바일에서는 XFile을 File로 변환
            final ioFile = File(file.path);
            uploadTask = ref.putFile(ioFile);
          }

          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          uploadedUrls.add(downloadUrl);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
          );
        }
        return;
      }
    }

    // 3. 최종 이미지 목록 생성 (메인 프로필 우선)
    List<String> tempImages = [];
    int uploadedIndex = 0;
    
    // 먼저 모든 이미지를 순서대로 수집
    for (int i = 0; i < 6; i++) {
      if (_selectedImages[i] != null) {
        // 새로 선택된 이미지
        if (uploadedIndex < uploadedUrls.length) {
          tempImages.add(uploadedUrls[uploadedIndex]);
          uploadedIndex++;
        }
        hasImageChanges = true;
      } else if (i < _originalImages.length) {
        // 기존 이미지 유지
        tempImages.add(_originalImages[i]);
      }
    }
    
    // 메인 프로필 이미지가 있다면 첫 번째로 이동
    if (tempImages.isNotEmpty && _mainProfileIndex < tempImages.length) {
      String mainProfileImage = tempImages[_mainProfileIndex];
      tempImages.removeAt(_mainProfileIndex);
      finalImages.add(mainProfileImage);
      finalImages.addAll(tempImages);
    } else {
      finalImages.addAll(tempImages);
    }

    final success = await profileController.updateProfile(
      nickname: _nicknameController.text.trim(),
      introduction: _introductionController.text.trim(),
      height: int.parse(_heightController.text.trim()),
      activityArea: _activityAreaController.text.trim(),
      profileImages: hasImageChanges ? finalImages : null,
    );

    if (success && mounted) {
      // 사용자 정보 새로고침
      await authController.refreshCurrentUser();
      
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')));
      Navigator.pop(context);
    } else if (mounted && profileController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileController.errorMessage!)),
      );
    }
  }

  Widget _buildImageWidget(dynamic imageData, {bool isMainProfile = false}) {
    if (imageData is XFile) {
      // 새로 선택된 이미지 (XFile)
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: imageData.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Center(
                child: Image.memory(
                  snapshot.data!,
                  width: isMainProfile ? double.infinity : 80,
                  height: isMainProfile ? double.infinity : 80,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              return Container(
                width: isMainProfile ? double.infinity : 80,
                height: 80,
                color: AppTheme.gray200,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
          },
        );
      } else {
        return FutureBuilder<Uint8List>(
          future: imageData.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Center(
                child: Image.memory(
                  snapshot.data!,
                  width: isMainProfile ? double.infinity : 80,
                  height: isMainProfile ? double.infinity : 80,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              return Container(
                width: isMainProfile ? double.infinity : 80,
                height: 80,
                color: AppTheme.gray200,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
          },
        );
      }
    } else if (imageData is String) {
      // 기존 저장된 이미지 (URL)
      return Center(child: _buildProfileImage(imageData, isMainProfile ? 200 : 80));
    } else {
      // 빈 슬롯
      return Container(
        width: isMainProfile ? double.infinity : 80,
        height: 80,
        color: AppTheme.gray200,
        child: Icon(
          Icons.add_photo_alternate,
          size: isMainProfile ? 48 : 24,
          color: AppTheme.gray400,
        ),
      );
    }
  }

  Widget _buildProfileImage(String imageUrl, double size) {
    // 유효한 네트워크 이미지만 표시
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
            Icon(Icons.person, size: size * 0.5, color: AppTheme.textSecondary),
      );
    } else {
      // 로컬 이미지나 잘못된 URL은 기본 아이콘으로 표시 -> 추후 정리 도움드리면 될 것으로 보임.
      return Icon(
        Icons.person,
        size: size * 0.5,
        color: AppTheme.textSecondary,
      );
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
    final imageData = _getImageForSlot(index);
    final hasImage = imageData != null;
    final isMainProfile = index == _mainProfileIndex && hasImage;
    
    return AspectRatio(
      aspectRatio: 1.0, // 정사각형 비율
      child: GestureDetector(
        onTap: () => _selectSingleImage(index),
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
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildImageWidget(imageData),
                    ),
                    // 메인 프로필 표시
                    if (isMainProfile)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '대표',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // 삭제 버튼
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImageFromSlot(index),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add,
                      color: AppTheme.gray300,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${index + 1}번',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

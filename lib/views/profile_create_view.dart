import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:io' if (dart.library.html) '';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../utils/app_theme.dart';

class ProfileCreateView extends StatefulWidget {
  const ProfileCreateView({super.key});

  @override
  State<ProfileCreateView> createState() => _ProfileCreateViewState();
}

class _ProfileCreateViewState extends State<ProfileCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _heightController = TextEditingController();
  final _introductionController = TextEditingController();
  final _activityAreaController = TextEditingController();
  final _userIdController = TextEditingController();

  String _selectedGender = '';
  DateTime? _selectedDate;
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  // 이미지 피커 활성화 상태 플래그
  bool _isPickerActive = false;
  
  // 회원가입에서 전달받은 데이터
  Map<String, dynamic>? _registerData;

  @override
  void initState() {
    super.initState();
    // initState에서는 ModalRoute.of(context)를 사용할 수 없으므로 
    // didChangeDependencies에서 처리
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 회원가입에서 전달받은 데이터 가져오기
    if (_registerData == null) {
      _registerData = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_registerData != null) {
        _initializeWithRegisterData();
      } else {
        // AuthWrapper에서 온 경우 현재 사용자 정보로 초기화
        _initializeWithCurrentUser();
      }
    }
  }

  void _initializeWithRegisterData() {
    print('회원가입 데이터 초기화: $_registerData');
    _userIdController.text = _registerData!['userId'] ?? '';
    _phoneController.text = _registerData!['phoneNumber'] ?? '';
    _birthDateController.text = _registerData!['birthDate'] ?? '';
    _selectedGender = _registerData!['gender'] ?? '';
    // 키는 프로필 생성 시 입력받으므로 초기화하지 않음
    
    // 생년월일을 DateTime으로 변환
    if (_registerData!['birthDate'] != null && _registerData!['birthDate'].length == 8) {
      final birthStr = _registerData!['birthDate'];
      try {
        _selectedDate = DateTime(
          int.parse(birthStr.substring(0, 4)),
          int.parse(birthStr.substring(4, 6)),
          int.parse(birthStr.substring(6, 8)),
        );
      } catch (e) {
        print('생년월일 파싱 오류: $e');
      }
    }
    
    setState(() {
      // UI 업데이트
    });
  }

  void _initializeWithCurrentUser() {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;
    
    if (currentUser != null) {
      print('현재 사용자 정보로 초기화: ${currentUser.userId}');
      _userIdController.text = currentUser.userId;
      _phoneController.text = currentUser.phoneNumber;
      _birthDateController.text = currentUser.birthDate;
      _selectedGender = currentUser.gender;
      // 키는 0이면 빈 값으로, 아니면 기존 값 표시
      _heightController.text = currentUser.height > 0 ? currentUser.height.toString() : '';
      
      // 생년월일을 DateTime으로 변환
      if (currentUser.birthDate.isNotEmpty && currentUser.birthDate.length == 8) {
        final birthStr = currentUser.birthDate;
        try {
          _selectedDate = DateTime(
            int.parse(birthStr.substring(0, 4)),
            int.parse(birthStr.substring(4, 6)),
            int.parse(birthStr.substring(6, 8)),
          );
        } catch (e) {
          print('생년월일 파싱 오류: $e');
        }
      }
      
      setState(() {
        // UI 업데이트
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    _birthDateController.dispose();
    _heightController.dispose();
    _introductionController.dispose();
    _activityAreaController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  // 생년월일 선택은 회원가입에서 이미 완료되어 더 이상 사용하지 않음
  // Future<void> _selectBirthDate() async { ... }

  Future<void> _selectImages() async {
    if (_isPickerActive) return; // 이미 활성화 중이면 리턴
    
    try {
      _isPickerActive = true;
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty && images.length <= 6) {
        setState(() {
          _selectedImages = images;
        });
      } else if (images.length > 6) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('최대 6장까지 선택할 수 있습니다.')));
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      _isPickerActive = false;
    }
  }

  Future<void> _selectSingleImage(int index) async {
    if (_isPickerActive) return; // 이미 활성화 중이면 리턴
    
    try {
      _isPickerActive = true;
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          if (index < _selectedImages.length) {
            // 기존 이미지 교체
            _selectedImages[index] = image;
          } else if (index == _selectedImages.length) {
            // 다음 순서에 새 이미지 추가
            _selectedImages.add(image);
          } else {
            // 중간에 빈 공간이 있는 경우, 마지막에 추가
            _selectedImages.add(image);
          }
        });
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      _isPickerActive = false;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필 사진을 최소 1장 선택해주세요.')));
      return;
    }

    final authController = context.read<AuthController>();

    // 이미지 업로드 먼저 처리
    List<String> imageUrls = [];
    if (_selectedImages.isNotEmpty) {
      try {
        final profileController = context.read<ProfileController>();
        // 임시로 이미지 업로드 (실제 구현 시 Firebase Storage 사용)
        imageUrls = _selectedImages.map((image) => 'temp://${image.path}').toList();
        print('이미지 업로드 완료: $imageUrls');
      } catch (e) {
        print('이미지 업로드 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
          );
        }
        return;
      }
    }

    // 실제 Firebase 계정 생성과 프로필 완성
    await authController.completeRegistrationWithProfile(
      nickname: _nicknameController.text.trim(),
      introduction: _introductionController.text.trim(),
      height: int.parse(_heightController.text.trim()),
      activityArea: _activityAreaController.text.trim(),
      profileImages: imageUrls,
    );

    if (mounted) {
      if (authController.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authController.errorMessage!)),
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  Future<void> _skipProfile() async {
    // 확인 다이얼로그 표시
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 생성 건너뛰기'),
        content: const Text('프로필을 나중에 설정하고 바로 시작하시겠습니까?\n언제든지 마이페이지에서 프로필을 완성할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나중에'),
          ),
        ],
      ),
    );

    if (shouldSkip == true) {
      final authController = context.read<AuthController>();
      
      // 프로필 없이 계정만 생성
      await authController.completeRegistrationWithoutProfile();

      if (mounted) {
        if (authController.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authController.errorMessage!)),
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('프로필 생성'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 회원가입에서 온 경우에만 회원가입 페이지로 돌아가기
            if (_registerData != null) {
              Navigator.pushReplacementNamed(context, '/register');
            } else {
              // AuthWrapper에서 온 경우 로그아웃
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('프로필 생성 취소'),
                  content: const Text('프로필 생성을 취소하고 로그아웃하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('계속 작성'),
                    ),
                                         TextButton(
                       onPressed: () {
                         Navigator.of(context).pop();
                         final authController = context.read<AuthController>();
                         authController.clearTemporaryData(); // 임시 데이터 정리
                         authController.signOut();
                       },
                       child: const Text('로그아웃'),
                     ),
                  ],
                ),
              );
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 2),

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
                  '1번 사진은 프로필 사진으로 사용됩니다.',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.gray300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // 좌측 메인 프로필 이미지 (1번)
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => _selectSingleImage(0),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedImages.isNotEmpty
                                      ? AppTheme.primaryColor
                                      : AppTheme.gray300,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _selectedImages.isNotEmpty
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: _buildImageWidget(
                                            _selectedImages[0],
                                            isMainProfile: true,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '프로필',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedImages.removeAt(0);
                                              });
                                            },
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 48,
                                          color: AppTheme.gray400,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          '1번\n프로필 사진',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 우측 작은 이미지들 (2-6번)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // 상단 2개
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildSmallImageSlot(1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSmallImageSlot(2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 하단 2개
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildSmallImageSlot(3),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSmallImageSlot(4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 5-6번 이미지 슬롯 (하단 추가)
                if (_selectedImages.length >= 4) // 4개 이상일 때 5-6번 슬롯 표시
                  Container(
                    height: 80,
                    child: Row(
                      children: [
                        Expanded(child: _buildSmallImageSlot(4)), // 5번째 이미지
                        const SizedBox(width: 12),
                        Expanded(child: _buildSmallImageSlot(5)), // 6번째 이미지
                        const SizedBox(width: 12),
                        Expanded(child: Container()), // 빈 공간
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // 회원가입 정보 섹션
                Text(
                  '회원가입 정보 (변경 불가)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 아이디 (읽기 전용)
                TextFormField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: '아이디',
                    prefixIcon: Icon(Icons.person),
                    suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                    enabled: false,
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // 전화번호 (읽기 전용)
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '전화번호',
                    prefixIcon: Icon(Icons.phone),
                    suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                    enabled: false,
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // 생년월일 (읽기 전용)
                TextFormField(
                  controller: _birthDateController,
                  decoration: const InputDecoration(
                    labelText: '생년월일',
                    prefixIcon: Icon(Icons.calendar_today),
                    suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                    enabled: false,
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // 성별 (읽기 전용)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            const Text('성별'),
                            const Spacer(),
                            const Icon(Icons.lock, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedGender == '남' ? '남성' : '여성',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 24),

                // 추가 정보 섹션
                Text(
                  '추가 정보 입력',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 키 (신규 입력)
                TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: '키 (cm)',
                    prefixIcon: Icon(Icons.straighten),
                    helperText: '140 ~ 220cm 사이의 숫자를 입력해주세요',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '키를 입력해주세요.';
                    }
                    final height = int.tryParse(value.trim());
                    if (height == null || height < 140 || height > 220) {
                      return '140cm ~ 220cm 사이의 값을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 닉네임
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    prefixIcon: Icon(Icons.badge),
                    helperText: '10자 이내',
                  ),
                  maxLength: 10,
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
                const SizedBox(height: 16),

                // 활동지역
                TextFormField(
                  controller: _activityAreaController,
                  decoration: const InputDecoration(
                    labelText: '활동지역',
                    prefixIcon: Icon(Icons.location_on),
                    helperText: '예: 강남구, 홍대, 건대 등',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '활동지역을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 자기소개
                TextFormField(
                  controller: _introductionController,
                  decoration: const InputDecoration(
                    labelText: '소개글',
                    prefixIcon: Icon(Icons.edit),
                    alignLabelWithHint: true,
                    helperText: '100자 이내',
                  ),
                  maxLines: 3,
                  maxLength: 100,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '소개글을 입력해주세요.';
                    }
                    if (value.trim().length < 10) {
                      return '소개글은 10자 이상 작성해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // 완료 및 스킵 버튼
                Consumer<AuthController>(
                  builder: (context, authController, _) {
                    if (authController.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Column(
                      children: [
                        // 프로필 완성 버튼
                        ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            '프로필 완성하기',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 나중에 하기 버튼
                        OutlinedButton(
                          onPressed: _skipProfile,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            '나중에 설정하기',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // 에러 메시지
                Consumer<AuthController>(
                  builder: (context, authController, _) {
                    if (authController.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          authController.errorMessage!,
                          style: const TextStyle(color: AppTheme.errorColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(XFile imageFile, {bool isMainProfile = false}) {
    if (kIsWeb) {
      // 웹에서는 Image.network 또는 FutureBuilder 사용
      return FutureBuilder<Uint8List>(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              width: isMainProfile ? double.infinity : 80,
              height: double.infinity,
              fit: BoxFit.cover,
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
      // 모바일에서는 XFile path로 이미지 표시
      return FutureBuilder<Uint8List>(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              width: isMainProfile ? double.infinity : 80,
              height: double.infinity,
              fit: BoxFit.cover,
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
  }

  Widget _buildSmallImageSlot(int index) {
    final hasImage = _selectedImages.length > index;
    final isNextSlot = index == _selectedImages.length; // 다음에 추가할 수 있는 슬롯인지
    final canAddImage = _selectedImages.length < 6; // 더 추가할 수 있는지
    
    return GestureDetector(
      onTap: hasImage || (isNextSlot && canAddImage) ? () => _selectSingleImage(index) : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: hasImage 
                ? AppTheme.gray300 
                : (isNextSlot && canAddImage) 
                    ? AppTheme.primaryColor.withOpacity(0.5)
                    : AppTheme.gray200
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: hasImage
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildImageWidget(_selectedImages[index]),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.removeAt(index);
                        });
                      },
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
                  Icon(
                    Icons.add,
                    color: (isNextSlot && canAddImage) 
                        ? AppTheme.primaryColor 
                        : AppTheme.gray300,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    index == 5 ? '6번' : '${index + 2}번',
                    style: TextStyle(
                      color: (isNextSlot && canAddImage) 
                          ? AppTheme.primaryColor 
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

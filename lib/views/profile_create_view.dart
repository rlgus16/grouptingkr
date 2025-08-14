import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  List<XFile?> _selectedImages = List.filled(6, null); // 6개 슬롯을 null로 초기화
  final ImagePicker _picker = ImagePicker();
  
  // 이미지 피커 활성화 상태 플래그
  bool _isPickerActive = false;
  int _mainProfileIndex = 0; // 메인 프로필 이미지 인덱스 (기본값: 0번)
  
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
    // 회원가입에서 전달받은 데이터로 초기화
    final authController = context.read<AuthController>();
    final tempData = authController.tempRegistrationData;
    
    // 우선 tempRegistrationData를 사용하고, 없으면 arguments 사용
    if (tempData != null) {
      _userIdController.text = tempData['userId'] ?? '';
      _phoneController.text = tempData['phoneNumber'] ?? '';
      _birthDateController.text = tempData['birthDate'] ?? '';
      _selectedGender = tempData['gender'] ?? '';
    } else if (_registerData != null) {
      _userIdController.text = _registerData!['userId'] ?? '';
      _phoneController.text = _registerData!['phoneNumber'] ?? '';
      _birthDateController.text = _registerData!['birthDate'] ?? '';
      _selectedGender = _registerData!['gender'] ?? '';
    }
    // 키는 프로필 생성 시 입력받으므로 초기화하지 않음
    
    // 생년월일을 DateTime으로 변환
    final birthDate = tempData?['birthDate'] ?? _registerData?['birthDate'];
    if (birthDate != null && birthDate.length == 8) {
      try {
        _selectedDate = DateTime(
          int.parse(birthDate.substring(0, 4)),
          int.parse(birthDate.substring(4, 6)),
          int.parse(birthDate.substring(6, 8)),
        );
      } catch (e) {
        // print('생년월일 파싱 오류: $e');
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
      // print('현재 사용자 정보로 초기화: ${currentUser.userId}');
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
          // print('생년월일 파싱 오류: $e');
        }
      }
      
      setState(() {
        // UI 업데이트
      });
    } else {
      // 현재 사용자 정보가 없는 경우 (프로필이 없는 상태)
      // print('현재 사용자 정보가 없음 - 빈 폼으로 초기화');
      _initializeEmptyForm();
    }
  }

  // 빈 폼으로 초기화하는 메서드
  void _initializeEmptyForm() {
    _userIdController.text = '';
    _phoneController.text = '';
    _birthDateController.text = '';
    _selectedGender = '';
    _heightController.text = '';
    _nicknameController.text = '';
    _introductionController.text = '';
    _activityAreaController.text = '';
    _selectedDate = null;
    _selectedImages = List.filled(6, null);
    
    setState(() {
      // UI 업데이트
    });
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
          // 선택된 이미지들을 순서대로 빈 슬롯에 배치
          for (int i = 0; i < images.length && i < 6; i++) {
            _selectedImages[i] = images[i];
          }
          // 나머지 슬롯은 null로 유지
          for (int i = images.length; i < 6; i++) {
            _selectedImages[i] = null;
          }
        });
      } else if (images.length > 6) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('최대 6장까지 선택할 수 있습니다.')));
      }
    } catch (e) {
      // print('이미지 선택 오류: $e');
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
          // 해당 인덱스에 직접 이미지 저장
          _selectedImages[index] = image;
        });
      }
    } catch (e) {
      // print('이미지 선택 오류: $e');
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

    // 이미지는 선택사항으로 변경 (나중에 업로드 가능)

    final authController = context.read<AuthController>();

    // 실제 Firebase 계정 생성과 프로필 완성 (이미지 포함)
    List<XFile> sortedImages = [];
    
    // 선택된 이미지가 있는지 확인
    final hasImages = _selectedImages.any((image) => image != null);
    
    if (hasImages) {
      // 메인 프로필 이미지가 있다면 첫 번째로 추가
      if (_selectedImages[_mainProfileIndex] != null) {
        sortedImages.add(_selectedImages[_mainProfileIndex]!);
      }
      
      // 나머지 이미지들 추가 (메인 프로필 제외)
      for (int i = 0; i < _selectedImages.length; i++) {
        if (i != _mainProfileIndex && _selectedImages[i] != null) {
          sortedImages.add(_selectedImages[i]!);
        }
      }
    }

    // 회원가입 데이터가 있는 경우와 없는 경우를 구분해서 처리
    if (_registerData != null || authController.tempRegistrationData != null) {
      // 회원가입 과정에서 온 경우 - 기존 로직 사용
      await authController.completeRegistrationWithProfile(
        nickname: _nicknameController.text.trim(),
        introduction: _introductionController.text.trim(),
        height: int.parse(_heightController.text.trim()),
        activityArea: _activityAreaController.text.trim(),
        profileImages: sortedImages.isNotEmpty ? sortedImages : null,
      );
    } else {
      // 홈 화면에서 온 경우 - 새로운 프로필 생성
      await _createNewProfile(authController, sortedImages);
    }

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

  // 새로운 프로필 생성 메서드 (이미 로그인된 사용자용)
  Future<void> _createNewProfile(AuthController authController, List<XFile> sortedImages) async {
    try {
      // 기본 정보가 비어있는 경우 사용자에게 입력을 요구
      if (_userIdController.text.isEmpty || 
          _phoneController.text.isEmpty || 
          _birthDateController.text.isEmpty || 
          _selectedGender.isEmpty) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필을 완성하려면 먼저 회원가입을 완료해주세요. 로그아웃 후 회원가입을 진행해주세요.'),
          ),
        );
        return;
      }

      // 현재 Firebase Auth 사용자 정보 가져오기
      final currentUser = authController.firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인 상태가 아닙니다.');
      }

      // 이미지 업로드 처리
      List<String> imageUrls = [];
      if (sortedImages.isNotEmpty) {
        try {
          for (int i = 0; i < sortedImages.length; i++) {
            final file = sortedImages[i];
            final fileName = '${currentUser.uid}_profile_$i.jpg';

            // print('Firebase Storage 업로드 시작: $fileName');

            // Firebase Storage에 업로드
            final ref = FirebaseStorage.instance
                .ref()
                .child('profile_images')
                .child(currentUser.uid)
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

            // print('Firebase Storage 업로드 성공: $downloadUrl');
            imageUrls.add(downloadUrl);
          }
        } catch (e) {
          // print('이미지 업로드 실패: $e');
          // 이미지 업로드 실패해도 계속 진행
          authController.setError('이미지 업로드에 실패했습니다. 프로필은 생성되었으니 나중에 다시 업로드해주세요.');
        }
      }

      await authController.createCompleteUserProfile(
        currentUser.uid,
        _userIdController.text.trim(), // 아이디 사용
        currentUser.email ?? '',
        _phoneController.text.trim(),
        _birthDateController.text.trim(),
        _selectedGender,
        _nicknameController.text.trim(),
        _introductionController.text.trim(),
        int.parse(_heightController.text.trim()),
        _activityAreaController.text.trim(),
        imageUrls,
      );
      
      // 프로필 생성 후 사용자 정보 새로고침
      await authController.refreshCurrentUser();
      
    } catch (e) {
      // print('새 프로필 생성 실패: $e');
      authController.setError('프로필 생성에 실패했습니다: $e');
    }
  }

  Future<void> _skipProfile() async {
    final authController = context.read<AuthController>();
    
    // 회원가입 데이터가 있는 경우와 없는 경우를 구분
    if (_registerData != null || authController.tempRegistrationData != null) {
      // 회원가입 과정에서 온 경우 - 확인 다이얼로그 표시 후 스킵 처리
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
    } else {
      // 홈 화면에서 온 경우 - 바로 홈으로 돌아가기
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
                  '이미지를 길게 눌러서 대표 프로필로 설정할 수 있습니다.',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.gray300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // 상단 3개 이미지 (1, 2, 3번)
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
                        // 하단 3개 이미지 (4, 5, 6번)
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
                const SizedBox(height: 12),
                // 대표 프로필 이미지 선택 안내
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: AppTheme.primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '선택한 대표 프로필 이미지가 메인으로 사용됩니다',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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
                    labelText: '아이디 (로그인 시 사용)',
                    prefixIcon: Icon(Icons.person),
                    suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                    helperText: '회원가입 시 입력한 아이디 (변경 불가)',
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

                // 성별
                if (_registerData != null) ...[
                  // 회원가입에서 온 경우 - 읽기 전용
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
                              _selectedGender.isEmpty 
                                  ? '성별을 선택해주세요'
                                  : (_selectedGender == '남' ? '남성' : '여성'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedGender.isEmpty ? AppTheme.gray400 : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // 홈에서 온 경우 - 선택 가능
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
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
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedGender = '남';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedGender == '남' 
                                          ? AppTheme.primaryColor 
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '남성',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _selectedGender == '남' 
                                            ? Colors.white 
                                            : Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedGender = '여';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedGender == '여' 
                                          ? AppTheme.primaryColor 
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '여성',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _selectedGender == '여' 
                                            ? Colors.white 
                                            : Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  // 메인 프로필 설정 메서드
  void _setMainProfile(int index) {
    setState(() {
      _mainProfileIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${index + 1}번 이미지가 대표 프로필로 설정되었습니다.')),
    );
  }

  // 이미지 삭제 시 메인 프로필 인덱스 조정
  void _removeImageFromSlot(int index) {
    setState(() {
      _selectedImages[index] = null;
      
      // 메인 프로필 인덱스 조정
      if (_mainProfileIndex == index) {
        // 삭제된 이미지가 메인 프로필이었다면 첫 번째 유효한 이미지로 변경
        int newMainIndex = -1;
        for (int i = 0; i < 6; i++) {
          if (_selectedImages[i] != null) {
            newMainIndex = i;
            break;
          }
        }
        _mainProfileIndex = newMainIndex >= 0 ? newMainIndex : 0;
      }
    });
  }

  // 새로운 그리드 이미지 슬롯 빌더
  Widget _buildImageGridSlot(int index) {
    final hasImage = _selectedImages[index] != null;
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
                      child: _buildImageWidget(_selectedImages[index]!),
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

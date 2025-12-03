import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'dart:io' if (dart.library.html) '';
import 'dart:convert';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';

class ProfileCreateView extends StatefulWidget {
  const ProfileCreateView({super.key});

  @override
  State<ProfileCreateView> createState() => _ProfileCreateViewState();
}

class _ProfileCreateViewState extends State<ProfileCreateView> with WidgetsBindingObserver {
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

  // 초기화 완료 여부 추적
  bool _isInitialized = false;

  // 닉네임 중복 검증 상태
  bool _isCheckingNickname = false;
  String? _nicknameValidationMessage;

  // 다이얼로그 표시 상태 추적 (중복 방지용)
  bool _isRestoringData = false;
  bool _isRestoreDialogShown = false;

  @override
  void initState() {
    super.initState();
    // WidgetsBindingObserver 등록 (앱 상태 변화 감지용)
    WidgetsBinding.instance.addObserver(this);

    // 로그인 상태 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized && !_isRestoringData) {
      // 회원가입 데이터 또는 현재 사용자 정보로 초기화
      final authController = context.read<AuthController>();
      final tempData = authController.tempRegistrationData;

      if (tempData != null) {
        // 회원가입 진행 중 - tempRegistrationData 사용
        _initializeWithRegisterData();
      } else {
        // AuthWrapper에서 온 경우 현재 사용자 정보로 초기화
        _initializeWithCurrentUser();
      }

      // 임시 저장된 프로필 데이터 복원 체크 (초기화 후에 수행)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isRestoringData && !_isRestoreDialogShown) {
          _checkAndRestoreTemporaryData();
        }
      });

      _isInitialized = true; // 중복 실행 방지
    }
  }

  void _initializeWithRegisterData() {
    // 회원가입 tempRegistrationData로 초기화
    final authController = context.read<AuthController>();
    final tempData = authController.tempRegistrationData;

    if (tempData != null) {
      // 이메일을 사용자 ID로 표시
      _userIdController.text = tempData['email'] ?? '';
      _phoneController.text = tempData['phoneNumber'] ?? '';
      _birthDateController.text = tempData['birthDate'] ?? '';
      _selectedGender = tempData['gender'] ?? '';

      // 생년월일을 DateTime으로 변환
      final birthDate = tempData['birthDate'];
      if (birthDate != null && birthDate.length == 8) {
        try {
          _selectedDate = DateTime(
            int.parse(birthDate.substring(0, 4)),
            int.parse(birthDate.substring(4, 6)),
            int.parse(birthDate.substring(6, 8)),
          );
        } catch (e) {
          // 생년월일 파싱 오류는 무시
        }
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
      // Firebase Auth에서 이메일 가져와서 사용자 ID로 사용
      final firebaseUser = authController.firebaseService.currentUser;
      if (firebaseUser != null && firebaseUser.email != null) {
        _userIdController.text = firebaseUser.email!;
      }
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
          // 생년월일 파싱 오류: $e
        }
      }

      setState(() {
        // UI 업데이트
      });
    } else {
      // 현재 사용자 정보가 없는 경우 (프로필이 없는 상태)
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

  // 뒤로가기 처리
  void _handleBackPress() {
    _navigateBack();
  }

  // 실제 뒤로가기 네비게이션
  void _navigateBack() {
    final authController = context.read<AuthController>();
    if (authController.tempRegistrationData != null) {
      // 회원가입에서 온 경우 이전 페이지(회원가입)로 돌아가기
      Navigator.pop(context);
    } else {
      // [수정됨] AuthWrapper에서 온 경우 "나중에 설정하기" 다이얼로그 제거
      // 대신 바로 로그아웃 확인 다이얼로그 표시 (프로필 생성을 취소하려면 로그아웃 해야 함)
      _showLogoutConfirmDialog();
    }
  }

  // 로그아웃 확인 다이얼로그
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃 확인'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              // 다이얼로그 닫기
              Navigator.of(context).pop();

              try {
                final authController = context.read<AuthController>();
                debugPrint('프로필 생성 화면에서 로그아웃 시작');

                // 임시 데이터 정리
                authController.clearTemporaryData();

                // 로그아웃 실행
                await authController.signOut();

                debugPrint('프로필 생성 화면에서 로그아웃 완료');

                // 로그인 화면으로 직접 이동 (AuthWrapper를 거치지 않고)
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                        (route) => false,
                  );
                }
              } catch (e) {
                debugPrint('로그아웃 중 오류: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // WidgetsBindingObserver 해제
    WidgetsBinding.instance.removeObserver(this);

    // 플래그 초기화 (메모리 정리)
    _isRestoringData = false;
    _isRestoreDialogShown = false;

    // 컨트롤러 해제
    _phoneController.dispose();
    _nicknameController.dispose();
    _birthDateController.dispose();
    _heightController.dispose();
    _introductionController.dispose();
    _activityAreaController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  // 로그인 상태 체크
  void _checkLoginStatus() {
    final authController = context.read<AuthController>();
    // 로그인되지 않았고 임시 회원가입 데이터도 없으면 로그인 화면으로
    if (!authController.isLoggedIn && authController.tempRegistrationData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      });
    }
  }

  // 앱 상태 변화 감지 (백그라운드/포그라운드, 중복 방지 추가)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      // 백그라운드로 갈 때 임시 저장 (복원 중이 아닐 때만)
        if (!_isRestoringData && !_isRestoreDialogShown) {
          _saveTemporaryData();
        }
        break;
      case AppLifecycleState.resumed:
      // 포그라운드로 돌아올 때 임시 데이터 복원 체크
      // (이미 복원 중이거나 다이얼로그가 표시된 상태가 아닐 때만)
        if (!_isRestoringData && !_isRestoreDialogShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isRestoringData && !_isRestoreDialogShown) {
              _checkAndRestoreTemporaryData();
            }
          });
        }
        break;
      default:
        break;
    }
  }

  // 임시 데이터 저장 (이미지 포함)
  Future<void> _saveTemporaryData() async {
    try {
      // 입력된 데이터가 있는지 확인
      final hasInputData = _nicknameController.text.isNotEmpty ||
          _introductionController.text.isNotEmpty ||
          _heightController.text.isNotEmpty ||
          _activityAreaController.text.isNotEmpty ||
          _selectedImages.any((image) => image != null);

      if (!hasInputData) return;

      // 이미지들을 Base64로 인코딩
      List<String> imageBytes = [];
      for (final image in _selectedImages) {
        if (image != null) {
          try {
            final bytes = await image.readAsBytes();
            final base64String = base64Encode(bytes);
            imageBytes.add(base64String);
          } catch (e) {
            imageBytes.add(''); // 실패한 경우 빈 문자열
          }
        } else {
          imageBytes.add(''); // null인 경우 빈 문자열
        }
      }

      final authController = context.read<AuthController>();
      authController.saveTemporaryProfileData(
        nickname: _nicknameController.text.trim(),
        introduction: _introductionController.text.trim(),
        height: _heightController.text.trim(),
        activityArea: _activityAreaController.text.trim(),
        profileImageBytes: imageBytes,
        mainProfileIndex: _mainProfileIndex,
      );
    } catch (e) {
      // 임시 저장 실패해도 앱 동작에 영향 없도록
      debugPrint('임시 데이터 저장 실패: $e');
    }
  }

  // 임시 데이터 복원 체크 (중복 방지 로직 추가)
  void _checkAndRestoreTemporaryData() {
    // 이미 복원 중이거나 다이얼로그가 표시되어 있으면 중단
    if (_isRestoringData || _isRestoreDialogShown) {
      return;
    }

    final authController = context.read<AuthController>();
    final tempProfileData = authController.tempProfileData;

    if (tempProfileData != null) {
      // 저장된 시간 확인 (24시간 이내만 유효)
      final savedAtStr = tempProfileData['savedAt'] as String?;
      if (savedAtStr != null) {
        final savedAt = DateTime.tryParse(savedAtStr);
        if (savedAt != null &&
            DateTime.now().difference(savedAt).inHours < 24) {
          // 24시간 이내 데이터면 복원 다이얼로그 표시 - 제거됨 (이전 요청에 의해)
          // _isRestoreDialogShown = true;
          // WidgetsBinding.instance.addPostFrameCallback((_) {
          //   if (mounted && !_isRestoringData) {
          //     _showRestoreConfirmDialog(tempProfileData, authController);
          //   }
          // });
        } else {
          // 24시간 지났으면 데이터 정리
          authController.clearTemporaryProfileData();
        }
      }
    }
  }

  // 실제 데이터 복원 수행 (이미지 포함, 플래그 관리 추가)
  Future<void> _performDataRestoreWithImages(
      Map<String, dynamic> tempProfileData,
      AuthController authController) async {
    // 복원 시작 플래그 설정
    _isRestoringData = true;

    try {
      setState(() {
        _nicknameController.text = tempProfileData['nickname'] ?? '';
        _introductionController.text = tempProfileData['introduction'] ?? '';
        _heightController.text = tempProfileData['height'] ?? '';
        _activityAreaController.text = tempProfileData['activityArea'] ?? '';
        _mainProfileIndex = tempProfileData['mainProfileIndex'] ?? 0;
      });

      // 이미지 복원
      final imageBytesList = tempProfileData['profileImageBytes'] as List<dynamic>?;
      if (imageBytesList != null) {
        for (int i = 0; i < imageBytesList.length && i < 6; i++) {
          final base64String = imageBytesList[i] as String?;
          if (base64String != null && base64String.isNotEmpty) {
            try {
              final bytes = base64Decode(base64String);
              final xFile = XFile.fromData(
                bytes,
                name: 'restored_image_$i.jpg',
                mimeType: 'image/jpeg',
              );
              setState(() {
                _selectedImages[i] = xFile;
              });
            } catch (e) {
              debugPrint('이미지 복원 실패 (인덱스 $i): $e');
            }
          }
        }
      }

      // 복원 후 임시 데이터 정리
      authController.clearTemporaryProfileData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이전 입력 정보를 복원했습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('데이터 복원 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터 복원 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 복원 완료 플래그 리셋
      _isRestoringData = false;
    }
  }

  // 닉네임 중복 검증 (실시간)
  Future<void> _checkNicknameDuplicate(String nickname) async {
    if (nickname.isEmpty || nickname.length < 2) {
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
      final authController = context.read<AuthController>();
      final isDuplicate = await authController.isNicknameDuplicate(nickname);

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
        // 이미지 선택 후 즉시 검증
        final validatedFile = await _validateAndCompressImageFile(image);
        if (validatedFile != null) {
          setState(() {
            // 해당 인덱스에 검증된 이미지 저장
            _selectedImages[index] = validatedFile;
          });
        }
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // 닉네임 중복 검증
    if (_nicknameValidationMessage == '이미 사용 중인 닉네임입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 닉네임입니다. 다른 닉네임을 사용해주세요.')),
      );
      return;
    }

    // [UPDATED] 이미지 최소 1장 필수 체크
    final hasImages = _selectedImages.any((image) => image != null);
    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진을 최소 1장 등록해주세요.')),
      );
      return;
    }

    final authController = context.read<AuthController>();

    // 실제 Firebase 계정 생성과 프로필 완성 (이미지 포함)
    List<XFile> sortedImages = [];

    // 선택된 이미지가 있는지 확인
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
    if (authController.tempRegistrationData != null) {
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

            // 파일 유효성 검사 및 압축
            final validatedFile = await _validateAndCompressImageFile(file);
            if (validatedFile == null) {
              continue; // 유효하지 않은 파일은 스킵
            }

            final fileName = '${currentUser.uid}_profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

            // Firebase Storage에 업로드 (재시도 포함)
            final downloadUrl = await _uploadImageWithRetry(
                validatedFile,
                'profile_images/${currentUser.uid}/$fileName',
                maxRetries: 3
            );

            if (downloadUrl != null) {
              imageUrls.add(downloadUrl);
            }
          }
        } catch (e) {
          // 이미지 업로드 실패해도 계속 진행
          authController.setError('이미지 업로드에 실패했습니다. 프로필은 생성되었으니 나중에 다시 업로드해주세요.');
        }
      }

      await authController.createCompleteUserProfile(
        currentUser.uid,
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
      authController.setError('프로필 생성에 실패했습니다: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 시스템 뒤로가기 버튼 처리를 커스터마이즈
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('프로필 생성'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPress,
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
                      labelText: '아이디 (이메일과 동일)',
                      prefixIcon: Icon(Icons.person),
                      suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                      helperText: '이메일 주소와 동일 (변경 불가)',
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
                  Builder(
                    builder: (context) {
                      final authController = context.read<AuthController>();
                      if (authController.tempRegistrationData != null) {
                        // 회원가입에서 온 경우 - 읽기 전용
                        return Container(
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
                        );
                      } else {
                        // 홈에서 온 경우 - 선택 가능
                        return Container(
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
                        );
                      }
                    },
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          labelText: '닉네임',
                          prefixIcon: const Icon(Icons.badge),
                          suffixIcon: _isCheckingNickname
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : null,
                          helperText: '10자 이내',
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
                      if (value.trim().length < 5) {
                        return '소개글은 5자 이상 작성해주세요.';
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

  // 이미지 파일 유효성 검사 및 압축
  Future<XFile?> _validateAndCompressImageFile(XFile file) async {
    try {
      // 파일 형식 검사 (확장자와 MIME 타입 모두 확인)
      final fileName = file.name.toLowerCase();
      final mimeType = file.mimeType ?? '';

      // 지원하는 이미지 확장자
      final supportedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
      final hasValidExtension = supportedExtensions.any((ext) => fileName.endsWith(ext));

      // MIME 타입 확인 (null이거나 비어있을 경우 확장자로 판단)
      final hasValidMimeType = mimeType.isEmpty || mimeType.startsWith('image/');

      if (!hasValidExtension || !hasValidMimeType) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '이미지 파일만 업로드 가능합니다.\n지원 형식: JPG, PNG, GIF, BMP, WebP\n선택된 파일: ${file.name}${mimeType.isNotEmpty ? ' ($mimeType)' : ''}'
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return null;
      }

      // 파일 크기 검사
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('빈 파일은 업로드할 수 없습니다.')),
          );
        }
        return null;
      }

      // 바이트 헤더로 이미지 파일 검증 (추가 안전장치)
      if (!_isValidImageByHeader(bytes)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('올바른 이미지 파일이 아닙니다. 파일이 손상되었을 수 있습니다.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      // 5MB 이하면 원본 파일 반환
      if (bytes.length <= 5 * 1024 * 1024) {
        return file;
      }

      // 5MB 초과 시 압축 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '파일 크기가 5MB를 초과합니다 (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). 자동으로 압축합니다.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 압축에 실패했습니다.')),
          );
        }
        return null;
      }

      // 압축된 파일을 임시 XFile로 생성
      final compressedFile = XFile.fromData(
        compressedBytes,
        name: file.name,
        mimeType: 'image/jpeg', // 압축 후 JPEG 형식으로 통일
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '이미지 압축 완료: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)}MB',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      return compressedFile;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 처리 중 오류가 발생했습니다.')),
        );
      }
      return null;
    }
  }

  // 이미지 압축 함수
  Future<Uint8List?> _compressImage(Uint8List originalBytes) async {
    try {
      // 이미지 디코딩
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        return null;
      }

      const targetSize = 5 * 1024 * 1024; // 5MB
      int quality = 85; // 초기 품질
      int maxWidth = originalImage.width;
      int maxHeight = originalImage.height;

      Uint8List? compressedBytes;

      // 품질을 점진적으로 낮추면서 압축
      while (quality >= 20) {
        // 크기가 너무 크면 이미지 크기도 줄임
        if (compressedBytes != null && compressedBytes.length > targetSize &&
            (maxWidth > 1000 || maxHeight > 1000)) {
          maxWidth = (maxWidth * 0.8).round();
          maxHeight = (maxHeight * 0.8).round();
        }

        // 이미지 리사이즈 (필요한 경우)
        img.Image resizedImage = originalImage;
        if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
          resizedImage = img.copyResize(
            originalImage,
            width: maxWidth,
            height: maxHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        // JPEG로 압축
        compressedBytes = Uint8List.fromList(
            img.encodeJpg(resizedImage, quality: quality)
        );

        // 목표 크기 이하이면 완료
        if (compressedBytes.length <= targetSize) {
          return compressedBytes;
        }

        // 품질을 10씩 낮춤
        quality -= 10;
      }

      // 최종적으로도 크기가 크면 크기를 더 줄임
      if (compressedBytes != null && compressedBytes.length > targetSize) {
        // 강제로 크기를 줄여서 재시도
        maxWidth = (originalImage.width * 0.6).round();
        maxHeight = (originalImage.height * 0.6).round();

        final finalImage = img.copyResize(
          originalImage,
          width: maxWidth,
          height: maxHeight,
          interpolation: img.Interpolation.linear,
        );

        compressedBytes = Uint8List.fromList(
            img.encodeJpg(finalImage, quality: 60)
        );
      }

      return compressedBytes;
    } catch (e) {
      return null;
    }
  }

  // 바이트 헤더로 이미지 파일 여부 확인
  bool _isValidImageByHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // JPEG
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return true;
    }

    // PNG
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A &&
        bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return true;
    }

    // GIF
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
        bytes[3] == 0x38 && (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61) {
      return true;
    }

    // BMP
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }

    // WebP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }

    // TIFF
    if (bytes.length >= 4 &&
        ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
            (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A))) {
      return true;
    }

    return false;
  }

  // 기존 유효성 검사 함수도 유지 (하위 호환성)
  Future<bool> _validateImageFile(XFile file) async {
    final validatedFile = await _validateAndCompressImageFile(file);
    return validatedFile != null;
  }

  // 재시도 메커니즘이 포함된 이미지 업로드
  Future<String?> _uploadImageWithRetry(
      XFile file,
      String storagePath,
      {int maxRetries = 3}
      ) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final ref = FirebaseStorage.instance.ref().child(storagePath);

        // 메타데이터 설정
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
          customMetadata: {
            'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            'uploadTimestamp': DateTime.now().toIso8601String(),
          },
        );

        // 플랫폼별 업로드 처리
        late UploadTask uploadTask;
        if (kIsWeb) {
          // 웹에서는 XFile에서 bytes 사용
          final bytes = await file.readAsBytes();
          uploadTask = ref.putData(bytes, metadata);
        } else {
          // 모바일에서는 XFile을 File로 변환
          final ioFile = File(file.path);

          // 파일 존재 여부 확인
          if (!await ioFile.exists()) {
            // 바이트 데이터로 대체 시도
            final bytes = await file.readAsBytes();
            uploadTask = ref.putData(bytes, metadata);
          } else {
            uploadTask = ref.putFile(ioFile, metadata);
          }
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        return downloadUrl;

      } catch (e) {
        if (attempt == maxRetries) {
          // 최종 실패
          return null;
        }

        // 재시도 전 잠시 대기 (지수 백오프)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    return null;
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
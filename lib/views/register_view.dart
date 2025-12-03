import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedGender = '';

  // 이메일 중복 검증 상태
  bool _isCheckingEmail = false;
  String? _emailValidationMessage;
  Timer? _emailDebounceTimer;

  // [ADDED] 전화번호 중복 검증 상태
  bool _isCheckingPhone = false;
  String? _phoneValidationMessage;
  Timer? _phoneDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreTemporaryData();
    });
  }

  @override
  void dispose() {
    _emailDebounceTimer?.cancel();
    _phoneDebounceTimer?.cancel(); // [ADDED] 타이머 해제
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  void _restoreTemporaryData() {
    final authController = context.read<AuthController>();
    final tempData = authController.tempRegistrationData;

    if (tempData != null) {
      setState(() {
        _emailController.text = tempData['email'] ?? '';
        _phoneController.text = tempData['phoneNumber'] ?? '';
        _birthDateController.text = tempData['birthDate'] ?? '';
        _selectedGender = tempData['gender'] ?? '';
      });
    }
  }

  // 이메일 중복 검증
  Future<void> _checkEmailDuplicate(String email) async {
    if (email.isEmpty || !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      if (mounted && _emailValidationMessage != null) {
        setState(() {
          _emailValidationMessage = null;
          _isCheckingEmail = false;
        });
      }
      return;
    }

    if (mounted && !_isCheckingEmail) {
      setState(() {
        _isCheckingEmail = true;
        _emailValidationMessage = null;
      });
    }

    try {
      final authController = context.read<AuthController>();
      final isDuplicate = await authController.isEmailDuplicate(email);

      if (mounted) {
        final newMessage = isDuplicate ? '이미 사용 중인 이메일입니다.' : '사용 가능한 이메일입니다.';
        setState(() {
          _isCheckingEmail = false;
          _emailValidationMessage = newMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          _emailValidationMessage = '이메일 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  // [ADDED] 전화번호 중복 검증
  Future<void> _checkPhoneNumberDuplicate(String phoneNumber) async {
    if (phoneNumber.isEmpty || !RegExp(r'^010\d{8}$').hasMatch(phoneNumber)) {
      if (mounted && _phoneValidationMessage != null) {
        setState(() {
          _phoneValidationMessage = null;
          _isCheckingPhone = false;
        });
      }
      return;
    }

    if (mounted && !_isCheckingPhone) {
      setState(() {
        _isCheckingPhone = true;
        _phoneValidationMessage = null;
      });
    }

    try {
      final authController = context.read<AuthController>();
      final isDuplicate = await authController.isPhoneNumberDuplicate(phoneNumber);

      if (mounted) {
        final newMessage = isDuplicate ? '이미 사용 중인 전화번호입니다.' : '사용 가능한 전화번호입니다.';
        setState(() {
          _isCheckingPhone = false;
          _phoneValidationMessage = newMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingPhone = false;
          _phoneValidationMessage = '전화번호 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  Future<void> _register() async {
    // 1. 폼 유효성 검사 (빈칸, 형식 체크)
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요.')),
      );
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final birthDate = _birthDateController.text.trim();

    if (email.isEmpty || password.isEmpty ||
        phoneNumber.isEmpty || birthDate.isEmpty || _selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필수 정보를 입력해주세요.')),
      );
      return;
    }

    final authController = context.read<AuthController>();

    // 2. 중복 검사 확인 (UI상 에러 메시지가 떠있는지 확인)
    if (_emailValidationMessage == '이미 사용 중인 이메일입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 이메일입니다. 다른 이메일을 사용해주세요.')),
      );
      return;
    }

    if (_phoneValidationMessage == '이미 사용 중인 전화번호입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 전화번호입니다. 다른 번호를 사용해주세요.')),
      );
      return;
    }

    // 에러 상태 초기화
    authController.clearError();

    // 3. [핵심 변경] 임시 저장이 아닌 '즉시 가입' 시도
    // AuthController에 새로 추가한 register 함수를 호출합니다.
    final success = await authController.register(
      email: email,
      password: password,
      phoneNumber: phoneNumber,
      birthDate: birthDate,
      gender: _selectedGender,
    );

    // 4. 가입 성공 여부에 따른 처리
    if (success && mounted) {
      // 성공 시: 홈 화면으로 이동 (이전 화면 기록 모두 삭제)
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입되었습니다! 우선 프로필을 완성해주세요.')),
      );
    } else if (mounted && authController.errorMessage != null) {
      // 실패 시: 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authController.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 안내 메시지
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '그룹팅에 오신 것을 환영합니다!\n이메일로 간편하게 가입해보세요.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '자물쇠 표시된 정보는 가입 후 변경할 수 없습니다',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 이메일 입력
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '이메일',
                          prefixIcon: const Icon(Icons.email),
                          suffixIcon: _isCheckingEmail
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(14.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                              : const Icon(Icons.lock, color: AppTheme.textSecondary),
                          helperText: '로그인 및 비밀번호 찾기에 사용할 이메일',
                        ),
                        onChanged: (value) {
                          _emailDebounceTimer?.cancel();
                          _emailDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                            if (mounted && _emailController.text == value && value.isNotEmpty) {
                              _checkEmailDuplicate(value);
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '이메일을 입력해주세요.';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                            return '올바른 이메일 형식을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      if (_emailValidationMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            _emailValidationMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _emailValidationMessage == '사용 가능한 이메일입니다.'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력 (생략)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: const Icon(Icons.lock),
                      helperText: '8자 이상',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }
                      if (value.length < 8) {
                        return '비밀번호는 8자 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 확인 (생략)
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: '비밀번호 확인',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 다시 입력해주세요.';
                      }
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않습니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // [UPDATED] 전화번호 입력
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          labelText: '전화번호',
                          prefixIcon: const Icon(Icons.phone),
                          // 로딩 중이면 스피너, 아니면 자물쇠 아이콘
                          suffixIcon: _isCheckingPhone
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(14.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                              : const Icon(Icons.lock, color: AppTheme.textSecondary),
                          helperText: '11자리 숫자만 입력 (예: 01012345678)',
                        ),
                        // [ADDED] 변경 시 중복 확인 트리거
                        onChanged: (value) {
                          _phoneDebounceTimer?.cancel();
                          _phoneDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                            if (mounted && _phoneController.text == value && value.isNotEmpty) {
                              _checkPhoneNumberDuplicate(value);
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '전화번호를 입력해주세요.';
                          }
                          if (value.length != 11) {
                            return '전화번호는 11자리여야 합니다.';
                          }
                          if (!RegExp(r'^010\d{8}$').hasMatch(value)) {
                            return '010으로 시작하는 11자리 번호를 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      // [ADDED] 검증 메시지 표시
                      if (_phoneValidationMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            _phoneValidationMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _phoneValidationMessage == '사용 가능한 전화번호입니다.'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 생년월일 입력
                  TextFormField(
                    controller: _birthDateController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: '생년월일',
                      prefixIcon: Icon(Icons.calendar_today),
                      suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                      helperText: '8자리 숫자 (예: 19950315)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '생년월일을 입력해주세요.';
                      }
                      if (value.length != 8) {
                        return '생년월일은 8자리여야 합니다.';
                      }

                      try {
                        final year = int.parse(value.substring(0, 4));
                        final month = int.parse(value.substring(4, 6));
                        final day = int.parse(value.substring(6, 8));

                        final currentYear = DateTime.now().year;
                        if (year < 1900 || year > currentYear) {
                          return '유효한 연도를 입력해주세요.';
                        }
                        if (month < 1 || month > 12) {
                          return '유효한 월을 입력해주세요.';
                        }
                        if (day < 1 || day > 31) {
                          return '유효한 일을 입력해주세요.';
                        }

                        DateTime(year, month, day);
                      } catch (e) {
                        return '유효한 날짜를 입력해주세요.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 성별 선택 (자물쇠 표시)
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
                              const Spacer(),
                              const Icon(Icons.lock, color: AppTheme.textSecondary),
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

                  const SizedBox(height: 32),

                  // 회원가입 버튼
                  Consumer<AuthController>(
                    builder: (context, authController, _) {
                      if (authController.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),

                  // 에러 메시지 표시
                  Consumer<AuthController>(
                    builder: (context, authController, _) {
                      if (authController.errorMessage != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authController.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 16),

                  // 로그인 버튼
                  TextButton(
                    onPressed: () {
                      final authController = context.read<AuthController>();
                      authController.clearError();
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text('이미 계정이 있으신가요? 로그인하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
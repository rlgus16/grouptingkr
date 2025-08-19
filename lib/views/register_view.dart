import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedGender = '';
  
  // 중복 검증 상태
  bool _isCheckingEmail = false;
  bool _isCheckingUserId = false;
  String? _emailValidationMessage;
  String? _userIdValidationMessage;

  @override
  void initState() {
    super.initState();
    // 임시 저장된 회원가입 데이터가 있으면 복원
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreTemporaryData();
    });
  }

  @override
  void dispose() {
    _idController.dispose();
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
      // print('임시 저장된 회원가입 데이터 복원: $tempData');
      setState(() {
        _idController.text = tempData['userId'] ?? '';
        _emailController.text = tempData['email'] ?? '';
        _phoneController.text = tempData['phoneNumber'] ?? '';
        _birthDateController.text = tempData['birthDate'] ?? '';
        _selectedGender = tempData['gender'] ?? '';
        // 비밀번호는 보안상 복원하지 않음
      });
    }
  }

  // 이메일 중복 검증 (실시간)
  Future<void> _checkEmailDuplicate(String email) async {
    if (email.isEmpty || !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() {
        _emailValidationMessage = null;
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailValidationMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final isDuplicate = await authController.isEmailDuplicate(email);
      
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          _emailValidationMessage = isDuplicate ? '이미 사용 중인 이메일입니다.' : '사용 가능한 이메일입니다.';
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

  // 아이디 중복 검증 (실시간)
  Future<void> _checkUserIdDuplicate(String userId) async {
    if (userId.isEmpty || userId.length < 4) {
      setState(() {
        _userIdValidationMessage = null;
        _isCheckingUserId = false;
      });
      return;
    }

    setState(() {
      _isCheckingUserId = true;
      _userIdValidationMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final isDuplicate = await authController.isUserIdDuplicate(userId);
      
      if (mounted) {
        setState(() {
          _isCheckingUserId = false;
          _userIdValidationMessage = isDuplicate ? '이미 사용 중인 아이디입니다.' : '사용 가능한 아이디입니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUserId = false;
          _userIdValidationMessage = '아이디 확인 중 오류가 발생했습니다.';
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요.')),
      );
      return;
    }

    // 필수 데이터 검증 강화
    final userId = _idController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final birthDate = _birthDateController.text.trim();
    
    if (userId.isEmpty || email.isEmpty || password.isEmpty || 
        phoneNumber.isEmpty || birthDate.isEmpty || _selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필수 정보를 입력해주세요.')),
      );
      return;
    }

    // 실시간 중복 검증이 완료되지 않았다면 강제로 재검증
    if (_emailValidationMessage == null && email.isNotEmpty) {
      // 이메일 중복 재검증
      final authController = context.read<AuthController>();
      final isEmailDuplicate = await authController.isEmailDuplicate(email);
      if (isEmailDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 이메일입니다. 다른 이메일을 사용해주세요.')),
        );
        return;
      }
    }

    if (_userIdValidationMessage == null && userId.isNotEmpty) {
      // 아이디 중복 재검증
      final authController = context.read<AuthController>();
      final isUserIdDuplicate = await authController.isUserIdDuplicate(userId);
      if (isUserIdDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 아이디입니다. 다른 아이디를 사용해주세요.')),
        );
        return;
      }
    }

    // 중복 검증 확인
    if (_emailValidationMessage == '이미 사용 중인 이메일입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 이메일입니다. 다른 이메일을 사용해주세요.')),
      );
      return;
    }

    if (_userIdValidationMessage == '이미 사용 중인 아이디입니다.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 아이디입니다. 다른 아이디를 사용해주세요.')),
      );
      return;
    }

    final authController = context.read<AuthController>();
    
    // 이전 에러 메시지 클리어
    authController.clearError();

    try {
      // 회원가입 데이터를 임시 저장 (Firebase 계정은 생성하지 않음)
      authController.saveTemporaryRegistrationData(
        userId: userId,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: _selectedGender,
      );

      if (mounted) {
        // 프로필 생성 화면으로 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/profile-create',
          (route) => false,
          arguments: {
            'userId': userId,
            'phoneNumber': phoneNumber,
            'birthDate': birthDate,
            'gender': _selectedGender,
          },
        );
      }
    } catch (e) {
      debugPrint('회원가입 준비 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 준비 중 오류가 발생했습니다.')),
        );
      }
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
                          '그룹팅에 오신 것을 환영합니다!\n기본 정보를 입력해주세요.',
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

                  // 아이디 입력 (자물쇠 표시)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _idController,
                        decoration: InputDecoration(
                          labelText: '아이디',
                          prefixIcon: const Icon(Icons.person),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isCheckingUserId)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              const Icon(Icons.lock, color: AppTheme.textSecondary),
                            ],
                          ),
                          helperText: '4자 이상, 영문과 숫자만 사용 가능 (로그인 시 사용)',
                        ),
                        onChanged: (value) {
                          // 디바운싱을 위해 타이머 사용
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_idController.text == value) {
                              _checkUserIdDuplicate(value);
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '아이디를 입력해주세요.';
                          }
                          if (value.length < 4) {
                            return '아이디는 4자 이상이어야 합니다.';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                            return '영문과 숫자만 사용할 수 있습니다.';
                          }
                          return null;
                        },
                      ),
                      if (_userIdValidationMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            _userIdValidationMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _userIdValidationMessage == '사용 가능한 아이디입니다.'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 이메일 입력 (자물쇠 표시)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '이메일',
                          prefixIcon: const Icon(Icons.email),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isCheckingEmail)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              const Icon(Icons.lock, color: AppTheme.textSecondary),
                            ],
                          ),
                          helperText: '비밀번호 찾기 등에 사용할 이메일',
                        ),
                        onChanged: (value) {
                          // 디바운싱을 위해 타이머 사용
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (_emailController.text == value) {
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

                  // 비밀번호 입력
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

                  // 비밀번호 확인
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

                  // 전화번호 입력 (자물쇠 표시)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: '전화번호',
                      prefixIcon: Icon(Icons.phone),
                      suffixIcon: Icon(Icons.lock, color: AppTheme.textSecondary),
                      helperText: '11자리 숫자만 입력 (예: 01012345678)',
                    ),
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
                  const SizedBox(height: 16),

                  // 생년월일 입력 (자물쇠 표시)
                  TextFormField(
                    controller: _birthDateController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
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
                      
                      // 날짜 유효성 검사
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
                        
                        // 실제 날짜 생성해서 유효성 검사
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
                      // 로그인 페이지로 이동할 때 오류 메시지 클리어
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

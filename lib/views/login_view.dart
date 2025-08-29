import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();

    // 이전 에러 메시지 클리어
    authController.clearError();

    try {
      // 이메일과 비밀번호로 로그인
      await authController.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 로그인 성공 시 처리
      if (mounted && authController.isLoggedIn) {
        authController.clearError();
        debugPrint('✅ 로그인 성공 - 홈 화면으로 이동');
        
        // 홈 화면으로 네비게이션 (기존 로그인 화면 제거)
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/home', 
          (route) => false,
        );
      } else if (mounted && authController.errorMessage == null) {
        // 로그인은 완료되었지만 isLoggedIn이 false인 경우 (예: 복구 중)
        // 잠시 대기 후 상태 재확인
        debugPrint('⏳ 로그인 처리 중 - 상태 재확인');
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted && authController.isLoggedIn) {
          debugPrint('✅ 지연된 로그인 성공 - 홈 화면으로 이동');
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/home', 
            (route) => false,
          );
        }
      }
    } catch (e) {
      // 예외 처리는 AuthController에서 하지만, 추가 안전장치
      debugPrint('로그인 중 예외 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                  // 로고/타이틀
                  const Text(
                    '그룹팅',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '친구들과 함께하는 소개팅',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // 이메일 입력
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      prefixIcon: Icon(Icons.email),
                      hintText: 'example@email.com',
                    ),
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
                  const SizedBox(height: 16),

                  // 비밀번호 입력
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: const Icon(Icons.lock),
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
                      if (value.length < 6) {
                        return '비밀번호는 6자 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 로그인 버튼
                  Consumer<AuthController>(
                    builder: (context, authController, _) {
                      if (authController.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          '로그인',
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

                  // 회원가입 버튼
                  TextButton(
                    onPressed: () {
                      // 회원가입 페이지로 이동할 때 오류 메시지 클리어
                      final authController = context.read<AuthController>();
                      authController.clearError();
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text('회원가입'),
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

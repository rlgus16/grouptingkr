import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
              (route) => false,
        );
      } else if (mounted && authController.errorMessage == null) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted && authController.isLoggedIn) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
                (route) => false,
          );
        }
      }
    } catch (e) {
      // 로그인 중 예외
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // 1. 로고 및 타이틀 섹션
                  _buildHeaderSection(),
                  const SizedBox(height: 48),

                  // 2. 입력 폼 섹션
                  _buildInputSection(),
                  const SizedBox(height: 24),

                  // 3. 에러 메시지
                  _buildErrorMessage(),
                  const SizedBox(height: 24),

                  // 4. 버튼 및 하단 링크 섹션
                  _buildBottomSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          '그룹팅',
          style: GoogleFonts.gugi(
            textStyle: const TextStyle(
              fontSize: 42,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          '친구들과 함께 즐기는\n새로운 만남의 시작',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: '이메일',
            hintText: 'example@email.com',
            prefixIcon: const Icon(Icons.email_outlined),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            filled: true,
            fillColor: AppTheme.gray50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.errorColor),
            ),
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
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: '비밀번호',
            hintText: '비밀번호를 입력해주세요',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.gray500,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            filled: true,
            fillColor: AppTheme.gray50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.errorColor),
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
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        if (authController.errorMessage != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorColor.withValues(alpha:0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authController.errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        Consumer<AuthController>(
          builder: (context, authController, _) {
            if (authController.isLoading) {
              return const SizedBox(
                height: 56,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            }

            return SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '계정이 없으신가요?',
              style: TextStyle(
                color: AppTheme.gray600,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                final authController = context.read<AuthController>();
                authController.clearError();
                Navigator.pushNamed(context, '/register');
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                '회원가입',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
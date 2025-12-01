import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // [추가] App Check 패키지
import 'package:flutter/foundation.dart'; // [추가] kReleaseMode 확인용

import 'controllers/auth_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/group_controller.dart';
import 'controllers/chat_controller.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/register_view.dart';
import 'views/profile_create_view.dart';
import 'utils/app_theme.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';

// 전역 네비게이터 키
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase 초기화 (플랫폼별 설정 사용)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // [추가] App Check 활성화 (배포/개발 환경 분리 적용)
    await FirebaseAppCheck.instance.activate(
      // Android: 배포(Release) 시 Play Integrity, 개발(Debug) 시 Debug Provider 사용
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,

      // iOS: 배포(Release) 시 App Attest, 개발(Debug) 시 Debug Provider 사용
      appleProvider: kReleaseMode
          ? AppleProvider.appAttest
          : AppleProvider.debug,

      // Web: 필요 시 ReCaptcha v3 키 입력 (미사용 시 주석 처리)
      // webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );

    // FCM 백그라운드 메시지 핸들러 설정
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    debugPrint('Firebase 및 App Check 초기화 성공');
  } catch (e) {
    debugPrint('Firebase 초기화 오류: $e');
  }

  runApp(const MyApp());
}

// FCM 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 메시지 처리 로직
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => GroupController()),
        ChangeNotifierProvider(create: (_) => ChatController()),
      ],
      child: MaterialApp(
        title: '그룹팅',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ko', 'KR'),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginView(),
          '/register': (context) => const RegisterView(),
          '/profile-create': (context) => const ProfileCreateView(),
          '/home': (context) => const HomeView(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _wasLoggedIn = false;
  GroupController? _groupController;
  ChatController? _chatController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  void _initializeControllers() {
    if (_controllersInitialized) return;

    try {
      final authController = context.read<AuthController>();
      _groupController = context.read<GroupController>();
      _chatController = context.read<ChatController>();

      authController.onSignOutCallback = () {
        try {
          _groupController?.onSignOut();
          _chatController?.onSignOut();
          FCMService().clearToken();
          if (mounted) setState(() {});
        } catch (e) {
          // Ignore
        }
      };

      authController.initialize();
      _wasLoggedIn = authController.isLoggedIn;
      FCMService().initialize();

      _controllersInitialized = true;
    } catch (e) {
      debugPrint('컨트롤러 초기화 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        if (!authController.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_wasLoggedIn && !authController.isLoggedIn) {
          _controllersInitialized = false;
          _groupController = null;
          _chatController = null;
          _wasLoggedIn = false;
          return const LoginView();
        }

        if (!_wasLoggedIn && authController.isLoggedIn && !_controllersInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeControllers();
          });
        }

        final previousWasLoggedIn = _wasLoggedIn;
        _wasLoggedIn = authController.isLoggedIn;

        if (previousWasLoggedIn && !authController.isLoggedIn) {
          _controllersInitialized = false;
          _groupController = null;
          _chatController = null;
          return const LoginView();
        }

        if (authController.tempRegistrationData != null) {
          return const ProfileCreateView();
        }

        if (!authController.isLoggedIn) {
          return const LoginView();
        }

        final firebaseUser = authController.firebaseService.currentUser;
        if (firebaseUser == null) {
          return const LoginView();
        }

        if (authController.currentUserModel == null) {
          return const LoginView();
        }

        if (!authController.currentUserModel!.isProfileComplete) {
          final user = authController.currentUserModel!;
          if (user.phoneNumber.isNotEmpty &&
              user.gender.isNotEmpty &&
              user.birthDate.isNotEmpty) {
            return const HomeView();
          } else {
            return const ProfileCreateView();
          }
        }

        return const HomeView();
      },
    );
  }
}
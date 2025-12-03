import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'controllers/auth_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/group_controller.dart';
import 'controllers/chat_controller.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/register_view.dart';
// ProfileCreateView import 삭제됨
import 'utils/app_theme.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';

// 전역 네비게이터 키
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check 활성화
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: kReleaseMode
          ? AppleProvider.appAttest
          : AppleProvider.debug,
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
          // '/profile-create': (context) => const ProfileCreateView(), // 삭제됨
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

        // 로그인 상태가 해제된 경우
        if (_wasLoggedIn && !authController.isLoggedIn) {
          _controllersInitialized = false;
          _groupController = null;
          _chatController = null;
          _wasLoggedIn = false;
          return const LoginView();
        }

        // 로그인 상태로 변경된 경우 (초기화 필요)
        if (!_wasLoggedIn && authController.isLoggedIn && !_controllersInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeControllers();
          });
        }

        final previousWasLoggedIn = _wasLoggedIn;
        _wasLoggedIn = authController.isLoggedIn;

        // 로그아웃 감지 (이중 체크)
        if (previousWasLoggedIn && !authController.isLoggedIn) {
          _controllersInitialized = false;
          _groupController = null;
          _chatController = null;
          return const LoginView();
        }

        // 로그인하지 않은 상태
        if (!authController.isLoggedIn) {
          return const LoginView();
        }

        final firebaseUser = authController.firebaseService.currentUser;
        if (firebaseUser == null) {
          return const LoginView();
        }

        // 사용자 데이터 로딩 중이거나 없는 경우 (일단 홈으로 보내거나 로딩 표시)
        // HomeView 내부에서 데이터 없음을 처리하거나 재로딩하므로 HomeView로 보냄
        if (authController.currentUserModel == null) {
          // 데이터 로딩을 기다리는 대신 HomeView로 보내서 처리
          return const HomeView();
        }

        // 프로필 미완성 상태라도 HomeView로 보내서 '프로필 완성하기' 카드를 띄움
        return const HomeView();
      },
    );
  }
}
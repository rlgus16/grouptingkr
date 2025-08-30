import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

    // FCM 백그라운드 메시지 핸들러 설정
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    debugPrint('Firebase 초기화 성공');
  } catch (e) {
    debugPrint('Firebase 초기화 오류: $e');
  }

  runApp(const MyApp());
}

// FCM 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 FCM 메시지 수신: ${message.notification?.title}
  // 메시지 내용: ${message.notification?.body}
  // 데이터: ${message.data}
  
  // 백그라운드에서는 시스템이 자동으로 알림을 표시합니다.
  // 추가적인 데이터 처리가 필요한 경우에만 여기서 처리
}

// 추후 앱 명칭 및 라우팅 위치, 상태관리 전환 분리 권장.
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
        navigatorKey: navigatorKey, // 전역 네비게이터 키 설정
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'), // 한국어
          Locale('en', 'US'), // 영어
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

// 인증 상태에 따라 화면 전환
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _wasLoggedIn = false;
  
  // 컨트롤러 인스턴스를 미리 저장 -> 조금 더 깔끔한 로그아웃을 위한 정리 코드.
  GroupController? _groupController;
  ChatController? _chatController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    // AuthController 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  void _initializeControllers() {
    if (_controllersInitialized) return;
    
    try {
      final authController = context.read<AuthController>();
      
      // 컨트롤러 인스턴스 저장
      _groupController = context.read<GroupController>();
      _chatController = context.read<ChatController>();
      
      // 로그아웃 콜백 설정 (null 안전성 추가)
      authController.onSignOutCallback = () {
        try {
          _groupController?.onSignOut();
          _chatController?.onSignOut();
          
          // FCM 토큰 정리
          FCMService().clearToken();
          
          // AuthWrapper 상태 즉시 업데이트
          if (mounted) {
            setState(() {
              // 상태 업데이트를 통해 위젯 재빌드 강제
            });
          }
        } catch (e) {
          // 로그아웃 콜백 실행 중 오류
        }
      };
      
      authController.initialize();
      
      // 초기 로그인 상태 설정
      _wasLoggedIn = authController.isLoggedIn;
      
      // FCM 초기화
      FCMService().initialize();
      
      _controllersInitialized = true;
    } catch (e) {
      debugPrint('컨트롤러 초기화 실패: $e');
    }
  }

  @override
  void dispose() {
    // 필요시 추가 정리 작업
    super.dispose();
  }

  // 메모메모..
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        // 초기화 중이면 로딩 화면
        if (!authController.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그아웃 감지 시 즉시 LoginView 반환 (정리는 AuthController 콜백에서 처리됨)
        if (_wasLoggedIn && !authController.isLoggedIn) {
          // 컨트롤러 재초기화 플래그 설정 (다시 로그인할 때 재초기화하도록)
          _controllersInitialized = false;
          // 추가적인 메모리 정리
          _groupController = null;
          _chatController = null;
          _wasLoggedIn = false; // 즉시 업데이트
          return const LoginView();
        }
        
        // 로그인 감지 (컨트롤러 재초기화)
        if (!_wasLoggedIn && authController.isLoggedIn && !_controllersInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeControllers();
          });
        }
        
        // 현재 상태를 기록 (다음 빌드에서 비교하기 위해)
        final previousWasLoggedIn = _wasLoggedIn;
        _wasLoggedIn = authController.isLoggedIn;
        
        // 로그아웃이 감지된 경우 즉시 LoginView 반환 (추가 안전장치)
        if (previousWasLoggedIn && !authController.isLoggedIn) {
          _controllersInitialized = false;
          _groupController = null;
          _chatController = null;
          return const LoginView();
        }

        // 임시 회원가입 데이터가 있으면 프로필 생성 화면으로
        if (authController.tempRegistrationData != null) {
          return const ProfileCreateView();
        }

        // 로그인 되어있지 않으면 로그인 화면
        if (!authController.isLoggedIn) {
          return const LoginView();
        }
        
        // 추가 안전장치: Firebase Auth 직접 확인
        final firebaseUser = authController.firebaseService.currentUser;
        if (firebaseUser == null) {
          return const LoginView();
        }

        // 로그인은 되어있지만 사용자 정보가 없으면 로그인 화면으로 이동
        // (Firestore 데이터 로드 실패 시 재로그인 유도)
        if (authController.currentUserModel == null) {
          return const LoginView(); // ❗️ 수정: HomeView → LoginView
        }

        // 프로필이 완성되지 않았지만 기본 정보가 있으면 홈 화면으로 이동 가능
        // (사용자가 "나중에 설정하기"를 선택한 경우)
        if (!authController.currentUserModel!.isProfileComplete) {
          // 기본 정보 (전화번호, 성별, 생년월일)가 있으면 홈 화면 허용
          final user = authController.currentUserModel!;
          if (user.phoneNumber.isNotEmpty && 
              user.gender.isNotEmpty && 
              user.birthDate.isNotEmpty) {
            return const HomeView();
          } else {
            // 기본 정보도 없으면 프로필 생성 화면으로
            return const ProfileCreateView();
          }
        }

        // 모든 조건을 만족하면 홈 화면
        return const HomeView();
      },
    );
  }
}

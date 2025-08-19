import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
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
import 'views/chat_view.dart';
import 'utils/app_theme.dart';
import 'services/fcm_service.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase 초기화 (플랫폼별 설정 사용)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firebase Realtime Database URL 설정
    FirebaseDatabase.instance.databaseURL =
        'https://groupting-aebab-default-rtdb.firebaseio.com';

    // FCM 백그라운드 메시지 핸들러 설정
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    print('Firebase 초기화 성공');
  } catch (e) {
    print('Firebase 초기화 오류: $e');
  }

  runApp(const MyApp());
}

// FCM 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // print('백그라운드에서 메시지 수신: ${message.messageId}');
  // print('제목: ${message.notification?.title}');
  // print('내용: ${message.notification?.body}');
  // print('데이터: ${message.data}');
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
        debugPrint('AuthController 로그아웃 콜백 실행');
        try {
          _groupController?.onSignOut();
          _chatController?.onSignOut();
          
          // FCM 토큰 정리
          FCMService().clearToken();
        } catch (e) {
          debugPrint('로그아웃 콜백 실행 중 오류: $e');
        }
      };
      
      authController.initialize();
      
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

        // 로그아웃 감지 (정리는 AuthController 콜백에서 처리됨)
        if (_wasLoggedIn && !authController.isLoggedIn) {
          debugPrint('로그아웃 감지됨 - 세션 정리 및 화면 전환');
          // 컨트롤러 재초기화 플래그 설정 (다시 로그인할 때 재초기화하도록)
          _controllersInitialized = false;
          // 추가적인 메모리 정리
          _groupController = null;
          _chatController = null;
          debugPrint('로그아웃 완료 - LoginView로 자동 전환');
        }
        
        // 로그인 감지 (컨트롤러 재초기화)
        if (!_wasLoggedIn && authController.isLoggedIn && !_controllersInitialized) {
          debugPrint('로그인 감지됨, 컨트롤러 재초기화 필요');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeControllers();
          });
        }
        
        _wasLoggedIn = authController.isLoggedIn;

        // 임시 회원가입 데이터가 있으면 프로필 생성 화면으로
        if (authController.tempRegistrationData != null) {
          return const ProfileCreateView();
        }

        // 로그인 되어있지 않으면 로그인 화면
        if (!authController.isLoggedIn) {
          return const LoginView();
        }

        // 로그인은 되어있지만 사용자 정보가 없으면 회원가입 화면
        // 단, "나중에 입력하기"로 스킵한 경우는 홈 화면으로 이동 가능
        if (authController.currentUserModel == null) {
          // Firebase Auth에는 로그인되어 있지만 Firestore에 프로필이 없는 경우
          // "나중에 입력하기"로 스킵한 사용자일 가능성이 높으므로 홈 화면으로 이동
          return const HomeView();
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

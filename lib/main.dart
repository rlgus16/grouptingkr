import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'controllers/auth_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/group_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/locale_controller.dart';
import 'controllers/store_controller.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/register_view.dart';
import 'utils/app_theme.dart';
import 'services/fcm_service.dart';
import 'firebase_options.dart';
import 'services/version_service.dart';
import 'views/update_view.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 전역 네비게이터 키
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // WidgetsBinding 인스턴스 캡처
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 스플래시 화면 유지 (앱 초기화 및 버전 체크가 끝날 때까지)
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 시스템 메시지 무시
  if (message.data['senderId'] == 'system') {
    return;
  }

  debugPrint('백그라운드 메시지 수신: ${message.messageId}');

  // 로컬 알림 플러그인 설정
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 1. 기본 알림 채널 (채팅 메시지 등)
  const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
    'groupting_message',
    '채팅 메세지 알림',
    description: '새로운 채팅 메세지 알림을 받습니다',
    importance: Importance.high,
  );

  // 2. 초대 전용 알림 채널 (최고 우선순위 + 소리/진동)
  const AndroidNotificationChannel invitationChannel = AndroidNotificationChannel(
    'groupting_invitation',
    '그룹 초대 알림',
    description: '친구들의 그룹 초대 알림을 받습니다',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  final androidImpl = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
  if (androidImpl != null) {
    await androidImpl.createNotificationChannel(defaultChannel);
    await androidImpl.createNotificationChannel(invitationChannel);
  }

  // 알림 표시
  String? title = message.notification?.title;
  String? body = message.notification?.body;
  
  // 사용할 채널 결정 (기본값: defaultChannel)
  AndroidNotificationChannel currentChannel = defaultChannel;
  // 초대 알림 여부 확인
  bool isInvitation = false;

  // 데이터 메시지인 경우 내용 채우기
  if (message.data.isNotEmpty) {
    final type = message.data['type'];
    
    // [초대 알림 처리]
    if (type == 'new_invitation') {
      isInvitation = true;
      currentChannel = invitationChannel;
      
      // 1순위: 명시적 로컬 알림 필드
      title = message.data['localNotificationTitle'];
      body = message.data['localNotificationBody'];
      
      // 2순위: 닉네임 기반 구성
      if (title == null || title.isEmpty) {
        title = '그룹팅';
        final nickname = message.data['fromUserNickname'];
        if (nickname != null && nickname.isNotEmpty) {
          body = '$nickname님이 그룹에 초대했습니다.';
        } else {
          body = '새로운 초대가 도착했습니다.';
        }
      }
    } 
    // [채팅 메시지 처리]
    else if (type == 'new_message') {
      if (title == null) {
        title = message.data['senderNickname'] ?? '알림';
        body = message.data['content'] ?? '새로운 메시지가 도착했습니다.';
        if (message.data['type'] == 'image') {
          body = '(사진)';
        }
      }
    }
    // [그 외 알림]
    else {
      if (title == null) {
        title = message.data['title'] ?? '알림';
        body = message.data['body'] ?? '새로운 알림이 도착했습니다.';
      }
    }
  }

  if (title != null && body != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          currentChannel.id,
          currentChannel.name,
          channelDescription: currentChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: currentChannel.importance,
          priority: isInvitation ? Priority.max : Priority.high,
          // 초대 알림은 헤드업 노티피케이션 등 강조
          fullScreenIntent: isInvitation, 
        ),
      ),
    );
  }
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
        ChangeNotifierProvider(create: (_) => StoreController()),
        ChangeNotifierProvider(create: (_) {
          final controller = LocaleController();
          controller.initialize();
          return controller;
        }),
      ],
      child: Consumer<LocaleController>(
        builder: (context, localeController, _) {
          return MaterialApp(
            title: '그룹팅',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,

            // 현재 선택된 언어
            locale: localeController.locale,

            // 델리게이트 설정
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // 언어 지원
            supportedLocales: AppLocalizations.supportedLocales,

            initialRoute: '/',
            routes: {
              '/': (context) => const VersionCheckWrapper(child: AuthWrapper()),
              '/login': (context) => const LoginView(),
              '/register': (context) => const RegisterView(),
              '/home': (context) => const HomeView(),
            },
          );
        },
      ),
    );
  }
}

// 앱 시작 시 버전 체크를 수행하는 위젯
class VersionCheckWrapper extends StatefulWidget {
  final Widget child;
  const VersionCheckWrapper({super.key, required this.child});

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  bool _isLoading = true;
  VersionCheckResult? _result;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final versionService = VersionService();
    // 버전 체크 수행
    final result = await versionService.checkVersion();

    if (mounted) {
      setState(() {
        _result = result;
        _isLoading = false;
      });
      // 로딩이 완료되면(버전 체크 끝) 스플래시 화면 제거
      FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 로딩 중에는 스플래시 화면이 네이티브 단에서 유지되므로
      // Flutter 화면에는 빈 공간을 둡니다. (사용자에게는 보이지 않음)
      return const SizedBox();
    }

    if (_result != null && _result!.needsUpdate) {
      // 업데이트가 필요하면 강제 업데이트 화면 표시
      return UpdateView(
        storeUrl: _result!.storeUrl ?? '',
        message: _result!.message ?? '업데이트가 필요합니다.',
      );
    }

    // 업데이트가 필요 없으면 기존 흐름(AuthWrapper)으로 진행
    return widget.child;
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
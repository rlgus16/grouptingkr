import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_service.dart';
import 'user_service.dart';
import '../main.dart' as main_file;
import '../views/chat_view.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _currentChatRoomId; // 현재 활성 채팅방 ID 추적
  
  // FCM 토큰 getter
  String? get fcmToken => _fcmToken;

  // 현재 채팅방 설정/해제 메서드
  void setCurrentChatRoom(String? chatRoomId) {
    _currentChatRoomId = chatRoomId;
    debugPrint('현재 활성 채팅방 설정: $chatRoomId');
  }

  void clearCurrentChatRoom() {
    debugPrint('채팅방 비활성화: $_currentChatRoomId');
    _currentChatRoomId = null;
  }

  String? get currentChatRoomId => _currentChatRoomId;

    // FCM 초기화
  Future<void> initialize() async {
    try {
      debugPrint('FCM 초기화 시작');

      // 로컬 알림 초기화
      debugPrint('로컬 알림 초기화 시작...');
      await _initializeLocalNotifications();

      // 알림 권한 요청
      debugPrint('FCM 알림 권한 요청 시작...');
      await _requestPermission();

      // Android 알림 채널 설정
      debugPrint('Android 알림 채널 설정 시작...');
      await _setupNotificationChannels();

      // FCM 토큰 가져오기
      debugPrint('FCM 토큰 가져오기 시작...');
      await _getToken();

      // 포그라운드 메시지 핸들러 설정
      debugPrint('포그라운드 메시지 핸들러 설정...');
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드 메시지 핸들러는 main.dart에서 설정됩니다.

      // 앱이 알림으로 열렸을 때 처리
      debugPrint('알림 탭 핸들러 설정...');
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // 앱이 종료된 상태에서 알림으로 열렸을 때 처리
      _handleInitialMessage();

      // 토큰 새로고침 리스너
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateTokenInFirestore);

      debugPrint('FCM 초기화 완료');
    } catch (e, stackTrace) {
      debugPrint('FCM 초기화 치명적 오류: $e');
      debugPrint('스택트레이스: $stackTrace');
    }
  }

  // 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android 설정
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 설정
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // 로컬 알림 초기화
      final bool? initialized = await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
          // 로컬 알림을 눌렀을 때의 처리
          _handleLocalNotificationTap(notificationResponse);
        },
      );

      if (initialized == true) {
        debugPrint('로컬 알림 초기화 완료');
      } else {
        debugPrint('로컬 알림 초기화 실패 (초기화 결과: $initialized)');
      }

      // Android 권한 확인
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          final bool? grantedNotificationPermission = await androidImplementation.requestNotificationsPermission();
          debugPrint('Android 알림 권한: $grantedNotificationPermission');

          final bool? grantedExactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
          debugPrint('Android 정확한 알람 권한: $grantedExactAlarmPermission');
        }
      }

    } catch (e, stackTrace) {
      debugPrint('로컬 알림 초기화 실패: $e');
      debugPrint('스택트레이스: $stackTrace');
    }
  }

  // Android 알림 채널 설정 (기본 FCM 사용)
  Future<void> _setupNotificationChannels() async {
    try {
      // Android 알림 채널 생성
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'groupting_default', // id
        '그룹팅 알림', // title
        description: '그룹팅 앱의 모든 알림',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('Android 알림 채널 설정 완료');
    } catch (e) {
      debugPrint('알림 채널 설정 오류: $e');
    }
  }

  // 알림 권한 요청
  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );


      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 사용자가 알림 권한을 허용
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 사용자가 임시 알림 권한을 허용
      } else {
        // 사용자가 알림 권한을 거부
      }
    } catch (e) {
      // FCM 권한 요청 오류
    }
  }

  // FCM 토큰 가져오기
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM 토큰 획득: ${_fcmToken?.substring(0, 20)}...');

      if (_fcmToken != null) {
        await _updateTokenInFirestore(_fcmToken!);
      } else {
        debugPrint('FCM 토큰이 null입니다');
      }
    } catch (e) {
      debugPrint('FCM 토큰 가져오기 오류: $e');
    }
  }

  // Firestore에 FCM 토큰 업데이트 (재시도 로직 추가)
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        debugPrint('사용자가 로그인되지 않음 - 토큰 저장 연기');
        _fcmToken = token;
        return;
      }

      debugPrint('Firestore에 FCM 토큰 저장 중... (사용자: ${currentUser.uid})');
      
      // 사용자 문서가 존재하는지 먼저 확인
      final userDoc = await _firebaseService.users.doc(currentUser.uid).get();
      if (!userDoc.exists) {
        debugPrint('사용자 문서가 존재하지 않음 - 토큰 저장 연기');
        _fcmToken = token;
        return;
      }

      await _firebaseService.users.doc(currentUser.uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('FCM 토큰 Firestore 저장 성공!');
    } catch (e) {
      debugPrint('Firestore 토큰 업데이트 실패: $e');
      // FCM 토큰 Firestore 저장 오류
      // 토큰만 저장해두고, 나중에 다시 시도
      _fcmToken = token;
    }
  }

  // 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('포그라운드 FCM 메시지 수신: ${message.notification?.title}');
    debugPrint('메시지 내용: ${message.notification?.body}');
    debugPrint('데이터: ${message.data}');
    
    // 메시지 타입이 new_message인 경우에만 채팅방 확인
    final messageType = message.data['type'];
    final messageChatRoomId = message.data['chatroomId'];
    
    if (messageType == 'new_message' && messageChatRoomId != null) {
      // 현재 활성 채팅방과 같은 채팅방의 메시지인지 확인
      if (_currentChatRoomId == messageChatRoomId) {
        debugPrint('현재 활성 채팅방($messageChatRoomId)의 메시지이므로 알림 표시하지 않음');
        return; // 알림 표시하지 않음
      } else {
        debugPrint('다른 채팅방($messageChatRoomId)의 메시지 (현재: $_currentChatRoomId)');
      }
    }
    
    // 포그라운드에서 로컬 알림 표시
    _showLocalNotification(message);
  }

  // 포그라운드에서 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) {
        debugPrint('FCM 알림 데이터가 null입니다');
        return;
      }

      debugPrint('로컬 알림 표시 시작: ${notification.title}');

      // 플러그인 상태 확인
      try {
        // 간단한 테스트로 플러그인이 등록되었는지 확인
        final pendingNotifications = await _localNotifications.pendingNotificationRequests();
        debugPrint('현재 대기 중인 알림 수: ${pendingNotifications.length}');
      } catch (pluginError) {
        debugPrint('플러그인 상태 확인 실패: $pluginError');
        // 플러그인이 제대로 등록되지 않았을 가능성
        return;
      }

      // 알림 데이터를 payload에 JSON으로 저장
      final payload = message.data.isNotEmpty 
          ? Uri.encodeComponent(message.data.toString()) 
          : '';

      debugPrint('알림 payload: $payload');

      // Android 알림 세부 설정
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'groupting_default',
        '그룹팅 알림',
        channelDescription: '그룹팅 앱의 모든 알림',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ticker: 'ticker',
      );

      // iOS 알림 세부 설정
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      debugPrint('알림 ID: $notificationId');

      // 로컬 알림 표시
      await _localNotifications.show(
        notificationId,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: payload,
      );

      debugPrint('포그라운드 로컬 알림 표시 완료');
    } catch (e, stackTrace) {
      debugPrint('로컬 알림 표시 실패: $e');
      debugPrint('스택트레이스: $stackTrace');
      
      // 플러그인 등록 상태 확인
      if (e is MissingPluginException) {
        debugPrint('flutter_local_notifications 플러그인이 등록되지 않았습니다.');
        debugPrint('해결방법: flutter clean && flutter pub get 후 완전 재빌드 필요');
      }
    }
  }

  // 로컬 알림을 눌렀을 때 처리
  void _handleLocalNotificationTap(NotificationResponse notificationResponse) {
    try {
      debugPrint('로컬 알림 클릭됨');
      
      if (notificationResponse.payload != null && 
          notificationResponse.payload!.isNotEmpty) {
        // payload에서 데이터 파싱
        final decodedPayload = Uri.decodeComponent(notificationResponse.payload!);
        debugPrint('알림 payload: $decodedPayload');
        
        // 간단한 데이터 파싱 (실제로는 JSON 파싱을 사용하는 것이 좋습니다)
        if (decodedPayload.contains('chatroomId')) {
          // chatroomId 추출
          final match = RegExp(r'chatroomId:\s*([^,}]+)').firstMatch(decodedPayload);
          if (match != null) {
            final chatroomId = match.group(1)?.trim();
            if (chatroomId != null && chatroomId.isNotEmpty) {
              _navigateToChat(chatroomId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('로컬 알림 탭 처리 오류: $e');
    }
  }

  // 알림을 탭해서 앱이 열렸을 때 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    _navigateToScreen(message);
  }

  // 앱이 종료된 상태에서 알림으로 열렸을 때 처리
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // 앱이 완전히 로드된 후 네비게이션 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToScreen(initialMessage);
        });
      }
    } catch (e) {
      // 초기 메시지 처리 오류
    }
  }

  // 알림 타입에 따른 화면 이동
  void _navigateToScreen(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    try {
      switch (type) {
        case 'new_message':
          // 채팅 화면으로 이동
          final chatroomId = data['chatroomId'];
          if (chatroomId != null && chatroomId.isNotEmpty) {
            debugPrint('FCM 알림으로 채팅방 이동: $chatroomId');
            _navigateToChat(chatroomId);
          }
          break;

        case 'new_invitation':
          // 초대 목록 화면으로 이동
          _navigateToInvitations();
          break;

        case 'matching_completed':
          // 매칭 완료된 채팅방으로 이동
          final chatRoomId = data['chatRoomId'];
          if (chatRoomId != null && chatRoomId.isNotEmpty) {
            debugPrint('매칭 완료 알림으로 채팅방 이동: $chatRoomId');
            _navigateToChat(chatRoomId);
          } else {
            // chatRoomId가 없으면 홈 화면으로
            _navigateToHome();
          }
          break;

        default:
          debugPrint('알 수 없는 알림 타입: $type');
          _navigateToHome();
      }
    } catch (e) {
      debugPrint('화면 이동 처리 오류: $e');
    }
  }

  // 채팅방으로 이동
  void _navigateToChat(String chatroomId) {
    try {
      final context = main_file.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatView(groupId: chatroomId),
          ),
        );
        debugPrint('채팅방 이동 완료: $chatroomId');
      } else {
        debugPrint('네비게이터 컨텍스트를 찾을 수 없음');
      }
    } catch (e) {
      debugPrint('채팅방 이동 실패: $e');
    }
  }

  // 홈 화면으로 이동
  void _navigateToHome() {
    try {
      final context = main_file.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        debugPrint('홈 화면 이동 완료');
      }
    } catch (e) {
      debugPrint('홈 화면 이동 실패: $e');
    }
  }

  // 초대 목록으로 이동
  void _navigateToInvitations() {
    try {
      final context = main_file.navigatorKey.currentContext;
      if (context != null) {
        // 홈 화면으로 이동 (초대 목록은 홈에서 접근)
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        debugPrint('초대 알림으로 홈 화면 이동 완료');
      }
    } catch (e) {
      debugPrint('초대 목록 이동 실패: $e');
    }
  }

  // FCM 토큰 새로고침
  Future<void> refreshToken() async {
    try {
      await _messaging.deleteToken();
      await _getToken();
    } catch (e) {
      // FCM 토큰 새로고침 오류
    }
  }

  // 로그인 후 FCM 토큰 다시 저장 시도 (지연된 토큰 저장 처리)
  Future<void> retryTokenSave() async {
    try {
      debugPrint('FCM 토큰 재저장 시도...');
      
      if (_fcmToken == null) {
        debugPrint('저장된 FCM 토큰이 없습니다. 새로 가져옵니다.');
        await _getToken();
        return;
      }

      debugPrint('기존 FCM 토큰으로 재저장 시도');
      await _updateTokenInFirestore(_fcmToken!);
    } catch (e) {
      debugPrint('FCM 토큰 재저장 실패: $e');
    }
  }

  // 로그아웃 시 FCM 토큰 제거
  Future<void> clearToken() async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser != null) {
        await _firebaseService.users.doc(currentUser.uid).update({
          'fcmToken': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _messaging.deleteToken();
      _fcmToken = null;

    } catch (e) {
      // FCM 토큰 제거 오류
    }
  }

  // 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      // 토픽 구독 오류
    }
  }

  // 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      // 토픽 구독 해제 오류
    }
  }
}
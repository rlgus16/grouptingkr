import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_service.dart';
import '../main.dart' as main_file;
import '../views/chat_view.dart';
import '../views/invitation_list_view.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _currentChatRoomId; // 현재 활성 채팅방 ID 추적
  
  // FCM 토큰 저장 재시도 관련 필드
  bool _tokenSavePending = false;
  Timer? _tokenSaveRetryTimer;
  int _tokenSaveRetryCount = 0;
  static const int _maxTokenSaveRetries = 5;
  
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

        }
      }

    } catch (e, stackTrace) {
      debugPrint('로컬 알림 초기화 실패: $e');
      debugPrint('스택트레이스: $stackTrace');
    }
  }

  // Android 알림 채널 설정 (다중 채널 지원)
  Future<void> _setupNotificationChannels() async {
    try {
      // 기본 알림 채널
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        'groupting_default', // id
        '그룹팅 알림', // title
        description: '그룹팅 앱의 기본 알림',
        importance: Importance.high,
      );

      // 초대 전용 알림 채널 (최고 우선순위)
      const AndroidNotificationChannel invitationChannel = AndroidNotificationChannel(
        'groupting_invitation', // id
        '그룹 초대 알림', // title
        description: '친구들의 그룹 초대 알림을 받습니다',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      // 채팅 메시지 전용 알림 채널
      const AndroidNotificationChannel messageChannel = AndroidNotificationChannel(
        'groupting_message', // id
        '채팅 메세지 알림', // title
        description: '새로운 채팅 메세지 알림을 받습니다',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        // 각 채널 생성
        await androidImpl.createNotificationChannel(defaultChannel);
        await androidImpl.createNotificationChannel(invitationChannel);
        await androidImpl.createNotificationChannel(messageChannel);
        
        debugPrint('알림 채널 설정 완료');
        debugPrint('기본 채널: ${defaultChannel.id}');
        debugPrint('초대 채널: ${invitationChannel.id}');
        debugPrint('메시지 채널: ${messageChannel.id}');
      }
    } catch (e) {
      debugPrint('알림 채널 설정 오류: $e');
    }
  }

  // 알림 권한 요청 및 상태 확인
  Future<void> _requestPermission() async {
    try {
      // 현재 권한 상태 먼저 확인
      final currentSettings = await _messaging.getNotificationSettings();
      debugPrint('현재 알림 권한 상태: ${currentSettings.authorizationStatus}');
      debugPrint('Alert 권한: ${currentSettings.alert}');
      debugPrint('Badge 권한: ${currentSettings.badge}');  
      debugPrint('Sound 권한: ${currentSettings.sound}');
      
      // 권한이 없거나 거부된 경우 요청
      if (currentSettings.authorizationStatus == AuthorizationStatus.notDetermined ||
          currentSettings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('알림 권한 요청 시작...');
        
        final settings = await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        
        debugPrint('알림 권한 요청 결과: ${settings.authorizationStatus}');
        
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('알림 권한 승인됨');
        } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
          debugPrint('임시 알림 권한 승인됨');
        } else {
          debugPrint('알림 권한 거부됨 - 알림이 표시되지 않습니다!');
        }
      } else if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('알림 권한이 이미 승인되어 있음');
      }

      // Android 13+ 추가 권한 확인
      if (Platform.isAndroid) {
        debugPrint('Android 플랫폼 - 추가 권한 상태 확인');
        try {
          await _localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
          debugPrint('Android 로컬 알림 권한 요청 완료');
        } catch (e) {
          debugPrint('Android 로컬 알림 권한 요청 실패: $e');
        }
      }
      
    } catch (e) {
      debugPrint('알림 권한 처리 중 오류: $e');
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
        _tokenSavePending = true;
        return;
      }

      debugPrint('Firestore에 FCM 토큰 저장 중... (사용자: ${currentUser.uid})');
      debugPrint('저장할 토큰: ${token.substring(0, 20)}...');
      
      // update()를 사용하여 기존 문서에 필드 추가/업데이트
      await _firebaseService.users.doc(currentUser.uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 저장 확인을 위해 서버에서 직접 읽어옴 (캐시가 아닌 서버 데이터 확인)
      final doc = await _firebaseService.users.doc(currentUser.uid).get(
        const GetOptions(source: Source.server),
      );
      final savedToken = doc.data()?['fcmToken'];
      
      if (savedToken == token) {
        debugPrint('FCM 토큰 Firestore 저장 확인 완료!');
        _tokenSavePending = false;
        _tokenSaveRetryCount = 0;
        _tokenSaveRetryTimer?.cancel();
      } else {
        debugPrint('FCM 토큰 저장 확인 실패! 저장된 토큰: $savedToken');
        _tokenSavePending = true;
        _scheduleTokenSaveRetry();
      }
    } catch (e) {
      debugPrint('Firestore 토큰 업데이트 실패: $e');
      _fcmToken = token;
      _tokenSavePending = true;
      _scheduleTokenSaveRetry();
    }
  }


  // FCM 토큰 저장 재시도 스케줄러
  void _scheduleTokenSaveRetry() {
    if (_tokenSaveRetryCount >= _maxTokenSaveRetries) {
      debugPrint('FCM 토큰 저장 최대 재시도 횟수 초과');
      return;
    }
    
    _tokenSaveRetryTimer?.cancel();
    final delaySeconds = math.pow(2, _tokenSaveRetryCount).toInt();
    _tokenSaveRetryCount++;
    
    debugPrint('FCM 토큰 저장 재시도 예약: ${delaySeconds}초 후 (시도: $_tokenSaveRetryCount)');
    
    _tokenSaveRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_fcmToken != null && _tokenSavePending) {
        _updateTokenInFirestore(_fcmToken!);
      }
    });
  }

  // 로그인 후 FCM 토큰이 저장되었는지 확인하고 저장 (공개 메서드)
  // 항상 새로운 토큰을 가져와서 저장합니다 (앱 재설치/디바이스 변경 대응)
  Future<void> ensureTokenSaved() async {
    debugPrint('FCM 토큰 새로 가져오기 및 저장 시작...');
    
    try {
      // 항상 FCM에서 새로운 토큰을 가져옴 (캐시된 토큰 사용하지 않음)
      final freshToken = await _messaging.getToken();
      
      if (freshToken == null) {
        debugPrint('FCM 토큰을 가져올 수 없습니다.');
        return;
      }
      
      debugPrint('FCM 새 토큰 획득: ${freshToken.substring(0, 20)}...');
      _fcmToken = freshToken;
      
      // Firestore에 저장
      await _updateTokenInFirestore(freshToken);
    } catch (e) {
      debugPrint('FCM 토큰 갱신 실패: $e');
      // 실패 시 기존 로직으로 폴백
      if (_fcmToken != null) {
        await _updateTokenInFirestore(_fcmToken!);
      }
    }
  }



  // 포그라운드 메시지 처리 (상세 로그)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('=== 포그라운드 FCM 메시지 수신 ===');
    debugPrint('데이터: ${message.data}');

    // 시스템 메시지는 무시
    if (message.data['senderId'] == 'system') {
      return;
    }

    final messageType = message.data['type'];
    // 서버 키값 대응 (chatRoomId 또는 chatroomId 둘 다 확인)
    final msgChatRoomId = message.data['chatRoomId'] ?? message.data['chatroomId'];

    // 초대 알림 특별 처리
    if (messageType == 'new_invitation') {
      _handleInvitationForegroundMessage(message);
      return;
    }

    // 현재 보고 있는 채팅방 관련 알림 차단 로직
    if (_currentChatRoomId != null && msgChatRoomId != null) {
      // (1) 일반 채팅: 방 ID가 정확히 일치하면 알림 안 띄움
      if (msgChatRoomId == _currentChatRoomId) {
        debugPrint('현재 채팅방 메시지입니다. 알림 생략.');
        return;
      }

      // 매칭 성공: 알림의 방 ID(예: A_B)가 내 현재 방 ID(예: A)를 포함하면 알림 안 띄움
      // 즉, 내가 대기방에 있는데 매칭되었다는 알림이 오면 팝업 띄우지 않음
      if (messageType == 'matching_completed' &&
          msgChatRoomId.toString().contains(_currentChatRoomId!)) {
        debugPrint('현재 보고 있는 그룹의 매칭 알림입니다. 알림 생략.');
        return;
      }
    }

    // 위 조건에 걸리지 않으면 로컬 알림 표시
    debugPrint('로컬 알림 표시 시작...');
    _showLocalNotification(message);
  }

  // 초대 알림 포그라운드 처리
  void _handleInvitationForegroundMessage(RemoteMessage message) {
    debugPrint('초대 알림 포그라운드 처리 시작');
    
    final data = message.data;
    final showAsLocalNotification = data['showAsLocalNotification'] == 'true';
    
    if (showAsLocalNotification) {
      // 로컬 알림 표시 (더 풍부한 초대 알림)
      _showInvitationLocalNotification(message);
    } else {
      // 기본 로컬 알림 표시
      _showLocalNotification(message);
    }
  }

  // 초대 전용 로컬 알림 표시 (프로필 이미지 포함)
  Future<void> _showInvitationLocalNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final title = data['localNotificationTitle'] ?? message.notification?.title ?? '새로운 초대';
      final body = data['localNotificationBody'] ?? message.notification?.body ?? '초대가 도착했습니다';
      final invitationId = data['invitationId'] ?? '';
      
      debugPrint('초대 로컬 알림 표시 시작: $title');
      
      // 플러터 로컬 알림 플러그인 설정
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // 고유 ID
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'groupting_invitation',
            '그룹 초대 알림',
            channelDescription: '친구들의 그룹 초대 알림을 받습니다',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            // sound: const RawResourceAndroidNotificationSound('notification'), // 리소스 부재로 제거 (기본음 사용)
            color: const Color(0xFF4CAF50), // 초대 알림 색상
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
            ),
            // actions: [ ... ] // 아이콘 리소스 부재로 제거
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            categoryIdentifier: 'INVITATION_CATEGORY',
            threadIdentifier: 'invitation_$invitationId',
            // iOS는 이미지 첨부 처리 복잡하여 제외 (Android만 지원)
            attachments: null,
          ),
        ),
        payload: invitationId,
      );

      debugPrint('초대 로컬 알림 표시 완료');

    } catch (e) {
      debugPrint('초대 로컬 알림 표시 실패: $e');
      // 실패 시 기본 로컬 알림으로 대체
      _showLocalNotification(message);
    }
  }

  // 포그라운드에서 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // Support both notification payload and data-only messages
      final notification = message.notification;
      final data = message.data;
      
      // Extract title and body from notification or data payload
      String? title;
      String? body;
      
      if (notification != null) {
        title = notification.title;
        body = notification.body;
      } else if (data.isNotEmpty) {
        // Data-only message: extract from data payload
        final messageType = data['type'];
        

        if (messageType == 'new_invitation') {
          // [초대 알림 처리 추가]
          title = data['localNotificationTitle'] ?? '그룹팅';
          body = '새로운 초대가 도착했습니다.';
        } else if (messageType == 'new_message') {
          title = data['senderNickname'] ?? '새 메시지';
          body = data['content'] ?? '';
        } else {
          // For other types, try generic fields
          title = data['title'] ?? '알림';
          body = data['body'] ?? data['message'] ?? '';
        }
      }
      
      if (title == null || title.isEmpty) {
        debugPrint('FCM 알림 데이터가 없거나 유효하지 않습니다');
        return;
      }

      debugPrint('로컬 알림 표시 시작: $title');

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
        title,
        body,
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
      debugPrint('로컬 알림 클릭됨: ${notificationResponse.actionId}');
      debugPrint('페이로드: ${notificationResponse.payload}');
      
      // 액션 버튼 클릭 처리 (초대 알림)
      if (notificationResponse.actionId != null) {
        _handleNotificationAction(notificationResponse.actionId!, notificationResponse.payload);
        return;
      }
      
      if (notificationResponse.payload != null && 
          notificationResponse.payload!.isNotEmpty) {
        final payload = notificationResponse.payload!;
        debugPrint('로컬 알림에서 페이로드: $payload');
        
        // 초대 ID인 경우 (일반적으로 길이가 20자 이상)
        if (payload.length > 15 && !payload.contains('_')) {
          debugPrint('초대 알림 클릭 -> 초대 목록 이동: $payload');
          _navigateToInvitations();
        } else {
          // 채팅방 ID인 경우
          debugPrint('채팅 알림 클릭 -> 채팅방 이동: $payload');
          _navigateToChat(payload);
        }
      } else {
        debugPrint('알림 payload가 없음, 홈 화면으로 이동');
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('로컬 알림 탭 처리 오류: $e');
      _navigateToHome();
    }
  }

  // 알림 액션 버튼 처리
  void _handleNotificationAction(String actionId, String? payload) {
    debugPrint('🎬 알림 액션 처리: $actionId');
    
    switch (actionId) {
      case 'accept_invitation':
        // 초대 수락 액션 - 초대 목록으로 이동 후 자동 수락 처리 가능
        debugPrint('초대 수락 액션');
        _navigateToInvitations();
        break;
      case 'view_invitation':
        // 초대 확인 액션 - 초대 목록으로 이동
        debugPrint('초대 확인 액션');
        _navigateToInvitations();
        break;
      default:
        debugPrint('알 수 없는 액션: $actionId');
        _navigateToHome();
    }
  }

  // 알림을 탭해서 앱이 열렸을 때 처리 (백그라운드 -> 포그라운드)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('백그라운드 알림 클릭 - 앱 포그라운드 전환');
    debugPrint('알림 데이터: ${message.data}');
    
    // 약간의 지연 후 네비게이션 (UI가 안정화된 후)
    Future.delayed(const Duration(milliseconds: 500), () {
      _navigateToScreen(message);
    });
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

    debugPrint('알림 타입별 화면 이동 처리: $type');
    debugPrint('알림 전체 데이터: $data');

    try {
      switch (type) {
        case 'new_message':
          // 채팅 화면으로 이동
          final chatroomId = data['chatroomId'];
          if (chatroomId != null && chatroomId.isNotEmpty) {
            debugPrint('새 메시지 알림으로 채팅방 이동: $chatroomId');
            _navigateToChat(chatroomId);
          } else {
            debugPrint('채팅방 ID가 없음, 홈 화면으로 이동');
            _navigateToHome();
          }
          break;

        case 'new_invitation':
          // 초대 목록 화면으로 이동 (홈에서 확인 가능)
          debugPrint('새 초대 알림으로 홈 화면 이동');
          _navigateToInvitations();
          break;

        case 'matching_completed':
          // 매칭 완료된 채팅방으로 이동
          final chatRoomId = data['chatRoomId'];
          if (chatRoomId != null && chatRoomId.isNotEmpty) {
            debugPrint('매칭 완료 알림으로 채팅방 이동: $chatRoomId');
            _navigateToChat(chatRoomId);
          } else {
            debugPrint('매칭 완료 알림에 채팅방 ID가 없음, 홈 화면으로 이동');
            _navigateToHome();
          }
          break;

        default:
          debugPrint('알 수 없는 알림 타입: $type, 홈 화면으로 이동');
          _navigateToHome();
      }
    } catch (e, stackTrace) {
      debugPrint('화면 이동 처리 오류: $e');
      debugPrint('스택트레이스: $stackTrace');
      // 오류 시 홈 화면으로라도 이동
      _navigateToHome();
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
        // 홈 화면을 먼저 스택의 최하단에 배치 (Back 버튼 시 홈으로 이동)
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        
        // 초대 목록 화면을 그 위에 푸시
        Future.delayed(const Duration(milliseconds: 100), () {
          if (main_file.navigatorKey.currentContext != null) {
            Navigator.of(main_file.navigatorKey.currentContext!).push(
              MaterialPageRoute(
                builder: (context) => const InvitationListView(),
              ),
            );
          }
        });
        
        debugPrint('초대 알림 클릭 -> 홈 -> 초대 목록 이동 완료');
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
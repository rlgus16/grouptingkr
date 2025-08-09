import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_service.dart';
import 'user_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();

  String? _fcmToken;
  
  // FCM 토큰 getter
  String? get fcmToken => _fcmToken;

  // FCM 초기화
  Future<void> initialize() async {
    try {
      print('FCM 초기화 시작');

      // 알림 권한 요청
      await _requestPermission();

      // FCM 토큰 가져오기
      await _getToken();

      // 포그라운드 메시지 핸들러 설정
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드 메시지 핸들러는 main.dart에서 설정됩니다.

      // 앱이 알림으로 열렸을 때 처리
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // 앱이 종료된 상태에서 알림으로 열렸을 때 처리
      _handleInitialMessage();

      // 토큰 새로고침 리스너
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateTokenInFirestore);

      print('FCM 초기화 완료');
    } catch (e) {
      print('FCM 초기화 오류: $e');
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

      print('FCM 권한 상태: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('사용자가 알림 권한을 허용했습니다.');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('사용자가 임시 알림 권한을 허용했습니다.');
      } else {
        print('사용자가 알림 권한을 거부했습니다.');
      }
    } catch (e) {
      print('FCM 권한 요청 오류: $e');
    }
  }

  // FCM 토큰 가져오기
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      print('FCM 토큰: $_fcmToken');

      if (_fcmToken != null) {
        await _updateTokenInFirestore(_fcmToken!);
      }
    } catch (e) {
      print('FCM 토큰 가져오기 오류: $e');
    }
  }

  // Firestore에 FCM 토큰 업데이트
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        print('로그인된 사용자가 없어 FCM 토큰을 저장할 수 없습니다.');
        return;
      }

      await _firebaseService.users.doc(currentUser.uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('FCM 토큰이 Firestore에 저장되었습니다: $token');
    } catch (e) {
      print('FCM 토큰 Firestore 저장 오류: $e');
    }
  }

  // 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    print('포그라운드에서 메시지 수신: ${message.messageId}');
    print('제목: ${message.notification?.title}');
    print('내용: ${message.notification?.body}');
    print('데이터: ${message.data}');

    // 현재 화면에 알림 표시 (선택사항)
    _showInAppNotification(message);
  }

  // 앱 내 알림 표시 (Overlay 사용)
  void _showInAppNotification(RemoteMessage message) {
    // 실제 구현 시에는 Overlay나 SnackBar를 사용할 수 있습니다.
    // 여기서는 로그만 출력합니다.
    print('앱 내 알림 표시: ${message.notification?.title}');
  }

  // 알림을 탭해서 앱이 열렸을 때 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('알림을 탭해서 앱이 열림: ${message.messageId}');
    print('데이터: ${message.data}');

    _navigateToScreen(message);
  }

  // 앱이 종료된 상태에서 알림으로 열렸을 때 처리
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('앱이 종료된 상태에서 알림으로 열림: ${initialMessage.messageId}');
        print('데이터: ${initialMessage.data}');

        // 앱이 완전히 로드된 후 네비게이션 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToScreen(initialMessage);
        });
      }
    } catch (e) {
      print('초기 메시지 처리 오류: $e');
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
          final chatId = data['chatId'];
          if (chatId != null) {
            // NavigatorKey를 사용해 전역 네비게이션
            // 실제 구현 시에는 GoRouter나 Navigator.pushNamed 사용
            print('채팅 화면으로 이동: $chatId');
          }
          break;

        case 'new_invitation':
          // 초대 목록 화면으로 이동
          print('초대 목록 화면으로 이동');
          break;

        case 'matching_completed':
          // 홈 화면으로 이동 (매칭 완료 알림)
          print('홈 화면으로 이동 (매칭 완료)');
          break;

        default:
          print('알 수 없는 알림 타입: $type');
      }
    } catch (e) {
      print('화면 이동 처리 오류: $e');
    }
  }

  // FCM 토큰 새로고침
  Future<void> refreshToken() async {
    try {
      await _messaging.deleteToken();
      await _getToken();
    } catch (e) {
      print('FCM 토큰 새로고침 오류: $e');
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

      print('FCM 토큰이 제거되었습니다.');
    } catch (e) {
      print('FCM 토큰 제거 오류: $e');
    }
  }

  // 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('토픽 구독 완료: $topic');
    } catch (e) {
      print('토픽 구독 오류: $e');
    }
  }

  // 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('토픽 구독 해제 완료: $topic');
    } catch (e) {
      print('토픽 구독 해제 오류: $e');
    }
  }
}

// 백그라운드 메시지 핸들러 (main.dart에서 사용)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('백그라운드에서 메시지 수신: ${message.messageId}');
  print('제목: ${message.notification?.title}');
  print('내용: ${message.notification?.body}');
  print('데이터: ${message.data}');

  // 백그라운드에서 필요한 처리 수행
  // 예: 로컬 알림 표시, 데이터 동기화 등
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../services/fcm_service.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FCMService _fcmService = FCMService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUserModel;
  bool _isInitialized = false;

  // 로그아웃 시 호출할 콜백
  VoidCallback? onSignOutCallback;

  // 임시 데이터 저장 (호환성 유지)
  Map<String, dynamic>? _tempRegistrationData;
  Map<String, dynamic>? _tempProfileData;

  // Auth 상태 변경 리스너
  StreamSubscription<User?>? _authStateSubscription;

  // 회원가입 진행 중 플래그
  bool _isRegistrationInProgress = false;

  // 차단 목록 관리 변수
  List<String> _blockedUserIds = [];
  List<String> get blockedUserIds => _blockedUserIds;

  // 양방향 차단 구독 변수
  StreamSubscription? _sub1; // 내가 차단한 목록 구독
  StreamSubscription? _sub2; // 나를 차단한 목록 구독

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _firebaseService.currentUser != null;
  Map<String, dynamic>? get tempRegistrationData => _tempRegistrationData;
  Map<String, dynamic>? get tempProfileData => _tempProfileData;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 에러 설정 (외부 노출)
  void setError(String? error) {
    _setError(error);
  }

  // 에러 초기화
  void clearError() {
    _setError(null);
  }

  // Firebase Auth 에러를 한국어로 변환 (로그인용)
  String _getKoreanErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return '등록되지 않은 아이디입니다.';
        case 'wrong-password':
          return '비밀번호가 올바르지 않습니다.';
        case 'invalid-email':
          return '올바르지 않은 이메일 형식입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'too-many-requests':
          return '시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
        case 'invalid-credential':
          return '아이디 또는 비밀번호가 올바르지 않습니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        default:
          return '오류가 발생했습니다: ${error.message}';
      }
    }
    return '오류가 발생했습니다.';
  }

  // Firebase Auth 에러를 한국어로 변환 (회원가입용)
  String _getKoreanRegisterErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return '이미 사용 중인 아이디입니다.';
        case 'weak-password':
          return '비밀번호가 너무 간단합니다.';
        case 'invalid-email':
          return '올바르지 않은 아이디 형식입니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        default:
          return '회원가입 오류: ${error.message}';
      }
    }
    return '회원가입 중 오류가 발생했습니다: $error';
  }

  // ===========================================================================
  // [NEW] 즉시 회원가입 메서드 (임시 저장 없이 바로 가입)
  // ===========================================================================
  Future<bool> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String birthDate,
    required String gender,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      _isRegistrationInProgress = true; // Auth 리스너 오작동 방지

      // 1. 중복 확인
      final duplicates = await checkDuplicates(
        email: email,
        phoneNumber: phoneNumber,
      );

      if (duplicates['email'] == true) {
        _setError('이미 사용 중인 이메일입니다.');
        _setLoading(false);
        _isRegistrationInProgress = false;
        return false;
      }
      if (duplicates['phoneNumber'] == true) {
        _setError('이미 사용 중인 전화번호입니다.');
        _setLoading(false);
        _isRegistrationInProgress = false;
        return false;
      }

      // 2. Firebase Auth 계정 생성
      final userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user == null) {
        _setError('계정 생성에 실패했습니다.');
        _setLoading(false);
        _isRegistrationInProgress = false;
        return false;
      }

      // 3. 전화번호 선점 (개선된 로직 사용)
      final phoneReserved = await reservePhoneNumber(phoneNumber, user.uid);
      if (!phoneReserved) {
        try {
          await user.delete(); // 실패 시 계정 롤백
        } catch (_) {}
        _setError('전화번호 선점 실패: 이미 사용 중입니다.');
        _setLoading(false);
        _isRegistrationInProgress = false;
        return false;
      }

      // 4. 기본 사용자 정보 Firestore 저장 (프로필 미완성 상태)
      await _createBasicUserProfileSafely(user, phoneNumber, birthDate, gender);

      // 5. FCM 토큰 저장
      try {
        await _fcmService.retryTokenSave();
      } catch (_) {}

      // 성공 처리
      _isRegistrationInProgress = false;
      _setLoading(false);
      return true;

    } catch (e) {
      _isRegistrationInProgress = false;
      _setError(_getKoreanRegisterErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // 안전한 기본 사용자 프로필 생성
  Future<void> _createBasicUserProfileSafely(
      User firebaseUser,
      String phoneNumber,
      String birthDate,
      String gender,
      ) async {
    try {
      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
        nickname: '',  // 나중에 입력
        introduction: '',
        height: 0,
        activityArea: '',
        profileImages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: false, // 프로필 미완성 표시
      );

      // 재시도 로직으로 문서 생성
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await Future.delayed(Duration(milliseconds: 500 * attempt)); // 권한 전파 대기
          await _userService.createUser(newUser);
          break;
        } catch (e) {
          if (attempt == 3) rethrow;
        }
      }

      // 생성된 정보 로드
      await _loadUserData(firebaseUser.uid);
      if (_currentUserModel == null) {
        _currentUserModel = newUser; // 로드 실패 시 메모리 객체 사용
      }

    } catch (e) {
      throw Exception('사용자 정보 생성 실패: $e');
    }
  }

  // 닉네임 선점 (유령 데이터 처리 로직 포함)
  Future<bool> reserveNickname(String nickname, String uid) async {
    try {
      final normalizedNickname = nickname.trim().toLowerCase();
      final nicknameRef = _firebaseService.getDocument('nicknames/$normalizedNickname');

      final reservationData = {
        'uid': uid,
        'originalNickname': nickname.trim(),
        'reservedAt': FieldValue.serverTimestamp(),
        'type': 'nickname',
      };

      try {
        await nicknameRef.set(reservationData, SetOptions(merge: false));
        return true;
      } catch (e) {
        // 이미 존재할 경우, 실제 유저가 있는지 확인 (좀비 데이터 정리)
        final doc = await nicknameRef.get();
        if (doc.exists) {
          final existingUid = doc.data()?['uid'];
          if (existingUid != null) {
            final userExists = await _userService.userExists(existingUid);
            if (!userExists) {
              await nicknameRef.delete(); // 유령 데이터 삭제
              await nicknameRef.set(reservationData); // 재시도
              return true;
            }
          }
        }
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // 전화번호 선점 (유령 데이터 처리 로직 포함)
  Future<bool> reservePhoneNumber(String phoneNumber, String uid) async {
    try {
      final trimmedPhoneNumber = phoneNumber.trim();
      final phoneRef = _firebaseService.getDocument('phoneNumbers/$trimmedPhoneNumber');

      final reservationData = {
        'uid': uid,
        'originalPhoneNumber': trimmedPhoneNumber,
        'reservedAt': FieldValue.serverTimestamp(),
        'type': 'phoneNumber',
      };

      try {
        await phoneRef.set(reservationData, SetOptions(merge: false));
        return true;
      } catch (e) {
        // 이미 존재할 경우, 실제 유저가 있는지 확인 (좀비 데이터 정리)
        final doc = await phoneRef.get();
        if (doc.exists) {
          final existingUid = doc.data()?['uid'];
          if (existingUid != null) {
            final userExists = await _userService.userExists(existingUid);
            if (!userExists) {
              await phoneRef.delete(); // 유령 데이터 삭제
              await phoneRef.set(reservationData); // 재시도
              return true;
            }
          }
        }
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 기존 기능들 (로그인, 비밀번호 변경 등) - RESTORED
  // ===========================================================================

  // 이메일과 비밀번호로 로그인
  Future<void> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);

      if (userCredential.user != null) {
        await _loadUserData(userCredential.user!.uid);

        if (_currentUserModel != null) {
          notifyListeners();
          try {
            await _fcmService.retryTokenSave();
          } catch (_) {}
        } else {
          // 사용자 데이터 없음 (계정 복구 시도)
          await _attemptAccountRecovery(userCredential.user!);
          notifyListeners();
          if (_currentUserModel != null) {
            try { await _fcmService.retryTokenSave(); } catch (_) {}
          }
        }
      } else {
        _setError('로그인에 실패했습니다.');
      }

      _setLoading(false);
    } catch (e) {
      _setError(_getKoreanErrorMessage(e));
      _setLoading(false);
    }
  }

  // 기존 호환성 유지용
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await signInWithEmail(email, password);
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      _setLoading(true);
      if (onSignOutCallback != null) onSignOutCallback!();

      await _firebaseService.auth.signOut();

      _sub1?.cancel();
      _sub2?.cancel();
      _sub1 = null;
      _sub2 = null;
      _blockedUserIds = [];
      _currentUserModel = null;
      _tempRegistrationData = null;
      _tempProfileData = null;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // 비밀번호 변경
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인된 사용자가 없습니다.');
        return false;
      }

      if (newPassword.length < 6) {
        _setError('새 비밀번호는 최소 6자 이상이어야 합니다.');
        return false;
      }

      if (currentPassword == newPassword) {
        _setError('새 비밀번호는 현재 비밀번호와 달라야 합니다.');
        return false;
      }

      // 재인증
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // 변경
      await currentUser.updatePassword(newPassword);

      _setLoading(false);
      return true;
    } catch (e) {
      String errorMessage = '비밀번호 변경에 실패했습니다';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'wrong-password': errorMessage = '현재 비밀번호가 올바르지 않습니다.'; break;
          case 'weak-password': errorMessage = '새 비밀번호가 너무 약합니다.'; break;
          case 'requires-recent-login': errorMessage = '다시 로그인한 후 시도해주세요.'; break;
          default: errorMessage = '오류: ${e.message}';
        }
      }
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // 계정 삭제
// 계정 삭제 (방장 위임 후 삭제)
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인된 사용자가 없습니다.');
        _setLoading(false);
        return false;
      }

      final userId = currentUser.uid;
      final firestore = FirebaseFirestore.instance;

      // ---------------------------------------------------------
      // 1. Firebase Storage 프로필 사진 삭제
      // ---------------------------------------------------------
      try {
        final storageRef = FirebaseStorage.instance.ref().child('profile_images/$userId');
        final listResult = await storageRef.listAll();

        await Future.wait(
          listResult.items.map((item) => item.delete()),
        );
      } catch (e) {
        debugPrint('프로필 사진 삭제 실패 (무시함): $e');
      }

      // ---------------------------------------------------------
      // 2. 활동 내역 정리 (그룹 탈퇴 및 초대장 삭제)
      // ---------------------------------------------------------
      try {
        // (1) 내가 속한 그룹에서 나가기 (Service의 leaveGroup 사용 -> 방장 자동 위임됨)
        final groupQuery = await firestore
            .collection('groups')
            .where('memberIds', arrayContains: userId)
            .get();

        for (final doc in groupQuery.docs) {
          // 직접 삭제(delete)하지 않고 leaveGroup 호출
          // -> 남은 멤버가 있으면 방장이 위임되고, 없으면 삭제됨
          await _groupService.leaveGroup(doc.id, userId);
        }

        // (2) 매칭된 채팅방에서도 나가기
        final chatroomQuery = await firestore
            .collection('chatrooms')
            .where('participants', arrayContains: userId)
            .get();

        for (final doc in chatroomQuery.docs) {
          await _groupService.leaveGroup(doc.id, userId);
        }

        // (3) 초대장 삭제
        final sentInvites = await firestore
            .collection('invitations')
            .where('fromUserId', isEqualTo: userId)
            .get();

        final receivedInvites = await firestore
            .collection('invitations')
            .where('toUserId', isEqualTo: userId)
            .get();

        final batch = firestore.batch();
        for (var doc in sentInvites.docs) batch.delete(doc.reference);
        for (var doc in receivedInvites.docs) batch.delete(doc.reference);
        await batch.commit();

      } catch (e) {
        debugPrint('활동 내역 정리 중 일부 실패: $e');
      }

      // ---------------------------------------------------------
      // 3. 내 정보 데이터 삭제 (Users 컬렉션)
      // ---------------------------------------------------------
      try {
        await _userService.deleteUser(userId);
      } catch (e) {
        debugPrint('Firestore 사용자 데이터 삭제 실패: $e');
      }

      // ---------------------------------------------------------
      // 4. 선점된 데이터 삭제 (닉네임, 전화번호)
      // ---------------------------------------------------------
      try {
        if (_currentUserModel != null) {
          if (_currentUserModel!.nickname.isNotEmpty) {
            await _firebaseService.getDocument('nicknames/${_currentUserModel!.nickname}').delete();
          }
          if (_currentUserModel!.phoneNumber.isNotEmpty) {
            await _firebaseService.getDocument('phoneNumbers/${_currentUserModel!.phoneNumber}').delete();
          }
        }
      } catch (e) {
        debugPrint('선점 데이터 삭제 실패: $e');
      }

      // ---------------------------------------------------------
      // 5. Firebase Auth 계정 삭제 (최종)
      // ---------------------------------------------------------
      await currentUser.delete();

      // 로그아웃 처리 및 상태 정리
      if (onSignOutCallback != null) onSignOutCallback!();
      _currentUserModel = null;
      _tempRegistrationData = null;
      _tempProfileData = null;

      _setLoading(false);
      notifyListeners();
      return true;

    } catch (e) {
      // ... 에러 처리 코드 유지
      debugPrint('계정 삭제 중 오류: $e');

      String errorMessage = '계정 삭제에 실패했습니다.';
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          errorMessage = '보안을 위해 다시 로그인한 후 탈퇴해주세요.';
        } else {
          errorMessage = '오류: ${e.message}';
        }
      }
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // 계정 복구 (유령 계정 처리)
  Future<void> _attemptAccountRecovery(User firebaseUser) async {
    try {
      final userService = UserService();
      UserModel? existingUser;

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          existingUser = await userService.getUserById(firebaseUser.uid);
          if (existingUser != null) break;
        } catch (_) {
          if (attempt < 3) await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (existingUser != null) {
        _currentUserModel = existingUser;
        return;
      }

      // 복구용 기본 문서 생성
      final recoveredUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        phoneNumber: '',
        birthDate: '',
        gender: '',
        nickname: '',
        introduction: '',
        height: 0,
        activityArea: '',
        profileImages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: false,
      );

      await userService.createUser(recoveredUser);
      _currentUserModel = recoveredUser;

    } catch (e) {
      await _firebaseService.signOut();
      _currentUserModel = null;
      _setError('계정 정보 복구 실패. 다시 회원가입해주세요.');
    }
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData(String uid, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final currentUser = _firebaseService.currentUser;
        if (currentUser == null || currentUser.uid != uid) {
          _currentUserModel = null;
          notifyListeners();
          return;
        }
        _currentUserModel = await _userService.getUserById(uid);
        // (사용자 정보 로드 성공 시)
        if (_currentUserModel != null) {
          _startBlockedUsersListener(uid);
        }
        notifyListeners();
        return;
      } catch (e) {
        if (attempt == maxRetries) {
          _currentUserModel = null;
          notifyListeners();
          return;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

// 차단 목록 리스너 시작 함수
  void _startBlockedUsersListener(String uid) {
    // 기존 구독 모두 해제
    _sub1?.cancel();
    _sub2?.cancel();

    // 양방향 리스너 시작
    _listenToBothBlockStreams(uid);
  }

  // [신규 추가] 양방향(내가 차단/나를 차단) 스트림 관리 함수
  void _listenToBothBlockStreams(String uid) {
    List<String> myBlocks = [];   // 내가 차단한 사람 ID들
    List<String> blockedBy = [];  // 나를 차단한 사람 ID들

    // 내부 함수: 두 목록을 합쳐서 _blockedUserIds 업데이트
    void updateCombinedList() {
      // 두 리스트를 합치고 중복 제거 (Set 사용)
      final combined = {...myBlocks, ...blockedBy}.toList();
      _blockedUserIds = combined;
      notifyListeners(); // UI 갱신 알림
    }

    // 1. 내가 차단한 목록 구독 (blockerId가 '나'인 문서)
    _sub1 = _firebaseService.firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      myBlocks = snapshot.docs.map((doc) => doc['blockedId'] as String).toList();
      updateCombinedList();
    });

    // 2. 나를 차단한 목록 구독 (blockedId가 '나'인 문서)
    _sub2 = _firebaseService.firestore
        .collection('blocks')
        .where('blockedId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      blockedBy = snapshot.docs.map((doc) => doc['blockerId'] as String).toList();
      updateCombinedList();
    });
  }

  // 앱 시작 시 초기화
  Future<void> initialize() async {
    try {
      _setLoading(true);
      await _authStateSubscription?.cancel();

      final currentUser = _firebaseService.currentUser;
      if (currentUser != null) {
        await _loadUserData(currentUser.uid);
      }

      _authStateSubscription = _firebaseService.auth.authStateChanges().listen((user) async {
        if (user != null) {
          await _loadUserData(user.uid);
        } else {
          if (_isRegistrationInProgress) return;
          _currentUserModel = null;
          _tempRegistrationData = null;
          _tempProfileData = null;
          notifyListeners();
        }
      });

      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    }
  }

  // 사용자 정보 새로고침
  Future<void> refreshCurrentUser() async {
    if (_firebaseService.currentUser != null) {
      await _loadUserData(_firebaseService.currentUser!.uid);
    }
  }

  // FirebaseService 접근용
  FirebaseService get firebaseService => _firebaseService;

  // ===========================================================================
  // 중복 확인 관련
  // ===========================================================================
  Future<bool> isEmailDuplicate(String email) async {
    try {
      final result = await _functions.httpsCallable('checkEmail').call({'email': email});
      return result.data['isDuplicate'] == true;
    } catch (e) { return false; }
  }

  Future<bool> isNicknameDuplicate(String nickname) async {
    try {
      final result = await _functions.httpsCallable('checkNickname').call({'nickname': nickname});
      return result.data['isDuplicate'] == true;
    } catch (e) { return false; }
  }

  Future<bool> isPhoneNumberDuplicate(String phoneNumber) async {
    try {
      final result = await _functions.httpsCallable('checkPhoneNumber').call({'phoneNumber': phoneNumber});
      return result.data['isDuplicate'] == true;
    } catch (e) { return false; }
  }

  Future<Map<String, bool>> checkDuplicates({String? email, String? nickname, String? phoneNumber}) async {
    final results = <String, bool>{};
    if (email != null) results['email'] = await isEmailDuplicate(email);
    if (nickname != null) results['nickname'] = await isNicknameDuplicate(nickname);
    if (phoneNumber != null) results['phoneNumber'] = await isPhoneNumberDuplicate(phoneNumber);
    return results;
  }

  // ===========================================================================
  // 프로필 관련 (ProfileCreateView 호환성)
  // ===========================================================================

  // 임시 데이터 저장 (프로필 화면용)
  void saveTemporaryProfileData({
    required String nickname,
    required String introduction,
    required String height,
    required String activityArea,
    List<String>? profileImagePaths,
    List<String>? profileImageBytes,
    int? mainProfileIndex,
  }) {
    _tempProfileData = {
      'nickname': nickname,
      'introduction': introduction,
      'height': height,
      'activityArea': activityArea,
      'profileImagePaths': profileImagePaths ?? [],
      'profileImageBytes': profileImageBytes ?? [],
      'mainProfileIndex': mainProfileIndex ?? 0,
      'savedAt': DateTime.now().toIso8601String(),
    };
    notifyListeners();
  }

  // 임시 데이터 정리
  void clearTemporaryData() {
    _tempRegistrationData = null;
    _tempProfileData = null;
    notifyListeners();
  }

  void clearTemporaryProfileData() {
    _tempProfileData = null;
    notifyListeners();
  }

  // 프로필 완성 (새로워진 로직 - 이미 로그인된 유저용)
  Future<void> createCompleteUserProfile(
      String uid,
      String phoneNumber,
      String birthDate,
      String gender,
      String nickname,
      String introduction,
      int height,
      String activityArea,
      List<String> profileImages,
      ) async {
    try {
      final user = UserModel(
        uid: uid,
        email: _firebaseService.currentUser?.email ?? '',
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
        nickname: nickname,
        introduction: introduction,
        height: height,
        activityArea: activityArea,
        profileImages: profileImages,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: true,
      );
      await _userService.createUser(user);
      _currentUserModel = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // (호환성 유지용 빈 메서드들)
  void saveTemporaryRegistrationData({required String email, required String password, required String phoneNumber, required String birthDate, required String gender}) {}
  Future<void> completeRegistrationWithoutProfile() async {}
  Future<void> completeRegistrationWithProfile({required String nickname, required String introduction, required int height, required String activityArea, List<XFile>? profileImages}) async {}
}
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUserModel;
  bool _isInitialized = false;

  // 로그아웃 시 호출할 콜백
  VoidCallback? onSignOutCallback;

  // 임시 회원가입 데이터 저장
  Map<String, dynamic>? _tempRegistrationData;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic>? get tempRegistrationData => _tempRegistrationData;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);

      // 로그아웃 콜백 호출 (다른 컨트롤러들 정리)
      if (onSignOutCallback != null) {
        onSignOutCallback!();
      }

      await _firebaseService.signOut();
      _currentUserModel = null;

      _setLoading(false);
    } catch (e) {
      _setError('로그아웃에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 이메일과 비밀번호로 로그인
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // 사용자 정보 로드
        await _loadUserData(userCredential.user!.uid);
      }

      _setLoading(false);
    } catch (e) {
      _setError('로그인에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 이메일과 비밀번호로 회원가입
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // 기본 사용자 정보 생성 (프로필 미완성 상태)
        await _createUserProfile(userCredential.user!.uid, email);

        // 사용자 정보 로드하여 자동 로그인 상태로 만들기
        await _loadUserData(userCredential.user!.uid);
      }

      _setLoading(false);
    } catch (e) {
      _setError('회원가입에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 회원가입 데이터 임시 저장 (Firebase 계정 생성하지 않는 방식으로 구현했습니다.)
  void saveTemporaryRegistrationData({
    required String email,
    required String password,
    required String phoneNumber,
    required String birthDate,
    required String gender,
  }) {
    _tempRegistrationData = {
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      'gender': gender,
    };
    print('회원가입 데이터 임시 저장: $_tempRegistrationData');
    notifyListeners();
  }

  // 프로필 완성과 함께 실제 계정 생성
  Future<void> completeRegistrationWithProfile({
    required String nickname,
    required String introduction,
    required int height,
    required String activityArea,
    List<String>? profileImages,
  }) async {
    if (_tempRegistrationData == null) {
      _setError('회원가입 데이터가 없습니다.');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      final email = _tempRegistrationData!['email'];
      final password = _tempRegistrationData!['password'];
      
      print('최종 회원가입 시작: $email');
      
      // Firebase Auth 계정 생성
      final userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        print('Firebase Auth 사용자 생성 완료: ${userCredential.user!.uid}');
        
        // 인증 상태가 완전히 반영될 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 500));
        
        // ID 토큰 새로고침하여 권한 갱신
        try {
          await userCredential.user!.getIdToken(true);
          print('ID 토큰 새로고침 완료');
        } catch (e) {
          print('ID 토큰 새로고침 실패: $e');
        }
        
        // 완전한 사용자 정보와 함께 사용자 문서 생성
        await _createCompleteUserProfile(
          userCredential.user!.uid,
          email,
          _tempRegistrationData!['phoneNumber'],
          _tempRegistrationData!['birthDate'],
          _tempRegistrationData!['gender'],
          nickname,
          introduction,
          height,
          activityArea,
          profileImages ?? [],
        );

        print('Firestore 사용자 문서 생성 완료');

        // 사용자 정보 로드하여 자동 로그인 상태로 만들기
        await _loadUserData(userCredential.user!.uid);
        
        // 임시 데이터 정리
        _tempRegistrationData = null;
        
        print('사용자 데이터 로드 완료');
      }

      _setLoading(false);
    } catch (e) {
      print('최종 회원가입 실패: $e');
      _setError('회원가입에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 프로필 생성 없이 계정만 생성 (스킵 옵션)
  Future<void> completeRegistrationWithoutProfile() async {
    if (_tempRegistrationData == null) {
      _setError('회원가입 데이터가 없습니다.');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      final email = _tempRegistrationData!['email'];
      final password = _tempRegistrationData!['password'];
      
      print('프로필 스킵 회원가입 시작: $email');
      
      // Firebase Auth 계정 생성
      final userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        print('Firebase Auth 사용자 생성 완료: ${userCredential.user!.uid}');
        
        // 인증 상태가 완전히 반영될 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 500));
        
        // ID 토큰 새로고침하여 권한 갱신
        try {
          await userCredential.user!.getIdToken(true);
          print('ID 토큰 새로고침 완료');
        } catch (e) {
          print('ID 토큰 새로고침 실패: $e');
        }
        
        // 기본 사용자 정보만으로 사용자 문서 생성
        await _createUserProfileWithInfo(
          userCredential.user!.uid,
          email,
          _tempRegistrationData!['phoneNumber'],
          _tempRegistrationData!['birthDate'],
          _tempRegistrationData!['gender'],
        );

        print('Firestore 사용자 문서 생성 완료');

        // 사용자 정보 로드하여 자동 로그인 상태로 만들기
        await _loadUserData(userCredential.user!.uid);
        
        // 임시 데이터 정리
        _tempRegistrationData = null;
        
        print('사용자 데이터 로드 완료');
      }

      _setLoading(false);
    } catch (e) {
      print('프로필 스킵 회원가입 실패: $e');
      _setError('회원가입에 실패했습니다: $e');
      _setLoading(false);
    }
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData(String uid) async {
    try {
      final userService = UserService();
      _currentUserModel = await userService.getUserById(uid);
    } catch (e) {
      _setError('사용자 정보를 로드하는데 실패했습니다: $e');
    }
  }

  // 사용자 프로필 생성
  Future<void> _createUserProfile(String uid, String email) async {
    try {
      final userService = UserService();
      final user = UserModel(
        uid: uid,
        userId: email.split('@')[0], // 이메일에서 @ 앞부분을 userId로 사용
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

      await userService.createUser(user);
      _currentUserModel = user;
    } catch (e) {
      _setError('사용자 프로필 생성에 실패했습니다: $e');
    }
  }

  // 추가 정보와 함께 사용자 프로필 생성 (기본 정보만)
  Future<void> _createUserProfileWithInfo(
    String uid,
    String email,
    String phoneNumber,
    String birthDate,
    String gender,
  ) async {
    try {
      print('사용자 프로필 생성 시작: UID=$uid');
      
      // Firebase Auth의 현재 사용자 확인
      final currentUser = _firebaseService.currentUser;
      print('현재 Firebase Auth 사용자: ${currentUser?.uid}');
      
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('인증 상태가 일치하지 않습니다.');
      }
      
      final userService = UserService();
      final user = UserModel(
        uid: uid,
        userId: email.split('@')[0], // 이메일에서 @ 앞부분을 userId로 사용
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
        nickname: '',
        introduction: '',
        height: 0, // 프로필 생성 시 입력
        activityArea: '',
        profileImages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: false,
      );

      print('Firestore에 사용자 문서 생성 중...');
      await userService.createUser(user);
      _currentUserModel = user;
      print('사용자 프로필 생성 완료');
    } catch (e) {
      print('사용자 프로필 생성 오류: $e');
      _setError('사용자 프로필 생성에 실패했습니다: $e');
      rethrow;
    }
  }

  // 완전한 프로필 정보와 함께 사용자 문서 생성
  Future<void> _createCompleteUserProfile(
    String uid,
    String email,
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
      print('완전한 사용자 프로필 생성 시작: UID=$uid');
      
      // Firebase Auth의 현재 사용자 확인
      final currentUser = _firebaseService.currentUser;
      print('현재 Firebase Auth 사용자: ${currentUser?.uid}');
      
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('인증 상태가 일치하지 않습니다.');
      }
      
      final userService = UserService();
      final user = UserModel(
        uid: uid,
        userId: email.split('@')[0], // 이메일에서 @ 앞부분을 userId로 사용
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
        isProfileComplete: true, // 프로필 완성됨
      );

      print('Firestore에 완전한 사용자 문서 생성 중...');
      await userService.createUser(user);
      _currentUserModel = user;
      print('완전한 사용자 프로필 생성 완료');
    } catch (e) {
      print('완전한 사용자 프로필 생성 오류: $e');
      _setError('사용자 프로필 생성에 실패했습니다: $e');
      rethrow;
    }
  }

  // 로그인 상태 확인
  bool get isLoggedIn => _firebaseService.currentUser != null;

  // 현재 사용자 정보 설정
  void setCurrentUser(UserModel? user) {
    _currentUserModel = user;
    notifyListeners();
  }

  // 앱 시작 시 현재 로그인 상태 확인
  Future<void> initialize() async {
    try {
      _setLoading(true);

      // Firebase Auth 상태 변경 리스너 설정
      _firebaseService.auth.authStateChanges().listen((user) async {
        if (user != null) {
          // 로그인된 사용자가 있으면 정보 로드
          await _loadUserData(user.uid);
        } else {
          // 로그아웃된 상태
          _currentUserModel = null;
        }
        _isInitialized = true;
        _setLoading(false);
        notifyListeners();
      });
    } catch (e) {
      _setError('초기화에 실패했습니다: $e');
      _isInitialized = true;
      _setLoading(false);
    }
  }

  // 현재 사용자 정보 새로고침
  Future<void> refreshCurrentUser() async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser != null) {
        await _loadUserData(currentUser.uid);
      }
    } catch (e) {
      _setError('사용자 정보 새로고침에 실패했습니다: $e');
    }
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 임시 데이터 정리
  void clearTemporaryData() {
    _tempRegistrationData = null;
    notifyListeners();
  }
}

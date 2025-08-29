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
import '../services/realtime_chat_service.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUserModel;
  bool _isInitialized = false;

  // 로그아웃 시 호출할 콜백
  VoidCallback? onSignOutCallback;

  // 임시 회원가입 데이터 저장
  Map<String, dynamic>? _tempRegistrationData;
  
  // 임시 프로필 데이터 저장 (뒤로가기 시 복원용)
  Map<String, dynamic>? _tempProfileData;

  // Auth 상태 변경 리스너 (중복 방지용)
  StreamSubscription<User?>? _authStateSubscription;

  // 회원가입 진행 중 플래그 (authStateChanges 리스너 오작동 방지)
  bool _isRegistrationInProgress = false;

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

  // Firebase Auth 에러를 한국어로 변환 (로그인용)
  String _getKoreanErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return '등록되지 않은 아이디입니다. 아이디를 확인하거나 회원가입을 진행해주세요.';
        case 'wrong-password':
          return '비밀번호가 올바르지 않습니다. 다시 확인해주세요.';
        case 'invalid-email':
          return '올바르지 않은 이메일 형식입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다. 고객센터에 문의해주세요.';
        case 'too-many-requests':
          return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
        case 'invalid-credential':
          return '아이디 또는 비밀번호가 올바르지 않습니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        case 'email-already-in-use':
          return '이미 사용 중인 이메일입니다.';
        case 'weak-password':
          return '비밀번호가 너무 간단합니다. 더 복잡한 비밀번호를 사용해주세요.';
        default:
          return '로그인 중 오류가 발생했습니다. 아이디와 비밀번호를 확인해주세요.';
      }
    }
    return '로그인 중 오류가 발생했습니다. 다시 시도해주세요.';
  }

  // Firebase Auth 에러를 한국어로 변환 (회원가입용)
  String _getKoreanRegisterErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return '이미 사용 중인 아이디입니다. 다른 아이디를 사용해주세요.';
        case 'weak-password':
          return '비밀번호가 너무 간단합니다. 8자 이상의 복잡한 비밀번호를 사용해주세요.';
        case 'invalid-email':
          return '올바르지 않은 아이디 형식입니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        case 'too-many-requests':
          return '회원가입 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
        case 'operation-not-allowed':
          return '이메일/비밀번호 회원가입이 비활성화되어 있습니다. 관리자에게 문의해주세요.';
        default:
          return '회원가입 중 오류가 발생했습니다. 입력 정보를 확인해주세요.';
      }
    }
    return '회원가입 중 오류가 발생했습니다. 다시 시도해주세요.';
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);
      
      debugPrint('=== 로그아웃 시작 ===');
      debugPrint('현재 Firebase Auth 상태: ${_firebaseService.currentUser?.uid}');

      // 로그아웃 콜백 호출 (다른 컨트롤러들 정리)
      if (onSignOutCallback != null) {
        onSignOutCallback!();
      }

      // Firebase 로그아웃
      debugPrint('Firebase Auth 로그아웃 시작');
      await _firebaseService.signOut();
      debugPrint('Firebase Auth 로그아웃 완료');
      
      // Firebase Auth 상태 확인
      debugPrint('로그아웃 후 Firebase Auth 상태: ${_firebaseService.currentUser?.uid ?? "null"}');

      // 로컬 상태 정리 (Firebase 로그아웃 후 처리)
      debugPrint('🧹 로컬 상태 정리 시작');
      _currentUserModel = null;
      _tempRegistrationData = null;
      _tempProfileData = null;
      debugPrint('로컬 상태 정리 완료');

      _setLoading(false);
      
      // 상태 변경 알림 (UI 즉시 업데이트를 위해)
      notifyListeners();
      
      debugPrint('=== 로그아웃 프로세스 완료 ===');
      debugPrint('최종 로그인 상태: $isLoggedIn');
    } catch (e) {
      debugPrint('로그아웃 실패: $e');
      _setError('로그아웃에 실패했습니다: $e');
      _setLoading(false);
      rethrow; // 에러를 다시 던져서 호출하는 곳에서 처리할 수 있도록
    }
  }

  // 리소스 정리
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
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

      // 새 비밀번호 유효성 검사
      if (newPassword.length < 6) {
        _setError('새 비밀번호는 최소 6자 이상이어야 합니다.');
        return false;
      }

      // 현재 비밀번호와 동일한지 확인
      if (currentPassword == newPassword) {
        _setError('새 비밀번호는 현재 비밀번호와 달라야 합니다.');
        return false;
      }

      // 1. 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);

      // 2. 새 비밀번호로 변경
      await currentUser.updatePassword(newPassword);

      _setLoading(false);
      return true;
    } catch (e) {
      String errorMessage = '비밀번호 변경에 실패했습니다';
      
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'wrong-password':
            errorMessage = '현재 비밀번호가 올바르지 않습니다.';
            break;
          case 'weak-password':
            errorMessage = '새 비밀번호가 너무 약합니다. 더 강한 비밀번호를 사용해주세요.';
            break;
          case 'requires-recent-login':
            errorMessage = '보안을 위해 다시 로그인한 후 비밀번호를 변경해주세요.';
            break;
          default:
            errorMessage = '비밀번호 변경에 실패했습니다: ${e.message}';
        }
      } else {
        errorMessage = '비밀번호 변경에 실패했습니다: $e';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // 계정 삭제 (Admin 함수 사용)
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인된 사용자가 없습니다.');
        return false;
      }

      final userId = currentUser.uid;
      debugPrint('🔥 Admin 함수를 통한 계정 삭제 시작: $userId');

      // Firebase Functions의 deleteUserAccount 함수 호출
      final HttpsCallable callable = _functions.httpsCallable('deleteUserAccount');
      
      try {
        final HttpsCallableResult result = await callable.call({
          'userId': userId,
        });

        debugPrint('🔥 Admin 함수 호출 성공: ${result.data}');

        // 함수 호출 성공 시 로컬 상태 정리
        if (result.data['success'] == true) {
          // 로그아웃 콜백 호출 (다른 컨트롤러들 정리)
          if (onSignOutCallback != null) {
            onSignOutCallback!();
          }

          // 로컬 상태 정리
          _currentUserModel = null;
          _tempRegistrationData = null;
          _tempProfileData = null;

          _setLoading(false);
          debugPrint('🔥 계정 삭제 완료: Admin 함수 통해 모든 데이터 정리됨');
          return true;
        } else {
          _setError(result.data['message'] ?? '계정 삭제에 실패했습니다.');
          _setLoading(false);
          return false;
        }
      } on FirebaseFunctionsException catch (functionsError) {
        debugPrint('🔥 Firebase Functions 에러: ${functionsError.code} - ${functionsError.message}');
        
        String errorMessage;
        switch (functionsError.code) {
          case 'unauthenticated':
            errorMessage = '인증이 필요합니다. 다시 로그인해주세요.';
            break;
          case 'permission-denied':
            errorMessage = '계정 삭제 권한이 없습니다.';
            break;
          case 'internal':
            errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
            break;
          default:
            errorMessage = '계정 삭제 중 오류가 발생했습니다: ${functionsError.message}';
        }
        
        _setError(errorMessage);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('🔥 계정 삭제 중 예상치 못한 오류: $e');
      
      String errorMessage;
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'requires-recent-login':
            errorMessage = '보안을 위해 다시 로그인한 후 계정을 삭제해주세요.';
            break;
          default:
            errorMessage = '계정 삭제에 실패했습니다: ${e.message}';
        }
      } else {
        errorMessage = '계정 삭제에 실패했습니다: $e';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // 이메일과 비밀번호로 로그인 (주 로그인 방식)
  Future<void> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);

      if (userCredential.user != null) {
        
        // 사용자 정보 로드
        await _loadUserData(userCredential.user!.uid);
        
        if (_currentUserModel != null) {
          
          // 상태 변경 알림 (UI 업데이트를 위해)
          notifyListeners();
          
        } else {
          // 사용자 데이터 없음
          await _attemptAccountRecovery(userCredential.user!);
          
          // 복구 후에도 상태 변경 알림
          notifyListeners();
        }
      } else {
        _setError('로그인에 실패했습니다.');
      }

      _setLoading(false);
    } catch (e) {
      debugPrint('이메일 로그인 에러: $e');
      _setError(_getKoreanErrorMessage(e));
      _setLoading(false);
    }
  }



  // 이메일과 비밀번호로 로그인 (기존 메서드는 새 메서드로 리다이렉트)
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await signInWithEmail(email, password);
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
        await _createUserProfile(userCredential.user!.uid);

        // 사용자 정보 로드하여 자동 로그인 상태로 만들기
        await _loadUserData(userCredential.user!.uid);
      }

      _setLoading(false);
    } catch (e) {
      _setError(_getKoreanRegisterErrorMessage(e));
      _setLoading(false);
    }
  }

  // 회원가입 데이터 임시 저장
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
    notifyListeners();
  }

  // 프로필 완성과 함께 실제 계정 생성
  Future<void> completeRegistrationWithProfile({
    required String nickname,
    required String introduction,
    required int height,
    required String activityArea,
    List<XFile>? profileImages,
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
      
      debugPrint('최종 회원가입 시작: $email');

      // 1단계: 중복 계정 확인 (이메일, nickname 확인)
      final duplicates = await checkDuplicates(
        email: email,
        nickname: nickname,
      );

      if (duplicates['email'] == true) {
        _setError('이미 사용 중인 이메일입니다.');
        _setLoading(false);
        return;
      }

      if (duplicates['nickname'] == true) {
        _setError('이미 사용 중인 닉네임입니다.');
        _setLoading(false);
        return;
      }
      
      // 2단계: Firebase Auth 계정 생성 (임시 UID 얻기 위해)
      final userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user == null) {
        _setError('계정 생성에 실패했습니다.');
        _setLoading(false);
        return;
      }
      
      final uid = userCredential.user!.uid;
      debugPrint('Firebase Auth 계정 생성 완료: $uid');
      
      // 3단계: 닉네임 선점 시도 (userId는 이메일과 동일하므로 사용자ID 선점 불필요)
      bool nicknameReserved = false;
      
      try {
        // 닉네임 선점  
        nicknameReserved = await reserveNickname(nickname, uid);
        if (!nicknameReserved) {
          throw Exception('닉네임 선점 실패: 이미 사용 중입니다.');
        }
        
      } catch (e) {
        // 선점 실패 시 정리
        await releaseAllReservations(uid, nickname: nickname);
        
        // Firebase Auth 계정도 삭제
        try {
          await userCredential.user!.delete();
        } catch (deleteError) {
          debugPrint('Firebase Auth 계정 삭제 실패: $deleteError');
        }
        
        _setError('회원가입 실패: $e');
        _setLoading(false);
        return;
      }

      // === 새로운 4단계: 안전한 완전 프로필 회원가입 ===
      try {
        debugPrint('🚀 완전 프로필 회원가입 시작: $uid');
        
        await _createCompleteUserProfileSafely(
          userCredential.user!,
          _tempRegistrationData!['phoneNumber'],
          _tempRegistrationData!['birthDate'],
          _tempRegistrationData!['gender'],
          nickname,
          introduction,
          height,
          activityArea,
          profileImages,
        );
        
        debugPrint('✅ 완전 프로필 회원가입 완료: $uid');
        _setLoading(false);
        
      } catch (profileError) {
        // 프로필 생성 실패 시 완전한 정리
        debugPrint('🧹 프로필 생성 실패 - 완전한 정리 시작: $profileError');
        
        await releaseAllReservations(uid, nickname: nickname);
        debugPrint('선점 해제 완료');
        
        // Firebase Auth 계정 삭제 (재시도 포함)
        bool authAccountDeleted = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            await userCredential.user!.delete();
            debugPrint('실패한 Firebase Auth 계정 삭제 완료 (시도 $attempt)');
            authAccountDeleted = true;
            break;
          } catch (deleteError) {
            debugPrint('Firebase Auth 계정 삭제 실패 (시도 $attempt): $deleteError');
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        }
        
        if (!authAccountDeleted) {
          debugPrint('Firebase Auth 계정 삭제 최종 실패 - 유령 계정 생성 위험');
        }
        
        throw profileError; // 상위 catch로 전달
      }

    } catch (e) {
      debugPrint('최종 회원가입 실패: $e');
      _setError(_getKoreanRegisterErrorMessage(e));
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
      
      // 회원가입 진행 중 플래그 설정 (authStateChanges 리스너 오작동 방지)
      _isRegistrationInProgress = true;
      
      final email = _tempRegistrationData!['email'];
      final password = _tempRegistrationData!['password'];
      final phoneNumber = _tempRegistrationData!['phoneNumber'];
      final birthDate = _tempRegistrationData!['birthDate'];
      final gender = _tempRegistrationData!['gender'];
      
      // 1단계: 중복 계정 확인 (이메일 확인)
      final duplicates = await checkDuplicates(
        email: email,
      );

      if (duplicates['email'] == true) {
        _setError('이미 사용 중인 이메일입니다.');
        _setLoading(false);
        _isRegistrationInProgress = false;
        return;
      }

      // 2단계: Firebase Auth 계정 생성/확인
      User? user;
      String uid;
      
      // 현재 Firebase Auth 사용자 확인
      final currentUser = _firebaseService.currentUser;
      if (currentUser != null && currentUser.email == email) {
        // 이미 로그인된 사용자가 동일한 이메일이면 재사용
        user = currentUser;
        uid = currentUser.uid;
      } else {
        // Firebase Auth 계정 생성
        final userCredential = await _firebaseService.auth
            .createUserWithEmailAndPassword(email: email, password: password);
        user = userCredential.user;
        if (user == null) {
          _setError('계정 생성에 실패했습니다.');
          _setLoading(false);
          _isRegistrationInProgress = false;
          return;
        }
        uid = user.uid;
        debugPrint('Firebase Auth 사용자 생성 완료: $uid');
      }

      // === 새로운 4단계: 안정적인 기본 정보 회원가입 ===
      try {
        debugPrint('🚀 기본 정보 회원가입 시작: $uid');
        
        await _createBasicUserProfileSafely(
          user,
          phoneNumber,
          birthDate, 
          gender,
        );
        
        debugPrint('✅ 기본 정보 회원가입 완료: $uid');
        _setLoading(false);
        _isRegistrationInProgress = false;
        
      } catch (profileError) {
        
        // 새로 생성한 계정인 경우에만 삭제 (재시도 포함)
        if (currentUser == null) {
          bool authAccountDeleted = false;
          for (int attempt = 1; attempt <= 3; attempt++) {
            try {
              await user!.delete();
              debugPrint('실패한 Firebase Auth 계정 삭제 완료 (시도 $attempt)');
              authAccountDeleted = true;
              break;
            } catch (deleteError) {
              debugPrint('Firebase Auth 계정 삭제 실패 (시도 $attempt): $deleteError');
              if (attempt < 3) {
                await Future.delayed(Duration(milliseconds: 500 * attempt));
              }
            }
          }
          
          if (!authAccountDeleted) {
            debugPrint('🚨 Firebase Auth 계정 삭제 최종 실패 - 유령 계정 생성 위험');
          }
        }
        
        throw profileError; // 상위 catch로 전달
      }

    } catch (e) {
      // 프로필 스킵 회원가입 실패
      _setError(_getKoreanRegisterErrorMessage(e));
      _setLoading(false);
      
      // 회원가입 실패 - 플래그 해제
      _isRegistrationInProgress = false;
    }
  }

  // 안전한 완전 사용자 프로필 생성 (새로운 로직)
  Future<void> _createCompleteUserProfileSafely(
    User firebaseUser,
    String phoneNumber,
    String birthDate,
    String gender,
    String nickname,
    String introduction,
    int height,
    String activityArea,
    List<XFile>? profileImages,
  ) async {
    try {
      debugPrint('🛡️ 안전한 완전 프로필 생성 시작: ${firebaseUser.uid}');
      
      final userService = UserService();
      
      // 1단계: 기존 사용자 문서 존재 여부 확인
      debugPrint('📡 기존 문서 확인 중...');
      final existingUser = await userService.getUserById(firebaseUser.uid);
      
      if (existingUser != null) {
        // 이미 문서가 있으면 업데이트
        _currentUserModel = existingUser;
        debugPrint('✅ 기존 사용자 문서 발견: ${existingUser.uid} - 업데이트 진행');
        // 여기서는 새로 생성하지 않고 기존 문서 사용
        return;
      }
      
      // 2단계: 프로필 이미지 업로드 (문서 생성 전)
      List<String> imageUrls = [];
      if (profileImages != null && profileImages.isNotEmpty) {
        debugPrint('📸 프로필 이미지 업로드 시작: ${profileImages.length}개');
        
        try {
          for (int i = 0; i < profileImages.length; i++) {
            final file = profileImages[i];
            
            // 파일 유효성 검사 및 압축
            final validatedFile = await _validateAndCompressImageFile(file);
            if (validatedFile == null) {
              debugPrint('⚠️ 유효하지 않은 이미지 파일 스킵: ${file.name}');
              continue;
            }
            
            final fileName = '${firebaseUser.uid}_profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

            // Firebase Storage에 업로드 (재시도 포함)
            final downloadUrl = await _uploadImageWithRetry(
              validatedFile, 
              'profile_images/${firebaseUser.uid}/$fileName',
              maxRetries: 3
            );
            
            if (downloadUrl != null) {
              imageUrls.add(downloadUrl);
              debugPrint('✅ 이미지 업로드 성공 ($i): $downloadUrl');
            } else {
              debugPrint('❌ 이미지 업로드 실패 ($i)');
            }
          }
          debugPrint('📸 이미지 업로드 완료: ${imageUrls.length}/${profileImages.length}');
          
        } catch (e) {
          debugPrint('❌ 이미지 업로드 중 오류: $e');
          imageUrls.clear(); // 실패 시 이미지 없이 진행
        }
      }
      
      // 3단계: 완전한 사용자 문서 생성
      debugPrint('📝 완전한 사용자 문서 생성 중...');
      
      final completeUser = UserModel(
        uid: firebaseUser.uid,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
        nickname: nickname,
        introduction: introduction,
        height: height,
        activityArea: activityArea,
        profileImages: imageUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: true, // 완전한 프로필
      );
      
      // 4단계: 안전한 문서 생성 (최대 5번 재시도)
      bool created = false;
      Exception? lastError;
      
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          debugPrint('📄 완전한 문서 생성 시도 $attempt/5');
          
          // 권한 전파 대기 (재시도마다 더 긴 대기)
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
          
          // ID 토큰 새로고침
          await firebaseUser.getIdToken(true);
          debugPrint('🔑 ID 토큰 새로고침 완료');
          
          // 사용자 문서 생성
          await userService.createUser(completeUser, maxRetries: 3);
          
          created = true;
          debugPrint('✅ 완전한 사용자 문서 생성 성공 (시도 $attempt)');
          break;
          
        } catch (e) {
          lastError = Exception('완전한 문서 생성 실패 (시도 $attempt): $e');
          debugPrint('❌ ${lastError.toString()}');
          
          if (attempt < 5) {
            // 다음 시도를 위한 추가 대기
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      
      if (!created) {
        throw lastError ?? Exception('완전한 문서 생성 실패 - 알 수 없는 오류');
      }
      
      // 5단계: 생성된 사용자 정보 로드 및 검증
      debugPrint('🔍 생성된 완전한 사용자 정보 로드 중...');
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await _loadUserData(firebaseUser.uid, maxRetries: 2);
          
          if (_currentUserModel != null) {
            debugPrint('✅ 완전한 사용자 정보 로드 성공 (시도 $attempt)');
            break;
          } else {
            debugPrint('❌ 완전한 사용자 정보 로드 실패 (시도 $attempt) - null 반환');
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        } catch (e) {
          debugPrint('❌ 완전한 사용자 정보 로드 실패 (시도 $attempt): $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      
      // 최종 검증: 사용자 정보가 제대로 로드되었는지 확인
      if (_currentUserModel == null) {
        // 로드 실패했지만 문서는 생성되었으므로 메모리에서라도 설정
        _currentUserModel = completeUser;
        debugPrint('⚠️ DB 로드 실패하여 메모리 객체 사용 (완전한 프로필)');
      }
      
      // 임시 데이터 정리
      _tempRegistrationData = null;
      
      debugPrint('🎉 완전한 프로필 생성 완료: 회원가입 성공');
      
    } catch (e) {
      debugPrint('💥 완전한 프로필 생성 최종 실패: $e');
      rethrow; // 상위에서 계정 정리 처리
    }
  }

  // 안전한 기본 사용자 프로필 생성 (새로운 로직)
  Future<void> _createBasicUserProfileSafely(
    User firebaseUser,
    String phoneNumber,
    String birthDate,
    String gender,
  ) async {
    try {
      debugPrint('🛡️ 안전한 기본 프로필 생성 시작: ${firebaseUser.uid}');
      
      final userService = UserService();
      
      // 1단계: 기존 사용자 문서 존재 여부 확인
      debugPrint('📡 기존 문서 확인 중...');
      final existingUser = await userService.getUserById(firebaseUser.uid);
      
      if (existingUser != null) {
        // 이미 문서가 있으면 그대로 사용
        _currentUserModel = existingUser;
        debugPrint('✅ 기존 사용자 문서 사용: ${existingUser.uid}');
        return;
      }
      
      // 2단계: 새 기본 사용자 문서 생성
      debugPrint('📝 새 기본 사용자 문서 생성 중...');
      
      final newUser = UserModel(
        uid: firebaseUser.uid,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        gender: gender,
        nickname: '',  // 빈 값 - 나중에 입력
        introduction: '',
        height: 0,     // 0 - 나중에 입력
        activityArea: '',
        profileImages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: false, // 기본 정보만 입력된 상태
      );
      
      // 3단계: 안전한 문서 생성 (최대 5번 재시도)
      bool created = false;
      Exception? lastError;
      
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          debugPrint('📄 문서 생성 시도 $attempt/5');
          
          // 권한 전파 대기 (재시도마다 더 긴 대기)
          await Future.delayed(Duration(milliseconds: 800 * attempt));
          
          // ID 토큰 새로고침
          await firebaseUser.getIdToken(true);
          debugPrint('🔑 ID 토큰 새로고침 완료');
          
          // 사용자 문서 생성
          await userService.createUser(newUser, maxRetries: 3);
          
          created = true;
          debugPrint('✅ 기본 사용자 문서 생성 성공 (시도 $attempt)');
          break;
          
        } catch (e) {
          lastError = Exception('문서 생성 실패 (시도 $attempt): $e');
          debugPrint('❌ ${lastError.toString()}');
          
          if (attempt < 5) {
            // 다음 시도를 위한 추가 대기
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      
      if (!created) {
        throw lastError ?? Exception('문서 생성 실패 - 알 수 없는 오류');
      }
      
      // 4단계: 생성된 사용자 정보 로드 및 검증
      debugPrint('🔍 생성된 사용자 정보 로드 중...');
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await _loadUserData(firebaseUser.uid, maxRetries: 2);
          
          if (_currentUserModel != null) {
            debugPrint('사용자 정보 로드 성공 (시도 $attempt)');
            break;
          } else {
            debugPrint('사용자 정보 로드 실패 (시도 $attempt) - null 반환');
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        } catch (e) {
          debugPrint('사용자 정보 로드 실패 (시도 $attempt): $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      
      // 최종 검증: 사용자 정보가 제대로 로드되었는지 확인
      if (_currentUserModel == null) {
        // 로드 실패했지만 문서는 생성되었으므로 메모리에서라도 설정
        _currentUserModel = newUser;
        debugPrint('DB 로드 실패하여 메모리 객체 사용');
      }
      
      // 임시 데이터 정리
      _tempRegistrationData = null;
      
      debugPrint('🎉 기본 프로필 생성 완료: 회원가입 성공');
      
    } catch (e) {
      debugPrint('💥 기본 프로필 생성 최종 실패: $e');
      rethrow; // 상위에서 계정 정리 처리
    }
  }

  // 계정 복구 시도 (새로운 로직)
  Future<void> _attemptAccountRecovery(User firebaseUser) async {
    try {
      debugPrint('계정 복구 시도: ${firebaseUser.uid} (${firebaseUser.email})');
      
      final userService = UserService();
      
      // 1단계: 한 번 더 사용자 문서 존재 여부 확인 (네트워크 재시도)
      debugPrint('1단계: 사용자 문서 재확인');
      UserModel? existingUser;
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          existingUser = await userService.getUserById(firebaseUser.uid);
          if (existingUser != null) {
            debugPrint('기존 사용자 문서 발견 (시도 $attempt)');
            break;
          }
          debugPrint('사용자 문서 없음 (시도 $attempt)');
        } catch (e) {
          debugPrint('문서 확인 실패 (시도 $attempt): $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      
      if (existingUser != null) {
        // 기존 문서가 있으면 복구 성공
        _currentUserModel = existingUser;
        notifyListeners(); // UI 업데이트
        return;
      }
      
      // 2단계: 유령 계정으로 판단 - 기본 사용자 문서 생성 시도
      debugPrint('유령 계정 감지 - 기본 문서 생성 시도');
      
      if (firebaseUser.email == null || firebaseUser.email!.isEmpty) {
        throw Exception('Firebase Auth 사용자 이메일 정보가 없습니다.');
      }
      
      // 최소한의 기본 사용자 문서 생성
      final recoveredUser = UserModel(
        uid: firebaseUser.uid,
        phoneNumber: '', // 빈 값 - 나중에 입력 필요
        birthDate: '',   // 빈 값 - 나중에 입력 필요  
        gender: '',      // 빈 값 - 나중에 입력 필요
        nickname: '',    // 빈 값 - 나중에 입력 필요
        introduction: '',
        height: 0,
        activityArea: '',
        profileImages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isProfileComplete: false, // 미완성 상태로 설정
      );
      
      debugPrint('📝 복구용 기본 문서 생성 시도');
      
      // 최대 3번 재시도로 문서 생성
      bool created = false;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          // 권한 전파 대기
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
          
          // ID 토큰 새로고침
          await firebaseUser.getIdToken(true);
          
          // 문서 생성
          await userService.createUser(recoveredUser, maxRetries: 3);
          created = true;
          debugPrint('복구용 기본 문서 생성 성공 (시도 $attempt)');
          break;
          
        } catch (e) {
          debugPrint('복구용 문서 생성 실패 (시도 $attempt): $e');
          if (attempt == 3) {
            debugPrint('💥 모든 복구 시도 실패');
            throw Exception('계정 복구에 실패했습니다: $e');
          }
        }
      }
      
      if (created) {
        _currentUserModel = recoveredUser;
        notifyListeners(); // UI 업데이트
      }
      
    } catch (e) {
      debugPrint('계정 복구 최종 실패: $e');
      
      // 복구 실패 시 로그아웃 후 재회원가입 유도 (기존 로직)
      await _firebaseService.signOut();
      _currentUserModel = null;
      _setError('계정 정보 복구에 실패했습니다. 회원가입을 다시 진행해주세요.');
      _setLoading(false);
    }
  }

  // 사용자 데이터 로드 (재시도 로직 포함) - 최적화
  Future<void> _loadUserData(String uid, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('사용자 데이터 로드 시작 (시도 $attempt/$maxRetries): UID=$uid');
        
        // Firebase Auth 상태 재확인
        final currentUser = _firebaseService.currentUser;
        if (currentUser == null || currentUser.uid != uid) {
          debugPrint('Firebase Auth 상태 불일치, 로드 중단');
          _currentUserModel = null;
          notifyListeners();
          return;
        }

        final userService = UserService();
        _currentUserModel = await userService.getUserById(uid);
        
        // 성공하면 루프 종료 (null이어도 정상적으로 로드된 것임)
        notifyListeners();
        return;
        
      } catch (e) {
        
        if (attempt == maxRetries) {
          // 최종 실패
          // 에러가 발생해도 로그인 상태는 유지
          _currentUserModel = null;
          notifyListeners();
          return;
        }
        
        // 재시도 전 잠시 대기 
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // 사용자 프로필 생성 (기본 빈 프로필)
  Future<void> _createUserProfile(String uid) async {
    try {
      final userService = UserService();
      final user = UserModel(
        uid: uid,
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
    String phoneNumber,
    String birthDate,
    String gender,
  ) async {
    try {
      // Firebase Auth의 현재 사용자 확인
      final currentUser = _firebaseService.currentUser;
      
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('인증 상태가 일치하지 않습니다.');
      }
      
      final userService = UserService();
      final user = UserModel(
        uid: uid,
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

      debugPrint('Firestore에 사용자 문서 생성 중...');
      debugPrint('생성할 사용자 정보: phone=${user.phoneNumber}, birth=${user.birthDate}, gender=${user.gender}');
      
      // "나중에 입력하기" 회원가입 - 최적화된 재시도 (속도 우선)
      // 최소 권한 전파 대기
      await Future.delayed(const Duration(milliseconds: 500));
      await userService.createUser(user, maxRetries: 2);
      _currentUserModel = user;
      debugPrint('사용자 프로필 생성 완료');
    } catch (e) {
      _setError('사용자 프로필 생성에 실패했습니다: $e');
      rethrow;
    }
  }

  // 완전한 프로필 정보와 함께 사용자 문서 생성
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
      // Firebase Auth의 현재 사용자 확인
      final currentUser = _firebaseService.currentUser;
      
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('인증 상태가 일치하지 않습니다.');
      }
      
      final userService = UserService();
      final user = UserModel(
        uid: uid,
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

      await userService.createUser(user);
      _currentUserModel = user;
    } catch (e) {
      _setError('사용자 프로필 생성에 실패했습니다: $e');
      rethrow;
    }
  }

  // FirebaseService getter (외부에서 접근 가능)
  FirebaseService get firebaseService => _firebaseService;

  // 현재 사용자 정보 설정
  void setCurrentUser(UserModel? user) {
    _currentUserModel = user;
    notifyListeners();
  }

  // 앱 시작 시 현재 로그인 상태 확인
  Future<void> initialize() async {
    try {
      _setLoading(true);
      debugPrint('AuthController 초기화 시작');

      // 기존 리스너가 있다면 취소
      await _authStateSubscription?.cancel();

      // 현재 Firebase Auth 상태 먼저 확인
      final currentUser = _firebaseService.currentUser;
      if (currentUser != null) {
        await _loadUserData(currentUser.uid);
      } else {
        _currentUserModel = null;
      }

      // Firebase Auth 상태 변경 리스너 설정 (중복 방지)
      _authStateSubscription = _firebaseService.auth.authStateChanges().listen((user) async {
        
        if (user != null) {
          // 로그인된 사용자가 있으면 정보 로드
          await _loadUserData(user.uid);
        } else {
          // 회원가입 진행 중일 때는 로그아웃 처리를 하지 않음 (계정 삭제 과정에서 발생하는 상태 변경)
          if (_isRegistrationInProgress) {
            return;
          }
          // 로그아웃된 상태 - 즉시 정리
          _currentUserModel = null;
          _tempRegistrationData = null;
          _tempProfileData = null;
          
          // 즉시 UI 업데이트
          notifyListeners();
        }
      }, onError: (error) {
        // debugPrint('Auth 상태 변경 리스너 오류: $error');
      });

      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('초기화에 실패했습니다: $e');
      _isInitialized = true;
      _setLoading(false);
      notifyListeners();
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

  // 에러 설정 (public으로 노출)
  void setError(String? error) {
    _setError(error);
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 이메일 중복 확인 (Firebase Auth 기반)
  Future<bool> isEmailDuplicate(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      
      // Firebase Auth fetchSignInMethodsForEmail 사용
      try {
        final signInMethods = await _firebaseService.auth.fetchSignInMethodsForEmail(normalizedEmail);
        if (signInMethods.isNotEmpty) {
          debugPrint('Firebase Auth에 이미 등록된 이메일: $normalizedEmail');
          return true;
        }
        
        return false;
      } catch (authError) {
        // Firebase Auth 오류 시에는 안전하게 false 반환 (회원가입 시 Firebase Auth에서 최종 확인됨)
        return false;
      }
    } catch (e) {
      debugPrint('이메일 중복 확인 오류: $e');
      // 오류 시에는 안전하게 false 반환 (Firebase Auth에서 최종 확인됨)
      return false;
    }
  }
  // 닉네임 중복 확인 (users 컬렉션 + 선점 시스템)
  Future<bool> isNicknameDuplicate(String nickname) async {
    try {
      final trimmedNickname = nickname.trim();
      
      // 1. users 컬렉션에서 실제 데이터 확인 (우선순위)
      final users = await _firebaseService.getCollection('users')
          .where('nickname', isEqualTo: trimmedNickname)
          .limit(1)
          .get();
      
      if (users.docs.isNotEmpty) {
        debugPrint('users 컬렉션에 이미 저장된 닉네임: $trimmedNickname');
        return true;
      }
      
      // 2. nicknames 컬렉션에서 선점 상태 확인 (보조)
      try {
        final normalizedNickname = trimmedNickname.toLowerCase();
        final nicknameDoc = await _firebaseService.getDocument('nicknames/$normalizedNickname').get();
        if (nicknameDoc.exists) {
          debugPrint('이미 선점된 닉네임: $normalizedNickname');
          return true;
        }
      } catch (reservationError) {
        debugPrint('선점 시스템 확인 오류 (무시함): $reservationError');
        // 선점 시스템 오류는 무시하고 users 컬렉션 결과만 사용
      }
      
      debugPrint('닉네임 중복 확인 완료: $trimmedNickname (사용 가능)');
      return false;
    } catch (e) {
      debugPrint('닉네임 중복 확인 오류: $e');
      // 오류 시에는 안전하게 false 반환
      return false;
    }
  }
  
  // 닉네임 선점
  Future<bool> reserveNickname(String nickname, String uid) async {
    try {
      final normalizedNickname = nickname.trim().toLowerCase();
      final reservationData = {
        'uid': uid,
        'originalNickname': nickname.trim(),
        'reservedAt': FieldValue.serverTimestamp(),
        'type': 'nickname',
      };
      
      await _firebaseService.getDocument('nicknames/$normalizedNickname').set(
        reservationData,
        SetOptions(merge: false),
      );
      
      debugPrint('닉네임 선점 성공: $normalizedNickname (uid: $uid)');
      return true;
    } catch (e) {
      debugPrint('닉네임 선점 실패: $nickname - $e');
      return false;
    }
  }
  

  
  // 닉네임 선점 해제
  Future<void> releaseNickname(String nickname, String uid) async {
    try {
      final normalizedNickname = nickname.trim().toLowerCase();
      final doc = await _firebaseService.getDocument('nicknames/$normalizedNickname').get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['uid'] == uid) {
          await _firebaseService.getDocument('nicknames/$normalizedNickname').delete();
          debugPrint('닉네임 선점 해제: $normalizedNickname (uid: $uid)');
        } else {
          debugPrint('닉네임 선점 해제 실패: 소유자가 아님 (uid: $uid)');
        }
      }
    } catch (e) {
      debugPrint('닉네임 선점 해제 오류: $nickname - $e');
    }
  }
  
  // 닉네임 선점 해제 (회원가입 실패 시 정리용)
  Future<void> releaseAllReservations(String uid, {String? nickname}) async {
    if (nickname != null) {
      await releaseNickname(nickname, uid);
    }
  }

  // 종합 중복 확인
  Future<Map<String, bool>> checkDuplicates({
    String? email,
    String? nickname,
  }) async {
    final results = <String, bool>{};
    
    if (email != null) {
      results['email'] = await isEmailDuplicate(email);
    }
    if (nickname != null) {
      results['nickname'] = await isNicknameDuplicate(nickname);
    }
    return results;
  }

  // 프로필 데이터 임시 저장
  void saveTemporaryProfileData({
    required String nickname,
    required String introduction,
    required String height,
    required String activityArea,
    List<String>? profileImagePaths,
    List<String>? profileImageBytes, // Base64 인코딩된 이미지 데이터
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

  // 프로필 데이터만 정리
  void clearTemporaryProfileData() {
    _tempProfileData = null;
    notifyListeners();
  }

  // 이미지 파일 유효성 검사 및 압축
  Future<XFile?> _validateAndCompressImageFile(XFile file) async {
    try {
      // 파일 형식 검사 (확장자와 MIME 타입 모두 확인)
      final fileName = file.name.toLowerCase();
      final mimeType = file.mimeType ?? '';
      
      // 지원하는 이미지 확장자
      final supportedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
      final hasValidExtension = supportedExtensions.any((ext) => fileName.endsWith(ext));
      
      // MIME 타입 확인 (null이거나 비어있을 경우 확장자로 판단)
      final hasValidMimeType = mimeType.isEmpty || mimeType.startsWith('image/');
      
      if (!hasValidExtension || !hasValidMimeType) {
        return null;
      }

      // 파일 크기 검사
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }

      // 바이트 헤더로 이미지 파일 검증 (추가 안전장치)
      if (!_isValidImageByHeader(bytes)) {
        return null;
      }

      // 5MB 이하면 원본 파일 반환
      if (bytes.length <= 5 * 1024 * 1024) {
        return file;
      }
      
      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) {
        return null;
      }

      // 압축된 파일을 임시 XFile로 생성
      final compressedFile = XFile.fromData(
        compressedBytes,
        name: file.name,
        mimeType: 'image/jpeg', // 압축 후 JPEG 형식으로 통일
      );
      
      return compressedFile;
    } catch (e) {
      debugPrint('파일 유효성 검사 및 압축 실패: $e');
      return null;
    }
  }

  // 이미지 압축 함수
  Future<Uint8List?> _compressImage(Uint8List originalBytes) async {
    try {
      // 이미지 디코딩
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        return null;
      }

      const targetSize = 5 * 1024 * 1024; // 5MB
      int quality = 85; // 초기 품질
      int maxWidth = originalImage.width;
      int maxHeight = originalImage.height;

      Uint8List? compressedBytes;

      // 품질을 점진적으로 낮추면서 압축
      while (quality >= 20) {
        // 크기가 너무 크면 이미지 크기도 줄임
        if (compressedBytes != null && compressedBytes.length > targetSize && 
            (maxWidth > 1000 || maxHeight > 1000)) {
          maxWidth = (maxWidth * 0.8).round();
          maxHeight = (maxHeight * 0.8).round();
        }

        // 이미지 리사이즈 (필요한 경우)
        img.Image resizedImage = originalImage;
        if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
          resizedImage = img.copyResize(
            originalImage,
            width: maxWidth,
            height: maxHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        // JPEG로 압축
        compressedBytes = Uint8List.fromList(
          img.encodeJpg(resizedImage, quality: quality)
        );

        // 목표 크기 이하이면 완료
        if (compressedBytes.length <= targetSize) {
          return compressedBytes;
        }

        // 품질을 10씩 낮춤
        quality -= 10;
      }

      // 최종적으로도 크기가 크면 크기를 더 줄임
      if (compressedBytes != null && compressedBytes.length > targetSize) {
        // 강제로 크기를 줄여서 재시도
        maxWidth = (originalImage.width * 0.6).round();
        maxHeight = (originalImage.height * 0.6).round();
        
        final finalImage = img.copyResize(
          originalImage,
          width: maxWidth,
          height: maxHeight,
          interpolation: img.Interpolation.linear,
        );

        compressedBytes = Uint8List.fromList(
          img.encodeJpg(finalImage, quality: 60)
        );

      }

      return compressedBytes;
    } catch (e) {
      return null;
    }
  }

  // 바이트 헤더로 이미지 파일 여부 확인
  bool _isValidImageByHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // JPEG
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    
    // PNG
    if (bytes.length >= 8 && 
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) return true;
    
    // GIF
    if (bytes.length >= 6 && 
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
        bytes[3] == 0x38 && (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61) return true;
    
    // BMP
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    
    // WebP
    if (bytes.length >= 12 && 
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return true;
    
    // TIFF
    if (bytes.length >= 4 && 
        ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
         (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A))) return true;
    
    return false;
  }

  // 기존 유효성 검사 함수도 유지 (하위 호환성)
  Future<bool> _validateImageFile(XFile file) async {
    final validatedFile = await _validateAndCompressImageFile(file);
    return validatedFile != null;
  }

  // 재시도 메커니즘이 포함된 이미지 업로드
  Future<String?> _uploadImageWithRetry(
    XFile file, 
    String storagePath, 
    {int maxRetries = 3}
  ) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        
        // 메타데이터 설정
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
          customMetadata: {
            'uploadedBy': _firebaseService.currentUser?.uid ?? 'unknown',
            'uploadTimestamp': DateTime.now().toIso8601String(),
          },
        );

        // 플랫폼별 업로드 처리
        late UploadTask uploadTask;
        if (kIsWeb) {
          // 웹에서는 XFile에서 bytes 사용
          final bytes = await file.readAsBytes();
          uploadTask = ref.putData(bytes, metadata);
        } else {
          // 모바일에서는 XFile을 File로 변환
          final ioFile = File(file.path);
          
          // 파일 존재 여부 확인
          if (!await ioFile.exists()) {
            // 바이트 데이터로 대체 시도
            final bytes = await file.readAsBytes();
            uploadTask = ref.putData(bytes, metadata);
          } else {
            uploadTask = ref.putFile(ioFile, metadata);
          }
        }

        // 업로드 진행 상황 모니터링
        uploadTask.snapshotEvents.listen((taskSnapshot) {
          final progress = (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        return downloadUrl;
        
      } catch (e) {
        
        if (attempt == maxRetries) {
          // 최종 실패
          return null;
        }
        
        // 재시도 전 잠시 대기 (지수 백오프)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    
    return null;
  }
}

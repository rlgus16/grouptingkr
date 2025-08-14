import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();

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
      
      // print('로그아웃 시작');

      // 먼저 로컬 상태 정리
      _currentUserModel = null;
      
      // 로그아웃 콜백 호출 (다른 컨트롤러들 정리)
      if (onSignOutCallback != null) {
        // print('로그아웃 콜백 호출');
        onSignOutCallback!();
      }

      // Firebase 로그아웃
      await _firebaseService.signOut();
      // print('Firebase 로그아웃 완료');

      _setLoading(false);
    } catch (e) {
      // print('로그아웃 실패: $e');
      _setError('로그아웃에 실패했습니다: $e');
      _setLoading(false);
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

      // print('비밀번호 변경 시작');

      // 1. 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);
      // print('재인증 성공');

      // 2. 새 비밀번호로 변경
      await currentUser.updatePassword(newPassword);
      // print('비밀번호 변경 완료');

      _setLoading(false);
      return true;
    } catch (e) {
      // print('비밀번호 변경 실패: $e');
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

  // 계정 삭제
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
      // print('계정 삭제 시작: $userId');

      // 1. 현재 사용자가 속한 그룹에서 제거
      if (_currentUserModel?.currentGroupId != null) {
        // print('그룹에서 사용자 제거 중...');
        await _groupService.leaveGroup(_currentUserModel!.currentGroupId!, userId);
      }

      // 2. 사용자와 관련된 초대들 정리
      // print('초대 데이터 정리 중...');
      try {
        final invitationsRef = _firebaseService.getCollection('invitations');
        
        // 사용자가 보낸 초대들 삭제
        final sentInvitations = await invitationsRef
            .where('fromUserId', isEqualTo: userId)
            .get();
        for (final doc in sentInvitations.docs) {
          await doc.reference.delete();
        }
        
        // 사용자가 받은 초대들 삭제
        final receivedInvitations = await invitationsRef
            .where('toUserId', isEqualTo: userId)
            .get();
        for (final doc in receivedInvitations.docs) {
          await doc.reference.delete();
        }
        
        // print('초대 데이터 정리 완료');
      } catch (e) {
        // print('초대 데이터 정리 실패 (계속 진행): $e');
      }

      // 3. 사용자가 작성한 메시지들 정리 (시스템 메시지는 제외)
      // print('메시지 데이터 정리 중...');
      try {
        final messagesRef = _firebaseService.getCollection('messages');
        final userMessages = await messagesRef
            .where('senderId', isEqualTo: userId)
            .where('type', isNotEqualTo: 'system')
            .get();
        
        for (final doc in userMessages.docs) {
          await doc.reference.delete();
        }
        
        // print('메시지 데이터 정리 완료');
      } catch (e) {
        // print('메시지 데이터 정리 실패 (계속 진행): $e');
      }

      // 4. Firebase Storage에서 프로필 이미지 삭제
      if (_currentUserModel?.profileImages != null && _currentUserModel!.profileImages.isNotEmpty) {
        // print('프로필 이미지 삭제 중...');
        for (final imageUrl in _currentUserModel!.profileImages) {
          if (imageUrl.startsWith('http')) {
            try {
              await FirebaseStorage.instance.refFromURL(imageUrl).delete();
            } catch (e) {
              // print('이미지 삭제 실패 (계속 진행): $e');
            }
          }
        }
      }

      // 5. Firestore에서 사용자 데이터 삭제
      // print('Firestore에서 사용자 데이터 삭제 중...');
      await _userService.deleteUser(userId);

      // 6. Firebase Authentication에서 계정 삭제
      // print('Firebase Auth에서 계정 삭제 중...');
      await currentUser.delete();

      // 7. 로컬 상태 정리
      _currentUserModel = null;

      // 로그아웃 콜백 호출 (다른 컨트롤러들 정리)
      if (onSignOutCallback != null) {
        onSignOutCallback!();
      }

      _setLoading(false);
      // print('계정 삭제 완료');
      return true;
    } catch (e) {
      // print('계정 삭제 실패: $e');
      String errorMessage = '계정 삭제에 실패했습니다';
      
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

  // 아이디와 비밀번호로 로그인 (아이디를 통해 이메일을 찾은 후 로그인)
  Future<void> signInWithUserIdAndPassword(String userId, String password) async {
    try {
      _setLoading(true);
      _setError(null);
      
      // 1. 아이디로 사용자 검색
      final userService = UserService();
      final users = await _firebaseService.getCollection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (users.docs.isEmpty) {
        _setError('등록되지 않은 아이디입니다. 아이디를 확인하거나 회원가입을 진행해주세요.');
        _setLoading(false);
        return;
      }

      // 2. 사용자의 이메일 가져오기
      final userData = users.docs.first.data() as Map<String, dynamic>;
      final email = userData['email'] as String?;
      
      if (email == null || email.isEmpty) {
        _setError('사용자 이메일 정보를 찾을 수 없습니다. 고객센터에 문의해주세요.');
        _setLoading(false);
        return;
      }

      // 3. 이메일과 비밀번호로 Firebase Auth 로그인
      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        
        // 사용자 정보 로드
        await _loadUserData(userCredential.user!.uid);
      }

      _setLoading(false);
    } catch (e) {
      _setError(_getKoreanErrorMessage(e));
      _setLoading(false);
    }
  }

  // 이메일과 비밀번호로 로그인 (기존 메서드는 유지)
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      // print('로그인 시도: email=$email');
      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // print('Firebase Auth 로그인 성공: UID=${userCredential.user!.uid}');
        // print('사용자 이메일: ${userCredential.user!.email}');
        
        // 사용자 정보 로드
        await _loadUserData(userCredential.user!.uid);
        
        if (_currentUserModel != null) {
          // print('로그인 완료: 사용자=${_currentUserModel!.nickname}');
        } else {
          // print('경고: Firebase Auth는 성공했지만 사용자 프로필을 찾을 수 없습니다');
        }
      }

      _setLoading(false);
    } catch (e) {
      // print('로그인 에러: $e');
      _setError(_getKoreanErrorMessage(e));
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
      _setError(_getKoreanRegisterErrorMessage(e));
      _setLoading(false);
    }
  }

  // 회원가입 데이터 임시 저장 (Firebase 계정 생성하지 않는 방식으로 구현했습니다.) -> 생명 주기 관리
  void saveTemporaryRegistrationData({
    required String userId,
    required String email,
    required String password,
    required String phoneNumber,
    required String birthDate,
    required String gender,
  }) {
    _tempRegistrationData = {
      'userId': userId,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      'gender': gender,
    };
    // print('회원가입 데이터 임시 저장: $_tempRegistrationData');
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
      
      // print('최종 회원가입 시작: $email');
      
      // Firebase Auth 계정 생성
      final userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // print('Firebase Auth 사용자 생성 완료: ${userCredential.user!.uid}');
        
        // 인증 상태가 완전히 반영될 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 500));
        
        // ID 토큰 새로고침하여 권한 갱신
        try {
          await userCredential.user!.getIdToken(true);
          // print('ID 토큰 새로고침 완료');
        } catch (e) {
          // print('ID 토큰 새로고침 실패: $e');
        }
        
        // 이미지 업로드 처리
        List<String> imageUrls = [];
        if (profileImages != null && profileImages.isNotEmpty) {
          try {
            // print('프로필 이미지 업로드 시작: ${profileImages.length}개');
            for (int i = 0; i < profileImages.length; i++) {
              final file = profileImages[i];
              final fileName = '${userCredential.user!.uid}_profile_$i.jpg';

              // print('Firebase Storage 업로드 시작: $fileName');

              // Firebase Storage에 업로드
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('profile_images')
                  .child(userCredential.user!.uid)
                  .child(fileName);

              // 플랫폼별 업로드 처리
              late UploadTask uploadTask;
              if (kIsWeb) {
                // 웹에서는 XFile에서 bytes 사용
                final bytes = await file.readAsBytes();
                uploadTask = ref.putData(bytes);
              } else {
                // 모바일에서는 XFile을 File로 변환
                final ioFile = File(file.path);
                uploadTask = ref.putFile(ioFile);
              }

              final snapshot = await uploadTask;
              final downloadUrl = await snapshot.ref.getDownloadURL();

              // print('Firebase Storage 업로드 성공: $downloadUrl');
              imageUrls.add(downloadUrl);
            }
            // print('모든 프로필 이미지 업로드 완료: ${imageUrls.length}개');
          } catch (e) {
            imageUrls.clear();
            _setError('이미지 업로드에 실패했습니다. 프로필은 생성되었으니 나중에 다시 업로드해주세요.');
          }
        }
        
        // 완전한 사용자 정보와 함께 사용자 문서 생성
        await createCompleteUserProfile(
          userCredential.user!.uid,
          _tempRegistrationData!['userId'],
          email,
          _tempRegistrationData!['phoneNumber'],
          _tempRegistrationData!['birthDate'],
          _tempRegistrationData!['gender'],
          nickname,
          introduction,
          height,
          activityArea,
          imageUrls,
        );

        // print('Firestore 사용자 문서 생성 완료');

        // 사용자 정보 로드하여 자동 로그인 상태로 만들기
        await _loadUserData(userCredential.user!.uid);
        
        // 임시 데이터 정리
        _tempRegistrationData = null;
        
        // print('사용자 데이터 로드 완료');
      }

      _setLoading(false);
    } catch (e) {
      // print('최종 회원가입 실패: $e');
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

      final email = _tempRegistrationData!['email'];
      final password = _tempRegistrationData!['password'];
      
      // print('프로필 스킵 회원가입 시작: $email');
      
      // 현재 Firebase Auth 사용자 확인
      final currentUser = _firebaseService.currentUser;
      
      User? user;
      if (currentUser != null && currentUser.email == email) {
        // 이미 로그인된 사용자가 동일한 이메일이면 재사용
        // print('기존 Firebase Auth 사용자 재사용: ${currentUser.uid}');
        user = currentUser;
      } else {
        // Firebase Auth 계정 생성
        // print('새로운 Firebase Auth 계정 생성 시도...');
        final userCredential = await _firebaseService.auth
            .createUserWithEmailAndPassword(email: email, password: password);
        user = userCredential.user;
        // print('Firebase Auth 사용자 생성 완료: ${user?.uid}');
      }

      if (user != null) {
        // 인증 상태가 완전히 반영될 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 500));
        
        // ID 토큰 새로고침하여 권한 갱신
        try {
          await user.getIdToken(true);
          // print('ID 토큰 새로고침 완료');
        } catch (e) {
          // print('ID 토큰 새로고침 실패: $e');
        }
        
        // Firestore에 사용자 문서가 이미 존재하는지 확인
        final userService = UserService();
        final existingUser = await userService.getUserById(user.uid);
        
        if (existingUser == null) {
          // 사용자 문서가 없으면 새로 생성 (프로필 미완성 상태)
          await _createUserProfileWithInfo(
            user.uid,
            _tempRegistrationData!['userId'],
            email,
            _tempRegistrationData!['phoneNumber'],
            _tempRegistrationData!['birthDate'],
            _tempRegistrationData!['gender'],
          );
          // print('새로운 Firestore 사용자 문서 생성 완료');
        } else {
          // print('기존 Firestore 사용자 문서 발견, 재사용: ${existingUser.nickname}');
          _currentUserModel = existingUser;
        }

        // print('Firestore 사용자 문서 생성 완료');

        // 사용자 정보 로드하여 자동 로그인 상태로 만들기
        await _loadUserData(user.uid);
        
        // 임시 데이터 정리
        _tempRegistrationData = null;

        // print('사용자 데이터 로드 완료');
      }

      _setLoading(false);
    } catch (e) {
      // print('프로필 스킵 회원가입 실패: $e');
      _setError(_getKoreanRegisterErrorMessage(e));
      _setLoading(false);
    }
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData(String uid) async {
    try {
      // print('사용자 데이터 로드 시작: UID=$uid');
      final userService = UserService();
      _currentUserModel = await userService.getUserById(uid);
      
      // 프로필이 완성되지 않은 사용자의 경우 null일 수 있음
      if (_currentUserModel == null) {
        // print('사용자 프로필이 존재하지 않습니다. "나중에 입력하기"로 스킵한 사용자일 수 있습니다.');
        // 이 경우에도 정상적으로 홈 화면에 진입할 수 있도록 함
      } else {
        // print('사용자 데이터 로드 성공: ${_currentUserModel!.nickname}');
      }
    } catch (e) {
      // print('사용자 데이터 로드 실패: $e');
      _setError('사용자 정보를 로드하는데 실패했습니다: $e');
    }
  }

  // 사용자 프로필 생성
  Future<void> _createUserProfile(String uid, String email) async {
    try {
      final userService = UserService();
      final user = UserModel(
        uid: uid,
        userId: '', // 기본 프로필 생성 시에는 userId를 빈 값으로 설정 (나중에 회원가입에서 설정)
        email: email,
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
    String userId,
    String email,
    String phoneNumber,
    String birthDate,
    String gender,
  ) async {
    try {
      // print('사용자 프로필 생성 시작: UID=$uid');
      
      // Firebase Auth의 현재 사용자 확인
      final currentUser = _firebaseService.currentUser;
      // print('현재 Firebase Auth 사용자: ${currentUser?.uid}');
      
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('인증 상태가 일치하지 않습니다.');
      }
      
      final userService = UserService();
      final user = UserModel(
        uid: uid,
        userId: userId, // 회원가입 시 입력받은 userId 사용
        email: email,
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

      // print('Firestore에 사용자 문서 생성 중...');
      await userService.createUser(user);
      _currentUserModel = user;
      // print('사용자 프로필 생성 완료');
    } catch (e) {
      // print('사용자 프로필 생성 오류: $e');
      _setError('사용자 프로필 생성에 실패했습니다: $e');
      rethrow;
    }
  }

  // 완전한 프로필 정보와 함께 사용자 문서 생성
  Future<void> createCompleteUserProfile(
    String uid,
    String userId,
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
      // print('완전한 사용자 프로필 생성 시작: UID=$uid');
      
      // Firebase Auth의 현재 사용자 확인
      final currentUser = _firebaseService.currentUser;
      // print('현재 Firebase Auth 사용자: ${currentUser?.uid}');
      
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('인증 상태가 일치하지 않습니다.');
      }
      
      final userService = UserService();
      final user = UserModel(
        uid: uid,
        userId: userId, // 회원가입 시 입력받은 userId 사용
        email: email,
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

  // 로그인 상태 확인
  bool get isLoggedIn => _firebaseService.currentUser != null;
  
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

  // 에러 설정 (public으로 노출)
  void setError(String? error) {
    _setError(error);
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

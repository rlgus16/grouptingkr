import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class ProfileController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 프로필 생성 (회원가입 시)
  Future<bool> createProfile({
    // String? userId,
    // String? phoneNumber,
    required String phoneNumber,
    required String nickname,
    required String birthDate,
    required String gender,
    required String introduction,
    required int height,
    required String activityArea,
    List<XFile>? profileImages,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인이 필요합니다.');
        return false;
      }

      // 이미지 업로드
      List<String> imageUrls = [];
      if (profileImages != null && profileImages.isNotEmpty) {
        try {
          for (int i = 0; i < profileImages.length; i++) {
            final file = profileImages[i];
            final fileName = '${currentUser.uid}_profile_$i.jpg';

            print('Firebase Storage 업로드 시작: $fileName');

            // Firebase Storage에 업로드
            final ref = FirebaseStorage.instance
                .ref()
                .child('profile_images')
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

            print('Firebase Storage 업로드 성공: $downloadUrl');
            imageUrls.add(downloadUrl);
          }
        } catch (e) {
          print('Firebase Storage 업로드 실패: $e');
          // Firebase Storage 실패 시 빈 배열로 처리 (나중에 다시 업로드할 수 있도록)
          imageUrls.clear();
          _setError('이미지 업로드에 실패했습니다. 프로필은 생성되었으니 나중에 다시 업로드해주세요.');
        }
      }
      // 기존 사용자 정보 가져오기
      final existingUser = await _userService.getUserById(currentUser.uid);
      if (existingUser == null) {
        _setError('기존 사용자 정보를 찾을 수 없습니다.');
        return false;
      }

      // 사용자 모델 업데이트
      final updatedUserModel = existingUser.copyWith(
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
        isProfileComplete: true,
      );

      // Firestore에 업데이트
      await _userService.updateUser(updatedUserModel);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('프로필 생성에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 프로필 업데이트
  Future<bool> updateProfile({
    required String nickname,
    required String introduction,
    required int height,
    required String activityArea,
    List<String>? profileImages,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인이 필요합니다.');
        return false;
      }

      // 현재 사용자 정보 가져오기
      final currentUserModel = await _userService.getUserById(currentUser.uid);
      if (currentUserModel == null) {
        _setError('사용자 정보를 찾을 수 없습니다.');
        return false;
      }

      // 업데이트된 사용자 모델 생성
      final updatedUser = currentUserModel.copyWith(
        nickname: nickname,
        introduction: introduction,
        height: height,
        activityArea: activityArea,
        profileImages: profileImages ?? currentUserModel.profileImages,
        updatedAt: DateTime.now(),
      );

      // Firestore에 업데이트
      await _userService.updateUser(updatedUser);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('프로필 업데이트에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 프로필 이미지 업데이트
  Future<bool> updateProfileImages(List<String> imageUrls) async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인이 필요합니다.');
        return false;
      }

      final currentUserModel = await _userService.getUserById(currentUser.uid);
      if (currentUserModel == null) {
        _setError('사용자 정보를 찾을 수 없습니다.');
        return false;
      }

      final updatedUser = currentUserModel.copyWith(
        profileImages: imageUrls,
        updatedAt: DateTime.now(),
      );

      await _userService.updateUser(updatedUser);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('이미지 업데이트에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 에러 클리어
  void clearError() {
    _setError(null);
  }

  // 프로필 이미지 정리 (유효하지 않은 로컬 경로 제거)
  Future<bool> cleanupProfileImages() async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        _setError('로그인이 필요합니다.');
        return false;
      }

      final currentUserModel = await _userService.getUserById(currentUser.uid);
      if (currentUserModel == null) {
        _setError('사용자 정보를 찾을 수 없습니다.');
        return false;
      }

      // 유효한 이미지 URL만 필터링 (http, https로 시작하는 것만)
      final validImages = currentUserModel.profileImages.where((imageUrl) {
        return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
      }).toList();

      // 변경사항이 있다면 업데이트
      if (validImages.length != currentUserModel.profileImages.length) {
        final updatedUser = currentUserModel.copyWith(
          profileImages: validImages,
          updatedAt: DateTime.now(),
        );

        await _userService.updateUser(updatedUser);
        print('프로필 이미지 정리 완료: ${currentUserModel.profileImages.length} → ${validImages.length}');
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('프로필 이미지 정리에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }
}

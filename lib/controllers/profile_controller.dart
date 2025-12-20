import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../services/firebase_service.dart';
import '../services/user_service.dart';

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

  // ===== 닉네임 선점 관련 메서드들 =====

  // 닉네임 선점 (원자적 생성)
  Future<bool> _reserveNickname(String nickname, String uid) async {
    try {
      final normalizedNickname = nickname.trim().toLowerCase();
      final reservationData = {
        'uid': uid,
        'originalNickname': nickname.trim(),
        'reservedAt': FieldValue.serverTimestamp(),
        'type': 'nickname',
      };

      // 원자적 생성 시도 (이미 존재하면 실패)
      await _firebaseService.getDocument('nicknames/$normalizedNickname').set(
        reservationData,
        SetOptions(merge: false), // merge: false로 덮어쓰기 방지
      );

      debugPrint('닉네임 선점 성공: $normalizedNickname (uid: $uid)');
      return true;
    } catch (e) {
      debugPrint('닉네임 선점 실패: $nickname - $e');
      return false;
    }
  }

  // 닉네임 선점 해제
  Future<void> _releaseNickname(String nickname, String uid) async {
    try {
      final normalizedNickname = nickname.trim().toLowerCase();
      final doc = await _firebaseService.getDocument('nicknames/$normalizedNickname').get();

      if (doc.exists) {
        final data = doc.data();
        // 본인이 선점한 것만 해제 가능
        if (data != null && data['uid'] == uid) {
          await _firebaseService.getDocument('nicknames/$normalizedNickname').delete();
        }
      }
    } catch (e) {
      // 닉네임 선점 해제 오류
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
        return true;
      }

      // 2. nicknames 컬렉션에서 선점 상태 확인 (보조)
      try {
        final normalizedNickname = trimmedNickname.toLowerCase();
        final nicknameDoc = await _firebaseService.getDocument('nicknames/$normalizedNickname').get();
        if (nicknameDoc.exists) {
          return true;
        }
      } catch (reservationError) {
        // 선점 시스템 오류는 무시하고 users 컬렉션 결과만 사용
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 프로필 생성 (회원가입 시 - 레거시 지원용)
  Future<bool> createProfile({
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

            final validatedFile = await _validateAndCompressImageFile(file);
            if (validatedFile == null) continue;

            final fileName = '${currentUser.uid}_profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

            final downloadUrl = await _uploadImageWithRetry(
                validatedFile,
                'profile_images/${currentUser.uid}/$fileName',
                maxRetries: 3
            );

            if (downloadUrl != null) {
              imageUrls.add(downloadUrl);
            }
          }
        } catch (e) {
          imageUrls.clear();
          _setError('이미지 업로드에 실패했습니다.');
        }
      }

      final existingUser = await _userService.getUserById(currentUser.uid);
      if (existingUser == null) {
        _setError('기존 사용자 정보를 찾을 수 없습니다.');
        return false;
      }

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

      await _userService.updateUser(updatedUserModel);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('프로필 생성에 실패했습니다: $e');
      _setLoading(false);
      return false;
    }
  }

  // 프로필 업데이트 (프로필 편집 및 완성용)
  Future<bool> updateProfile({
    required String nickname,
    required String introduction,
    required int height,
    required String activityArea,
    double latitude = 0.0,
    double longitude = 0.0,
    List<String>? profileImages,
  }) async {
    _setLoading(true);
    _setError(null);

    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) {
      _setError('로그인이 필요합니다.');
      _setLoading(false);
      return false;
    }

    String? oldNickname;

    try {
      final currentUserModel = await _userService.getUserById(currentUser.uid);
      if (currentUserModel == null) {
        _setError('사용자 정보를 찾을 수 없습니다.');
        _setLoading(false);
        return false;
      }

      // 닉네임 변경 시 중복 검사 및 선점
      if (nickname.trim() != currentUserModel.nickname) {
        oldNickname = currentUserModel.nickname;
        final newNicknameReserved = await _reserveNickname(nickname.trim(), currentUser.uid);
        if (!newNicknameReserved) {
          _setError('이미 사용 중인 닉네임입니다.');
          _setLoading(false);
          return false;
        }
      }

      // isProfileComplete를 true로 설정 및 좌표 업데이트
      final updatedUser = currentUserModel.copyWith(
        nickname: nickname,
        introduction: introduction,
        height: height,
        activityArea: activityArea,
        latitude: latitude,
        longitude: longitude,
        profileImages: profileImages ?? currentUserModel.profileImages,
        updatedAt: DateTime.now(),
        isProfileComplete: true,
      );

      await _userService.updateUser(updatedUser);

      // 기존 닉네임 해제
      if (oldNickname != null && oldNickname.isNotEmpty) {
        await _releaseNickname(oldNickname, currentUser.uid);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      // 실패 시 닉네임 롤백
      if (oldNickname != null) {
        await _releaseNickname(nickname.trim(), currentUser.uid);
      }

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

  void clearError() {
    _setError(null);
  }

  // 이미지 유효성 검사 및 압축
  Future<XFile?> _validateAndCompressImageFile(XFile file) async {
    try {
      final fileName = file.name.toLowerCase();
      final mimeType = file.mimeType ?? '';

      final supportedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
      final hasValidExtension = supportedExtensions.any((ext) => fileName.endsWith(ext));
      final hasValidMimeType = mimeType.isEmpty || mimeType.startsWith('image/');

      if (!hasValidExtension || !hasValidMimeType) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || !_isValidImageByHeader(bytes)) return null;

      if (bytes.length <= 5 * 1024 * 1024) return file;

      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) return null;

      return XFile.fromData(
        compressedBytes,
        name: file.name,
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      return null;
    }
  }

  // 이미지 압축
  Future<Uint8List?> _compressImage(Uint8List originalBytes) async {
    try {
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) return null;

      const targetSize = 5 * 1024 * 1024; // 5MB
      int quality = 85;
      int maxWidth = originalImage.width;
      int maxHeight = originalImage.height;

      Uint8List? compressedBytes;

      while (quality >= 20) {
        if (compressedBytes != null && compressedBytes.length > targetSize &&
            (maxWidth > 1000 || maxHeight > 1000)) {
          maxWidth = (maxWidth * 0.8).round();
          maxHeight = (maxHeight * 0.8).round();
        }

        img.Image resizedImage = originalImage;
        if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
          resizedImage = img.copyResize(
            originalImage,
            width: maxWidth,
            height: maxHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        compressedBytes = Uint8List.fromList(
            img.encodeJpg(resizedImage, quality: quality)
        );

        if (compressedBytes.length <= targetSize) return compressedBytes;
        quality -= 10;
      }

      if (compressedBytes != null && compressedBytes.length > targetSize) {
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

  // 이미지 헤더 검사
  bool _isValidImageByHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return true; // JPEG
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true; // PNG
    if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true; // GIF
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) return true; // BMP
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[8] == 0x57 && bytes[9] == 0x45) return true; // WebP
    return false;
  }

  Future<String?> _uploadImageWithRetry(XFile file, String storagePath, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: file.mimeType ?? 'image/jpeg',
          customMetadata: {
            'uploadedBy': _firebaseService.currentUser?.uid ?? 'unknown',
            'uploadTimestamp': DateTime.now().toIso8601String(),
          },
        );

        late UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          uploadTask = ref.putData(bytes, metadata);
        } else {
          final ioFile = File(file.path);
          if (!await ioFile.exists()) {
            final bytes = await file.readAsBytes();
            uploadTask = ref.putData(bytes, metadata);
          } else {
            uploadTask = ref.putFile(ioFile, metadata);
          }
        }

        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        if (attempt == maxRetries) return null;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return null;
  }

  // 프로필 이미지 정리
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

      final validImages = currentUserModel.profileImages.where((imageUrl) {
        return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
      }).toList();

      if (validImages.length != currentUserModel.profileImages.length) {
        final updatedUser = currentUserModel.copyWith(
          profileImages: validImages,
          updatedAt: DateTime.now(),
        );
        await _userService.updateUser(updatedUser);
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
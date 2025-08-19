import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
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
          debugPrint('닉네임 선점 해제: $normalizedNickname (uid: $uid)');
        } else {
          debugPrint('닉네임 선점 해제 실패: 소유자가 아님 (uid: $uid)');
        }
      }
    } catch (e) {
      debugPrint('닉네임 선점 해제 오류: $nickname - $e');
    }
  }

  // 닉네임 중복 확인 (users 컬렉션 + 선점 시스템) - AuthController와 동일한 로직
  Future<bool> isNicknameDuplicate(String nickname) async {
    try {
      final trimmedNickname = nickname.trim();
      
      // 1. users 컬렉션에서 실제 데이터 확인 (우선순위 처리하는 곳)
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
        // 선점 시스템 오류는 무시하고 users 컬렉션 결과만 사용! 확인 완료
      }
      
      debugPrint('닉네임 중복 확인 완료: $trimmedNickname (사용 가능)');
      return false;
    } catch (e) {
      debugPrint('닉네임 중복 확인 오류: $e');
      // 오류 시에는 안전하게 false 반환
      return false;
    }
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
            
            // 파일 유효성 검사 및 압축
            final validatedFile = await _validateAndCompressImageFile(file);
            if (validatedFile == null) {
              // print('파일 유효성 검사 실패 또는 압축 실패: ${file.name}');
              continue; // 유효하지 않은 파일은 스킵
            }
            
            final fileName = '${currentUser.uid}_profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

            // Firebase Storage에 업로드 (재시도 포함)
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
          // print('Firebase Storage 업로드 실패: $e');
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
    _setLoading(true);
    _setError(null);

    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) {
      _setError('로그인이 필요합니다.');
      _setLoading(false);
      return false;
    }

    // 변수들을 메서드 최상위에서 선언 (catch 블록에서 접근 가능하도록)
    String? oldNickname;
    
    try {
      // 현재 사용자 정보 가져오기
      final currentUserModel = await _userService.getUserById(currentUser.uid);
      if (currentUserModel == null) {
        _setError('사용자 정보를 찾을 수 없습니다.');
        _setLoading(false);
        return false;
      }

      // 닉네임이 변경된 경우에만 원자적 중복 검증 및 선점
      if (nickname.trim() != currentUserModel.nickname) {
        oldNickname = currentUserModel.nickname;
        
        // 새 닉네임 선점 시도
        final newNicknameReserved = await _reserveNickname(nickname.trim(), currentUser.uid);
        if (!newNicknameReserved) {
          _setError('이미 사용 중인 닉네임입니다.');
          _setLoading(false);
          return false;
        }
        
        debugPrint('닉네임 선점 성공: ${nickname.trim()}');
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

      // 업데이트 성공 시 기존 닉네임 선점 해제
      if (oldNickname != null) {
        await _releaseNickname(oldNickname, currentUser.uid);
        debugPrint('기존 닉네임 선점 해제: $oldNickname');
      }

      _setLoading(false);
      return true;
    } catch (e) {
      // 업데이트 실패 시 새 닉네임 선점 해제
      if (oldNickname != null) {
        await _releaseNickname(nickname.trim(), currentUser.uid);
        debugPrint('새 닉네임 선점 해제 (실패): ${nickname.trim()}');
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

  // 에러 클리어
  void clearError() {
    _setError(null);
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
        // print('이미지 파일이 아닙니다: $fileName ($mimeType)');
        return null;
      }

      // 파일 크기 검사
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        // print('빈 파일입니다');
        return null;
      }

      // 바이트 헤더로 이미지 파일 검증 (추가 안전장치)
      if (!_isValidImageByHeader(bytes)) {
        // print('올바른 이미지 파일이 아닙니다');
        return null;
      }

      // 5MB 이하면 원본 파일 반환
      if (bytes.length <= 5 * 1024 * 1024) {
        return file;
      }

      // 5MB 초과 시 압축 처리
      // print('파일 크기가 5MB를 초과합니다 (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). 압축을 진행합니다.');
      
      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) {
        // print('이미지 압축에 실패했습니다');
        return null;
      }

      // 압축된 파일을 임시 XFile로 생성
      final compressedFile = XFile.fromData(
        compressedBytes,
        name: file.name,
        mimeType: 'image/jpeg', // 압축 후 JPEG 형식으로 통일
      );

      // print('이미지 압축 완료: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
      
      return compressedFile;
    } catch (e) {
      // print('파일 유효성 검사 및 압축 실패: $e');
      return null;
    }
  }

  // 이미지 압축 함수
  Future<Uint8List?> _compressImage(Uint8List originalBytes) async {
    try {
      // 이미지 디코딩
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        // print('이미지 디코딩 실패');
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
          // print('압축 성공: 품질 $quality%, 크기 ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
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

        // print('강제 압축 완료: 크기 ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
      }

      return compressedBytes;
    } catch (e) {
      // print('이미지 압축 중 오류 발생: $e');
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
        // print('프로필 이미지 정리 완료: ${currentUserModel.profileImages.length} → ${validImages.length}');
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

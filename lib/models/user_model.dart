import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid; //  UID - 사용자의 고유 식별자
  final String email; // 이메일 주소
  final String phoneNumber;
  final String birthDate; // YYYYMMDD format
  final String gender; // '남' or '여'
  final String nickname;
  final String introduction;
  final int height;
  final String activityArea;
  final List<String> profileImages;
  final String? currentGroupId;
  final String? fcmToken; // FCM 푸시 알림 토큰
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isProfileComplete;
  final double latitude;
  final double longitude;
  final int tingBalance; // Ting 잔액

  // 알림 설정 필드
  final bool matchingNotification;
  final bool invitationNotification;
  final bool chatNotification;

  UserModel({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.birthDate,
    required this.gender,
    required this.nickname,
    required this.introduction,
    required this.height,
    required this.activityArea,
    required this.profileImages,
    this.currentGroupId,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
    required this.isProfileComplete,
    this.matchingNotification = true,
    this.invitationNotification = true,
    this.chatNotification = true,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.tingBalance = 0,
  });

  // 나이 계산
  int get age {
    if (birthDate.length != 8) return 0;
    try {
      final birth = DateTime(
        int.parse(birthDate.substring(0, 4)),
        int.parse(birthDate.substring(4, 6)),
        int.parse(birthDate.substring(6, 8)),
      );
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  // 메인 프로필 이미지
  String? get mainProfileImage {
    return profileImages.isNotEmpty ? profileImages.first : null;
  }

  // Firestore에서 데이터 가져오기
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();

    // 데이터가 null이거나 Map이 아닌 경우 에러 방지
    if (data == null) {
      throw Exception('Firestore 문서 데이터가 null입니다');
    }

    final dataMap = data as Map<String, dynamic>;
    return UserModel(
      uid: doc.id, // Firestore 문서 ID uid로 사용
      email: dataMap['email'] ?? '', // 이메일 필드
      phoneNumber: dataMap['phoneNumber'] ?? '',
      birthDate: dataMap['birthDate'] ?? '',
      gender: dataMap['gender'] ?? '',
      nickname: dataMap['nickname'] ?? '',
      introduction: dataMap['introduction'] ?? '',
      height: dataMap['height'] ?? 0,
      activityArea: dataMap['activityArea'] ?? '',
      profileImages: List<String>.from(dataMap['profileImages'] ?? []),
      currentGroupId: dataMap['currentGroupId'],
      fcmToken: dataMap['fcmToken'],
      createdAt: (dataMap['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      updatedAt: (dataMap['updatedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      isProfileComplete: dataMap['isProfileComplete'] ?? false,
      matchingNotification: dataMap['matchingNotification'] ?? true,
      invitationNotification: dataMap['invitationNotification'] ?? true,
      chatNotification: dataMap['chatNotification'] ?? true,
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      tingBalance: dataMap['tingBalance'] ?? 0,
    );
  }

  // Firestore에 저장할 데이터 형태로 변환
  // 주의: fcmToken은 null인 경우 제외하여 기존 값을 덮어쓰지 않도록 함
  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      'gender': gender,
      'nickname': nickname,
      'introduction': introduction,
      'height': height,
      'activityArea': activityArea,
      'profileImages': profileImages,
      'currentGroupId': currentGroupId,
      // fcmToken은 FCMService에서 별도로 관리하므로 여기서는 제외
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isProfileComplete': isProfileComplete,
      'matchingNotification': matchingNotification,
      'invitationNotification': invitationNotification,
      'chatNotification': chatNotification,
      'latitude': latitude,
      'longitude': longitude,
      'tingBalance': tingBalance,
    };
    
    // fcmToken이 null이 아닌 경우에만 포함 (기존 값 덮어쓰기 방지)
    if (fcmToken != null) {
      data['fcmToken'] = fcmToken;
    }
    
    return data;
  }


  // 사용자 정보 업데이트용 copyWith 메서드
  UserModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? birthDate,
    String? gender,
    String? nickname,
    String? introduction,
    int? height,
    String? activityArea,
    List<String>? profileImages,
    String? currentGroupId,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isProfileComplete,
    bool? matchingNotification,
    bool? invitationNotification,
    bool? chatNotification,
    double? latitude,
    double? longitude,
    int? tingBalance,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      nickname: nickname ?? this.nickname,
      introduction: introduction ?? this.introduction,
      height: height ?? this.height,
      activityArea: activityArea ?? this.activityArea,
      profileImages: profileImages ?? this.profileImages,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      matchingNotification: matchingNotification ?? this.matchingNotification,
      invitationNotification: invitationNotification ?? this.invitationNotification,
      chatNotification: chatNotification ?? this.chatNotification,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tingBalance: tingBalance ?? this.tingBalance,
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String userId; // 로그인 아이디
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

  UserModel({
    required this.uid,
    required this.userId,
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
  });

  // 나이 계산
  int get age {
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
      uid: doc.id,
      userId: dataMap['userId'] ?? '',
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
      createdAt: (dataMap['createdAt'] as Timestamp).toDate(),
      updatedAt: (dataMap['updatedAt'] as Timestamp).toDate(),
      isProfileComplete: dataMap['isProfileComplete'] ?? false,
    );
  }

  // Firestore에 저장할 데이터 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid, // Firestore 보안 규칙 호환성을 위해 uid 필드 추가
      'userId': userId,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate,
      'gender': gender,
      'nickname': nickname,
      'introduction': introduction,
      'height': height,
      'activityArea': activityArea,
      'profileImages': profileImages,
      'currentGroupId': currentGroupId,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isProfileComplete': isProfileComplete,
    };
  }

  // 사용자 정보 업데이트용 copyWith 메서드
  UserModel copyWith({
    String? uid,
    String? userId,
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
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
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
    );
  }
}

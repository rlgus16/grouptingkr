import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupStatus { active, matched, inactive, waiting, matching }

class GroupModel {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final String? description;
  final GroupStatus status;
  final String? matchedGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int maxMembers;
  final String preferredGender;

  // 기존 나이 관련 필드
  final int minAge;
  final int maxAge;
  final int averageAge;

  // 키 관련 필드
  final int minHeight;      // 선호 최소 키
  final int maxHeight;      // 선호 최대 키
  final int averageHeight;  // 우리 그룹 평균 키

  final String groupGender;

  // 거리 필드 선언
  final int maxDistance;

  // 그룹 위치 좌표 (방장 기준)
  final double latitude;
  final double longitude;


  GroupModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    this.description,
    required this.status,
    this.matchedGroupId,
    required this.createdAt,
    required this.updatedAt,
    this.maxMembers = 5,
    this.preferredGender = '상관없음',
    this.minAge = 19,
    this.maxAge = 60,
    this.averageAge = 20,
    this.minHeight = 150,
    this.maxHeight = 190,
    this.averageHeight = 170,
    this.groupGender = '혼성',
    this.maxDistance = 100,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      description: data['description'],
      status: GroupStatus.values.firstWhere(
            (e) => e.toString().split('.').last == data['status'],
        orElse: () => GroupStatus.active,
      ),
      matchedGroupId: data['matchedGroupId'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      maxMembers: data['maxMembers'] ?? 5,
      preferredGender: data['preferredGender'] ?? '상관없음',
      minAge: data['minAge'] ?? 19,
      maxAge: data['maxAge'] ?? 40,
      averageAge: data['averageAge'] ?? 20,
      minHeight: data['minHeight'] ?? 150,
      maxHeight: data['maxHeight'] ?? 190,
      averageHeight: data['averageHeight'] ?? 170,
      groupGender: data['groupGender'] ?? '혼성',
      maxDistance: data['maxDistance'] ?? 100,
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'description': description,
      'status': status.toString().split('.').last,
      'matchedGroupId': matchedGroupId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'maxMembers': maxMembers,
      'preferredGender': preferredGender,
      'minAge': minAge,
      'maxAge': maxAge,
      'averageAge': averageAge,
      'minHeight': minHeight,
      'maxHeight': maxHeight,
      'averageHeight': averageHeight,
      'groupGender': groupGender,
      'maxDistance': maxDistance,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? memberIds,
    String? description,
    GroupStatus? status,
    String? matchedGroupId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? maxMembers,
    String? preferredGender,
    int? minAge,
    int? maxAge,
    int? averageAge,
    int? minHeight,
    int? maxHeight,
    int? averageHeight,
    String? groupGender,
    int? maxDistance,
    double? latitude,
    double? longitude,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      description: description ?? this.description,
      status: status ?? this.status,
      matchedGroupId: matchedGroupId ?? this.matchedGroupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      maxMembers: maxMembers ?? this.maxMembers,
      preferredGender: preferredGender ?? this.preferredGender,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      averageAge: averageAge ?? this.averageAge,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
      averageHeight: averageHeight ?? this.averageHeight,
      groupGender: groupGender ?? this.groupGender,
      maxDistance: maxDistance ?? this.maxDistance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  // 헬퍼 메서드들
  String get groupId => id;
  int get memberCount => memberIds.length;
  bool get isFull => memberIds.length >= maxMembers;
  bool get canMatch => memberIds.length >= 1 && status == GroupStatus.active;
  bool isOwner(String userId) => ownerId == userId;
  bool isMember(String userId) => memberIds.contains(userId);
}
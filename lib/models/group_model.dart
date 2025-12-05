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
  final int minAge;
  final int maxAge;
  final String groupGender;
  final int averageAge;

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
    this.minAge = 20,
    this.maxAge = 40,
    this.groupGender = '혼성',
    this.averageAge = 20,
  });

  // Firestore에서 데이터를 가져올 때 사용
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
      // [수정됨] Timestamp가 null이거나 타입이 맞지 않을 경우 안전하게 처리
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(), // 데이터가 없으면 현재 시간으로 대체
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(), // 데이터가 없으면 현재 시간으로 대체
      maxMembers: data['maxMembers'] ?? 5,
      preferredGender: data['preferredGender'] ?? '상관없음',
      minAge: data['minAge'] ?? 20,
      maxAge: data['maxAge'] ?? 40,
      groupGender: data['groupGender'] ?? '혼성',
      averageAge: data['averageAge'] ?? 20,
    );
  }

// Firestore에 저장할 때 사용
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
      'groupGender': groupGender,
      'averageAge': averageAge,
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
    String? groupGender,
    int? averageAge,
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
      groupGender: groupGender ?? this.groupGender,
      averageAge: averageAge ?? this.averageAge,
    );
  }

  // 헬퍼 메서드들
  String get groupId => id; // id와 동일
  int get memberCount => memberIds.length;
  bool get isFull => memberIds.length >= maxMembers;
  bool get canMatch => memberIds.length >= 1 && status == GroupStatus.active; // 1명부터 매칭 가능
  bool isOwner(String userId) => ownerId == userId;
  bool isMember(String userId) => memberIds.contains(userId);
}

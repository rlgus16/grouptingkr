import 'package:cloud_firestore/cloud_firestore.dart';

enum InvitationStatus { pending, accepted, rejected, expired }
enum InvitationType { group, private }

class InvitationModel {
  final String id;
  final String fromUserId;
  final String fromUserNickname;
  final String toUserId;
  final String toUserNickname;
  final String groupId;
  final String? message;
  final InvitationStatus status;
  final InvitationType type;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;
  final String? fromUserProfileImage;
  final String? invitationId;

  InvitationModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserNickname,
    required this.toUserId,
    required this.toUserNickname,
    required this.groupId,
    this.message,
    required this.status,
    this.type = InvitationType.group,
    required this.createdAt,
    this.respondedAt,
    required this.expiresAt,
    this.fromUserProfileImage,
    this.invitationId,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvitationModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserNickname: data['fromUserNickname'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserNickname: data['toUserNickname'] ?? '',
      groupId: data['groupId'] ?? '',
      message: data['message'],
      fromUserProfileImage: data['fromUserProfileImage'],
      invitationId: doc.id,
      status: InvitationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => InvitationStatus.pending,
      ),
      type: InvitationType.values.firstWhere(
        (e) => e.toString().split('.').last == (data['type'] ?? 'group'),
        orElse: () => InvitationType.group,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserNickname': fromUserNickname,
      'toUserId': toUserId,
      'toUserNickname': toUserNickname,
      'groupId': groupId,
      'message': message,
      'fromUserProfileImage': fromUserProfileImage,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  // 복사본 생성 (상태 업데이트 등에 사용)
  InvitationModel copyWith({
    String? id,
    String? fromUserId,
    String? fromUserNickname,
    String? toUserId,
    String? toUserNickname,
    String? groupId,
    String? message,
    String? fromUserProfileImage,
    String? invitationId,
    InvitationStatus? status,
    InvitationType? type,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserNickname: fromUserNickname ?? this.fromUserNickname,
      toUserId: toUserId ?? this.toUserId,
      toUserNickname: toUserNickname ?? this.toUserNickname,
      groupId: groupId ?? this.groupId,
      message: message ?? this.message,
      fromUserProfileImage: fromUserProfileImage ?? this.fromUserProfileImage,
      invitationId: invitationId ?? this.invitationId,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // 초대가 만료되었는지 확인
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // 초대가 응답 가능한 상태인지 확인
  bool get canRespond => status == InvitationStatus.pending && !isExpired;

  // 초대가 유효한지 확인
  bool get isValid => status == InvitationStatus.pending && !isExpired;
}

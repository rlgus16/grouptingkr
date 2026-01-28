import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, system }

class MessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderNickname;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final List<String> readBy;
  final String? imageUrl;
  final String? senderProfileImage;
  final Map<String, dynamic>? metadata;

  MessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderNickname,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.readBy,
    this.imageUrl,
    this.senderProfileImage,
    this.metadata,
  });

  // Factory for Firestore
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      ),
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      imageUrl: data['imageUrl'],
      senderProfileImage: data['senderProfileImage'],
      metadata: data['metadata'],
    );
  }

  // Factory for Map (used in open chatrooms)
  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    return MessageModel(
      id: id,
      groupId: data['groupId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      ),
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
      imageUrl: data['imageUrl'],
      senderProfileImage: data['senderProfileImage'],
      metadata: data['metadata'],
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'content': content,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
      'imageUrl': imageUrl,
      'senderProfileImage': senderProfileImage,
      'metadata': metadata,
    };
  }

  // CopyWith
  MessageModel copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderNickname,
    String? content,
    MessageType? type,
    DateTime? createdAt,
    List<String>? readBy,
    String? imageUrl,
    String? senderProfileImage,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      readBy: readBy ?? this.readBy,
      imageUrl: imageUrl ?? this.imageUrl,
      senderProfileImage: senderProfileImage ?? this.senderProfileImage,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helpers
  bool isReadBy(String userId) => readBy.contains(userId);
  bool get isImage => type == MessageType.image;
  bool get isSystem => type == MessageType.system;
  bool get isSystemMessage => type == MessageType.system;
  bool get isInvitationMessage => metadata?['type'] == 'invitation';

  // Factory: System Message
  factory MessageModel.createSystemMessage({
    required String groupId,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: '',
      groupId: groupId,
      senderId: 'system',
      senderNickname: 'System',
      content: content,
      type: MessageType.system,
      createdAt: DateTime.now(),
      readBy: [],
      metadata: metadata,
    );
  }

  // Factory: Invitation Message
  factory MessageModel.createInvitationMessage({
    required String groupId,
    required String senderId,
    required String senderNickname,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: '',
      groupId: groupId,
      senderId: senderId,
      senderNickname: senderNickname,
      content: content,
      type: MessageType.system,
      createdAt: DateTime.now(),
      readBy: [],
      metadata: {'type': 'invitation', ...?metadata},
    );
  }
}
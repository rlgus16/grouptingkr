import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:groupting/models/message_model.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderNickname;
  final String? senderProfileImage;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    this.senderProfileImage,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.readBy,
  });

  // Firestore 문서(DocumentSnapshot)로부터 생성
  factory ChatMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage.fromMap(doc.id, data);
  }

  // Map 데이터로부터 생성 (배열 내부 데이터 처리용)
  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id, // ID가 없을 경우 빈 문자열 또는 생성된 ID 사용 필요
      senderId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? '',
      senderProfileImage: data['senderProfileImage'],
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      ),
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderNickname': senderNickname,
      'senderProfileImage': senderProfileImage,
      'content': content,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }
}

class LastMessage {
  final String content;
  final String senderId;
  final String senderNickname;
  final MessageType type;
  final DateTime createdAt;
  final List<String> readBy;

  LastMessage({
    required this.content,
    required this.senderId,
    required this.senderNickname,
    required this.type,
    required this.createdAt,
    required this.readBy,
  });

  factory LastMessage.fromMap(Map<String, dynamic> data) {
    return LastMessage(
      content: data['content'] ?? '',
      senderId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      ),
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }

  bool get isSystem => type == MessageType.system;
  bool get isImage => type == MessageType.image;
}

class ChatroomModel {
  final String id;
  final String groupId;
  final List<String> participants;
  final List<ChatMessage> messages;
  final LastMessage? lastMessage;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatroomModel({
    required this.id,
    required this.groupId,
    required this.participants,
    this.messages = const [],
    this.lastMessage,
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // [추가됨] Firestore withConverter 호환용 팩토리
  factory ChatroomModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data();
    return ChatroomModel.fromMap(snapshot.id, data ?? {});
  }

  // [추가됨] Firestore withConverter 호환용 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'participants': participants,
      // messages는 보통 하위 컬렉션으로 관리하므로 저장 시 제외하거나 필요한 경우 포함
      'lastMessage': lastMessage?.toMap(),
      'messageCount': messageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ChatroomModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatroomModel.fromMap(doc.id, data);
  }

  factory ChatroomModel.fromMap(String id, Map<String, dynamic> data) {
    return ChatroomModel(
      id: id,
      groupId: data['groupId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      messages: (data['messages'] as List<dynamic>? ?? [])
          .map((m) {
        // Map 데이터인 경우 처리
        if (m is Map<String, dynamic>) {
          return ChatMessage.fromMap(m['id'] as String? ?? '', m);
        }
        return null;
      })
          .whereType<ChatMessage>() // null 제거
          .toList(),
      lastMessage: data['lastMessage'] != null
          ? LastMessage.fromMap(data['lastMessage'])
          : null,
      messageCount: data['messageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }

  ChatroomModel addMessage(ChatMessage message) {
    final updatedMessages = [...messages, message];
    final messagesToKeep = updatedMessages.length > 100
        ? updatedMessages.sublist(updatedMessages.length - 100)
        : updatedMessages;

    return ChatroomModel(
      id: id,
      groupId: groupId,
      participants: participants,
      messages: messagesToKeep,
      lastMessage: LastMessage(
        content: message.content,
        senderId: message.senderId,
        senderNickname: message.senderNickname,
        type: message.type,
        createdAt: message.createdAt,
        readBy: message.readBy,
      ),
      messageCount: messageCount + 1,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
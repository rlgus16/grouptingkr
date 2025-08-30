import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderNickname;
  final String? senderProfileImage;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final List<String> readBy;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    this.senderProfileImage,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.readBy,
    this.metadata,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['id'] ?? '',
      senderId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? '',
      senderProfileImage: data['senderProfileImage'],
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => MessageType.text,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      metadata: data['metadata'] != null 
          ? Map<String, dynamic>.from(data['metadata']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'senderProfileImage': senderProfileImage,
      'content': content,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
      'metadata': metadata,
    };
  }

  bool get isSystem => type == MessageType.system;
  bool isReadBy(String userId) => readBy.contains(userId);
}

class LastMessage {
  final String content;
  final String senderId;
  final String senderNickname;
  final MessageType type;
  final DateTime createdAt;

  LastMessage({
    required this.content,
    required this.senderId,
    required this.senderNickname,
    required this.type,
    required this.createdAt,
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum MessageType { text, image, system }

class ChatroomModel {
  final String id;
  final String groupId;  // 매칭된 그룹들의 복합 ID (group1_group2)
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
    required this.messages,
    this.lastMessage,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatroomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChatroomModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      messages: (data['messages'] as List<dynamic>? ?? [])
          .map((messageData) => ChatMessage.fromMap(messageData as Map<String, dynamic>))
          .toList(),
      lastMessage: data['lastMessage'] != null 
          ? LastMessage.fromMap(data['lastMessage'] as Map<String, dynamic>)
          : null,
      messageCount: data['messageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'participants': participants,
      'messages': messages.map((message) => message.toMap()).toList(),
      'lastMessage': lastMessage?.toMap(),
      'messageCount': messageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // 새 메시지 추가
  ChatroomModel addMessage(ChatMessage message) {
    final updatedMessages = [...messages, message];
    
    // 최신 100개 메시지만 유지 (문서 크기 제한 대응)
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
      ),
      messageCount: messageCount + 1,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // 메시지 읽음 처리
  ChatroomModel markMessageAsRead(String messageId, String userId) {
    final updatedMessages = messages.map((message) {
      if (message.id == messageId && !message.readBy.contains(userId)) {
        return ChatMessage(
          id: message.id,
          senderId: message.senderId,
          senderNickname: message.senderNickname,
          senderProfileImage: message.senderProfileImage,
          content: message.content,
          type: message.type,
          createdAt: message.createdAt,
          readBy: [...message.readBy, userId],
          metadata: message.metadata,
        );
      }
      return message;
    }).toList();

    return ChatroomModel(
      id: id,
      groupId: groupId,
      participants: participants,
      messages: updatedMessages,
      lastMessage: lastMessage,
      messageCount: messageCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // 읽지 않은 메시지 수 계산
  int getUnreadCount(String userId) {
    return messages.where((message) => 
        message.senderId != userId && !message.isReadBy(userId)
    ).length;
  }
}

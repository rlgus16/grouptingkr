import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:groupting/models/message_model.dart';

enum ChatroomType { group_match, private, open }

class ChatroomModel {
  final String id;
  final String groupId;
  final List<String> participants;
  final List<MessageModel> messages;
  final MessageModel? lastMessage;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ChatroomType type;

  ChatroomModel({
    required this.id,
    required this.groupId,
    required this.participants,
    this.messages = const [],
    this.lastMessage,
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.type = ChatroomType.group_match,
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
      'lastMessage': lastMessage?.toFirestore(), // MessageModel의 toFirestore 사용
      'messageCount': messageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'type': type.toString().split('.').last,
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
          return MessageModel.fromMap(m['id'] as String? ?? '', m);
        }
        return null;
      })
          .whereType<MessageModel>() // null 제거
          .toList(),
      lastMessage: data['lastMessage'] != null
          ? MessageModel.fromMap('', data['lastMessage']) // ID가 없는 경우 빈 문자열
          : null,
      messageCount: data['messageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      type: ChatroomType.values.firstWhere(
        (e) => e.toString().split('.').last == (data['type'] ?? 'group_match'),
        orElse: () => ChatroomType.group_match,
      ),
    );
  }

  ChatroomModel addMessage(MessageModel message) {
    final updatedMessages = [...messages, message];
    final messagesToKeep = updatedMessages.length > 100
        ? updatedMessages.sublist(updatedMessages.length - 100)
        : updatedMessages;

    return ChatroomModel(
      id: id,
      groupId: groupId,
      participants: participants,
      messages: messagesToKeep,
      lastMessage: message, // Use the new message as lastMessage
      messageCount: messageCount + 1,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      type: type,
    );
  }
}
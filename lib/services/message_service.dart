import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();

  // 메시지 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _firebaseService.getCollection('messages');

  // 그룹의 메시지 스트림
  Stream<List<MessageModel>> getGroupMessagesStream(String groupId) {
    return _messagesCollection
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
        });
  }

  // 메시지 전송
  Future<void> sendMessage({
    required String groupId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자 정보 가져오기
      final user = await _userService.getUserById(currentUser.uid);
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final message = MessageModel(
        id: '',
        groupId: groupId,
        senderId: currentUser.uid,
        senderNickname: user.nickname,
        senderProfileImage: user.mainProfileImage,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        readBy: [],
        metadata: metadata,
      );

      // 메시지 저장
      final docRef = _messagesCollection.doc();
      final messageWithId = message.copyWith(id: docRef.id); // ID 포함된 메시지 객체 생성
      await docRef.set(messageWithId.toFirestore());

      // [핵심 수정 부분]
      // 기존: await _updateGroupLastMessage(groupId, docRef.id);
      // 변경: 아래 함수를 호출해야 서버(Cloud Functions)가 'chatrooms' 변경을 감지하고 알림을 보냅니다.
      await _updateChatRoomLastMessage(groupId, messageWithId);

    } catch (e) {
      throw Exception('메시지 전송에 실패했습니다: $e');
    }
  }

  // 채팅방(chatrooms) 컬렉션에 마지막 메시지 정보를 업데이트합니다.
  Future<void> _updateChatRoomLastMessage(String chatRoomId, MessageModel message) async {
    try {
      // 1. chatrooms 컬렉션 업데이트 (알림 발송용)
      await _firebaseService.getDocument('chatrooms/$chatRoomId').update({
        'lastMessage': message.toFirestore(), // 메시지 전체 내용 저장 (닉네임, 내용 등)
        'lastMessageId': message.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. groups 컬렉션 업데이트 (앱 내 채팅 목록 표시용 - 기존 로직 유지)
      try {
        await _firebaseService.getDocument('groups/$chatRoomId').update({
          'lastMessageId': message.id,
          'lastMessageTime': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } catch (e) {
        // 그룹 ID와 채팅방 ID가 다른 경우 무시
      }

    } catch (e) {
      print('채팅방 마지막 메시지 업데이트 실패: $e');
    }
  }

  // 시스템 메시지 전송
  Future<void> sendSystemMessage({
    required String groupId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final message = MessageModel.createSystemMessage(
        groupId: groupId,
        content: content,
        metadata: metadata,
      );

      final docRef = _messagesCollection.doc();
      await docRef.set(message.copyWith(id: docRef.id).toFirestore());

      // 그룹의 마지막 메시지 정보 업데이트
      await _updateGroupLastMessage(groupId, docRef.id);
    } catch (e) {
      throw Exception('시스템 메시지 전송에 실패했습니다: $e');
    }
  }

  // 초대 메시지 전송
  Future<void> sendInvitationMessage({
    required String groupId,
    required String targetUserId,
    required String content,
  }) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 현재 사용자 정보 가져오기
      final user = await _userService.getUserById(currentUser.uid);
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final message = MessageModel.createInvitationMessage(
        groupId: groupId,
        senderId: currentUser.uid,
        senderNickname: user.nickname,
        content: content,
        metadata: {'targetUserId': targetUserId},
      );

      final docRef = _messagesCollection.doc();
      await docRef.set(message.copyWith(id: docRef.id).toFirestore());

      // 그룹의 마지막 메시지 정보 업데이트
      await _updateGroupLastMessage(groupId, docRef.id);
    } catch (e) {
      throw Exception('초대 메시지 전송에 실패했습니다: $e');
    }
  }

  // 초대 메시지 응답 업데이트
  Future<void> updateInvitationResponse({
    required String messageId,
    required String status, // 'accepted' or 'rejected'
  }) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'metadata.invitationStatus': status,
      });
    } catch (e) {
      throw Exception('초대 응답 업데이트에 실패했습니다: $e');
    }
  }

  // 그룹의 마지막 메시지 정보 업데이트
  Future<void> _updateGroupLastMessage(String groupId, String messageId) async {
    try {
      await _firebaseService.getDocument('groups/$groupId').update({
        'lastMessageId': messageId,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      // 그룹 정보 업데이트 실패는 로그만 출력
    }
  }

  // 특정 메시지 가져오기
  Future<MessageModel?> getMessageById(String messageId) async {
    try {
      final doc = await _messagesCollection.doc(messageId).get();
      if (!doc.exists) return null;
      return MessageModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('메시지를 가져오는데 실패했습니다: $e');
    }
  }

  // 그룹의 최근 메시지 가져오기
  Future<List<MessageModel>> getRecentMessages(
    String groupId, {
    int limit = 50,
  }) async {
    try {
      final query = await _messagesCollection
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final messages = query.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      // 시간 순으로 정렬 (오래된 것부터)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return messages;
    } catch (e) {
      throw Exception('최근 메시지를 가져오는데 실패했습니다: $e');
    }
  }

  // 메시지 삭제 (시스템 메시지는 삭제 불가)
  Future<void> deleteMessage(String messageId) async {
    try {
      final message = await getMessageById(messageId);
      if (message == null) {
        throw Exception('메시지를 찾을 수 없습니다.');
      }

      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 본인이 보낸 메시지만 삭제 가능
      if (message.senderId != currentUserId) {
        throw Exception('본인이 보낸 메시지만 삭제할 수 있습니다.');
      }

      // 시스템 메시지는 삭제 불가
      if (message.isSystemMessage) {
        throw Exception('시스템 메시지는 삭제할 수 없습니다.');
      }

      await _messagesCollection.doc(messageId).delete();
    } catch (e) {
      throw Exception('메시지 삭제에 실패했습니다: $e');
    }
  }
}

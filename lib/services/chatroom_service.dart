import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:groupting/models/message_model.dart';
import '../models/chatroom_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

class ChatroomService {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  
  CollectionReference<Map<String, dynamic>> get _chatroomsCollection =>
      _firebaseService.firestore.collection('chatrooms');

  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) throw Exception('로그인이 필요합니다');

      final userModel = await _userService.getUserById(currentUser.uid);
      final senderNickname = userModel?.nickname ?? 'Unknown User';
      final senderProfileImage = userModel?.mainProfileImage;

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final newMessage = MessageModel(
        id: messageId,
        groupId: chatRoomId,
        senderId: currentUser.uid,
        senderNickname: senderNickname,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        readBy: [currentUser.uid],
        imageUrl: imageUrl,
        senderProfileImage: senderProfileImage,
        metadata: metadata,
      );

      final chatroomRef = _chatroomsCollection.doc(chatRoomId);

      await chatroomRef.update({
        'messages': FieldValue.arrayUnion([newMessage.toFirestore()]),
        'lastMessage': newMessage.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });
      
    } catch (e) {
      debugPrint('메시지 전송 실패: $e');
      throw Exception('메시지 전송 실패: $e');
    }
  }
  
    /// 채팅방 생성 또는 가져오기 (개선된 참여자 관리)
  Future<ChatroomModel> getOrCreateChatroom({
    required String chatRoomId,
    required String groupId,
    required List<String> participants,
  }) async {
    DocumentSnapshot<Map<String, dynamic>>? doc;

    try {
      doc = await _chatroomsCollection.doc(chatRoomId).get();
    } catch (e) {
      debugPrint('채팅방 조회/생성 실패: $e');
    }

    try {
      if (doc?.exists ?? false) {
        final existingChatroom = ChatroomModel.fromFirestore(doc!);
        final existingParticipants = Set.from(existingChatroom.participants);
        final newParticipants = Set.from(participants);
        
        if (!existingParticipants.containsAll(newParticipants) || 
            !newParticipants.containsAll(existingParticipants)) {
          
          await _chatroomsCollection.doc(chatRoomId).update({
            'participants': participants,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          return existingChatroom.copyWith(
            participants: participants,
            updatedAt: DateTime.now(),
          );
        }
        
        return existingChatroom;
      }
      
      final now = DateTime.now();
      final newChatroom = ChatroomModel(
        id: chatRoomId,
        groupId: groupId,
        participants: participants,
        messages: [],
        messageCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      
      await _chatroomsCollection.doc(chatRoomId).set(newChatroom.toFirestore());
      
      return newChatroom;
    } catch (e) {
      throw Exception('채팅방 생성 실패: $e');
    }
  }

  Stream<ChatroomModel?> getChatroomStream(String chatRoomId) {
    return _chatroomsCollection.doc(chatRoomId)
        .snapshots(
          includeMetadataChanges: false,
        )
        .distinct((prev, next) {
          final prevData = prev.data();
          final nextData = next.data();
          
          if (prevData == null && nextData == null) return true;
          if (prevData == null || nextData == null) return false;
          
          return prevData['messageCount'] == nextData['messageCount'] &&
                 prevData['updatedAt'] == nextData['updatedAt'];
        })
        .map((doc) {
      if (doc.exists) {
        final chatroom = ChatroomModel.fromFirestore(doc);
        return chatroom;
      } else {
        return null;
      }
    });
  }

  Future<void> sendSystemMessage({
    required String chatRoomId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final systemMessage = MessageModel.createSystemMessage(
        groupId: chatRoomId,
        content: content,
        metadata: metadata,
      );

      final chatroomRef = _chatroomsCollection.doc(chatRoomId);
      
      await chatroomRef.update({
        'messages': FieldValue.arrayUnion([systemMessage.toFirestore()]),
        'lastMessage': systemMessage.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });

    } catch (e) {
      throw Exception('시스템 메시지 전송 실패: $e');
    }
  }
}

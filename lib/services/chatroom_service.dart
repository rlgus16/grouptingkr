import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chatroom_model.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

class ChatroomService {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  
  // Firestore 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _chatroomsCollection =>
      _firebaseService.firestore.collection('chatrooms');

  /// 채팅방 생성 또는 가져오기
  Future<ChatroomModel> getOrCreateChatroom({
    required String chatRoomId,
    required String groupId,
    required List<String> participants,
  }) async {
    try {
      // 기존 채팅방 확인
      final doc = await _chatroomsCollection.doc(chatRoomId).get();
      
      if (doc.exists) {
        // 기존 채팅방 반환
        return ChatroomModel.fromFirestore(doc);
      }
      
      // 새 채팅방 생성
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

  /// 실시간 채팅방 스트림
  Stream<ChatroomModel?> getChatroomStream(String chatRoomId) {
    return _chatroomsCollection.doc(chatRoomId).snapshots().map((doc) {
      if (doc.exists) {
        return ChatroomModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// 메시지 전송
  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('메시지 전송 시작 - 채팅방: $chatRoomId, 내용: ${content.substring(0, content.length > 20 ? 20 : content.length)}...');
      
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 사용자 정보 가져오기
      final userModel = await _userService.getUserById(currentUser.uid);
      final senderNickname = userModel?.nickname ?? 'Unknown User';
      final senderProfileImage = userModel?.mainProfileImage;
      
      debugPrint('발송자 정보 - 닉네임: $senderNickname, UID: ${currentUser.uid}');

      // 새 메시지 생성
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final newMessage = ChatMessage(
        id: messageId,
        senderId: currentUser.uid,
        senderNickname: senderNickname,
        senderProfileImage: senderProfileImage,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        readBy: [currentUser.uid], // 발신자는 자동으로 읽음 처리
        metadata: metadata,
      );

      // 트랜잭션으로 채팅방 업데이트
      await _firebaseService.runTransaction((transaction) async {
        final chatroomDoc = await transaction.get(_chatroomsCollection.doc(chatRoomId));
        
        if (!chatroomDoc.exists) {
          throw Exception('채팅방을 찾을 수 없습니다');
        }

        final chatroom = ChatroomModel.fromFirestore(chatroomDoc);
        final updatedChatroom = chatroom.addMessage(newMessage);

        transaction.update(_chatroomsCollection.doc(chatRoomId), updatedChatroom.toFirestore());
        
        debugPrint('채팅방 업데이트 완료 - 총 메시지: ${updatedChatroom.messageCount}개');
      });

      debugPrint('메시지 전송 성공! Firebase Functions 트리거 예상됨');
    } catch (e) {
      debugPrint('메시지 전송 실패: $e');
      throw Exception('메시지 전송 실패: $e');
    }
  }

  /// 시스템 메시지 전송
  Future<void> sendSystemMessage({
    required String chatRoomId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 시스템 메시지 생성
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final systemMessage = ChatMessage(
        id: messageId,
        senderId: 'system',
        senderNickname: 'System',
        content: content,
        type: MessageType.system,
        createdAt: DateTime.now(),
        readBy: [], // 시스템 메시지는 모든 사용자가 읽어야 함
        metadata: metadata,
      );

      // 트랜잭션으로 채팅방 업데이트
      await _firebaseService.runTransaction((transaction) async {
        final chatroomDoc = await transaction.get(_chatroomsCollection.doc(chatRoomId));
        
        ChatroomModel chatroom;
        if (chatroomDoc.exists) {
          chatroom = ChatroomModel.fromFirestore(chatroomDoc);
        } else {
          // 채팅방이 없으면 생성 (매칭 완료 시 첫 메시지인 경우)
          chatroom = ChatroomModel(
            id: chatRoomId,
            groupId: chatRoomId, // 매칭된 그룹들의 복합 ID
            participants: [], // 실제 참여자는 별도로 설정 필요
            messages: [],
            messageCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }

        final updatedChatroom = chatroom.addMessage(systemMessage);
        
        if (chatroomDoc.exists) {
          transaction.update(_chatroomsCollection.doc(chatRoomId), updatedChatroom.toFirestore());
        } else {
          transaction.set(_chatroomsCollection.doc(chatRoomId), updatedChatroom.toFirestore());
        }
      });

    } catch (e) {
      throw Exception('시스템 메시지 전송 실패: $e');
    }
  }

  /// 메시지 읽음 처리
  Future<void> markMessageAsRead({
    required String chatRoomId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _firebaseService.runTransaction((transaction) async {
        final chatroomDoc = await transaction.get(_chatroomsCollection.doc(chatRoomId));
        
        if (!chatroomDoc.exists) {
          throw Exception('채팅방을 찾을 수 없습니다');
        }

        final chatroom = ChatroomModel.fromFirestore(chatroomDoc);
        final updatedChatroom = chatroom.markMessageAsRead(messageId, userId);

        transaction.update(_chatroomsCollection.doc(chatRoomId), updatedChatroom.toFirestore());
      });
    } catch (e) {
      throw Exception('메시지 읽음 처리 실패: $e');
    }
  }

  /// 모든 메시지 읽음 처리
  Future<void> markAllMessagesAsRead({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      await _firebaseService.runTransaction((transaction) async {
        final chatroomDoc = await transaction.get(_chatroomsCollection.doc(chatRoomId));
        
        if (!chatroomDoc.exists) {
          return;
        }

        final chatroom = ChatroomModel.fromFirestore(chatroomDoc);
        
        // 모든 메시지를 읽음 처리
        final updatedMessages = chatroom.messages.map((message) {
          if (!message.readBy.contains(userId)) {
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

        final updatedChatroom = ChatroomModel(
          id: chatroom.id,
          groupId: chatroom.groupId,
          participants: chatroom.participants,
          messages: updatedMessages,
          lastMessage: chatroom.lastMessage,
          messageCount: chatroom.messageCount,
          createdAt: chatroom.createdAt,
          updatedAt: DateTime.now(),
        );

        transaction.update(_chatroomsCollection.doc(chatRoomId), updatedChatroom.toFirestore());
      });
    } catch (e) {
      throw Exception('전체 메시지 읽음 처리 실패: $e');
    }
  }

  /// 읽지 않은 메시지 수 조회
  Future<int> getUnreadCount({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      final doc = await _chatroomsCollection.doc(chatRoomId).get();
      
      if (!doc.exists) {
        return 0;
      }

      final chatroom = ChatroomModel.fromFirestore(doc);
      return chatroom.getUnreadCount(userId);
    } catch (e) {
      return 0;
    }
  }

  /// 채팅방 참여자 업데이트
  Future<void> updateParticipants({
    required String chatRoomId,
    required List<String> participants,
  }) async {
    try {
      await _chatroomsCollection.doc(chatRoomId).update({
        'participants': participants,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('참여자 업데이트 실패: $e');
    }
  }

  /// 채팅방 삭제
  Future<void> deleteChatroom(String chatRoomId) async {
    try {
      await _chatroomsCollection.doc(chatRoomId).delete();
    } catch (e) {
      throw Exception('채팅방 삭제 실패: $e');
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chatroom_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

class ChatroomService {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  
  // Firestore 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _chatroomsCollection =>
      _firebaseService.firestore.collection('chatrooms');

  /// 채팅방 생성 또는 가져오기 (개선된 참여자 관리)
  Future<ChatroomModel> getOrCreateChatroom({
    required String chatRoomId,
    required String groupId,
    required List<String> participants,
  }) async {
    DocumentSnapshot<Map<String, dynamic>>? doc;

    // [빠른손] 기존 채팅방 확인
    try {
      debugPrint('채팅방 조회/생성 시도: $chatRoomId (참여자 ${participants.length}명)');
      doc = await _chatroomsCollection.doc(chatRoomId).get();
    } catch (e) {
      debugPrint('채팅방 조회/생성 실패: $e');
    }

    try {
      if (doc?.exists ?? false) {
        final existingChatroom = ChatroomModel.fromFirestore(doc!);

        // 참여자 목록이 다르면 업데이트
        final existingParticipants = Set.from(existingChatroom.participants);
        final newParticipants = Set.from(participants);
        
        if (!existingParticipants.containsAll(newParticipants) || 
            !newParticipants.containsAll(existingParticipants)) {
          debugPrint('채팅방 참여자 목록 업데이트: ${existingParticipants.length}명 → ${newParticipants.length}명');
          
          await _chatroomsCollection.doc(chatRoomId).update({
            'participants': participants,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          // 업데이트된 채팅방 반환
          return existingChatroom.copyWith(
            participants: participants,
            updatedAt: DateTime.now(),
          );
        }
        
        // 기존 채팅방 반환
        return existingChatroom;
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
      
      debugPrint('새 채팅방 생성: $chatRoomId (참여자 ${participants.length}명)');
      await _chatroomsCollection.doc(chatRoomId).set(newChatroom.toFirestore());
      
      return newChatroom;
    } catch (e) {
      throw Exception('채팅방 생성 실패: $e');
    }
  }

  /// 실시간 채팅방 스트림 - 성능 최적화 및 디버깅 강화
  Stream<ChatroomModel?> getChatroomStream(String chatRoomId) {
    
    return _chatroomsCollection.doc(chatRoomId)
        .snapshots(
          includeMetadataChanges: false, // 메타데이터 변경 제외로 불필요한 업데이트 방지
        )
        .distinct((prev, next) {
          // 실제 변경사항이 있을 때만 업데이트 (성능 최적화)
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

      // 성능 최적화된 트랜잭션으로 채팅방 업데이트
      await _firebaseService.runTransaction((transaction) async {
        final chatroomDoc = await transaction.get(_chatroomsCollection.doc(chatRoomId));
        
        if (!chatroomDoc.exists) {
          throw Exception('채팅방을 찾을 수 없습니다');
        }

        final chatroom = ChatroomModel.fromFirestore(chatroomDoc);
        
        // 성능 최적화: 메시지 수 제한 (50개 초과 시 오래된 메시지 제거)
        var messages = chatroom.messages;
        if (messages.length >= 50) {
          messages = messages.sublist(messages.length - 49); // 49개 + 새 메시지 = 50개
          debugPrint('오래된 메시지 제거: ${chatroom.messages.length - 49}개 삭제');
        }
        
        final optimizedChatroom = ChatroomModel(
          id: chatroom.id,
          groupId: chatroom.groupId,
          participants: chatroom.participants,
          messages: [...messages, newMessage],
          lastMessage: LastMessage(
            content: newMessage.content,
            senderId: newMessage.senderId,
            senderNickname: newMessage.senderNickname,
            createdAt: newMessage.createdAt,
            type: newMessage.type,
          ),
          messageCount: chatroom.messageCount + 1,
          createdAt: chatroom.createdAt,
          updatedAt: DateTime.now(),
        );

        transaction.update(_chatroomsCollection.doc(chatRoomId), optimizedChatroom.toFirestore());
        
        debugPrint('채팅방 업데이트 완료 - 총 메시지: ${optimizedChatroom.messageCount}개 (메모리: ${optimizedChatroom.messages.length}개)');
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

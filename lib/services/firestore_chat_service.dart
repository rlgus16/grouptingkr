import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

// 권장 방식으로 전환 -> 99.5에서 99.99의 정확도를 가져가는 클라우드 쪽으로 전환하여 적용도와드리기
class FirestoreChatService {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();
  
  // Firestore 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _firebaseService.firestore.collection('messages');

  // 그룹 채팅방에 메시지 전송
  Future<void> sendMessage({
    required String groupId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }


      // 사용자 닉네임 가져오기
      final userModel = await _userService.getUserById(currentUser.uid);
      final senderNickname = userModel?.nickname ?? 'Unknown User';

      final message = MessageModel(
        id: '', // Firestore에서 자동 생성
        senderId: currentUser.uid,
        senderNickname: senderNickname,
        senderProfileImage: userModel?.mainProfileImage,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        groupId: groupId,
        readBy: [],
        imageUrl: imageUrl,
        metadata: metadata,
      );

      // Firestore에 저장
      final docRef = await _messagesCollection.add(message.toFirestore());
      
    } catch (e) {
      throw Exception('메시지 전송에 실패했습니다: $e');
    }
  }

  // 실시간 메시지 스트림 (그룹별)
  Stream<List<MessageModel>> getMessagesStream(String groupId) {
    
    return _messagesCollection
        .where('groupId', isEqualTo: groupId)
        // .orderBy('createdAt', descending: false) // 시간 순으로 정렬 -> 해당 부분은 속도 증가를 위해 인덱스 해줄 필요가 있는 부분.
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
          
          // 시간순으로 정렬 (클라이언트에서)
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));          
          return messages;
        });
  }

  // 시스템 메시지 전송 (매칭 성공, 멤버 참가/탈퇴 등)
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

      final docRef = await _messagesCollection.add(message.toFirestore());
      
    } catch (e) {
      // 시스템 메시지 전송 오류
      throw Exception('시스템 메시지 전송에 실패했습니다: $e');
    }
  }

  // 특정 메시지 읽음 처리
  Future<void> markMessageAsRead(String messageId, String userId) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'readBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      // 메시지 읽음 처리 실패
    }
  }
    
  // 그룹의 모든 메시지 읽음 처리
  Future<void> markAllMessagesAsRead(String groupId, String userId) async {
    try {
      // 읽지 않은 메시지들 조회
      final unreadMessages = await _messagesCollection
          .where('groupId', isEqualTo: groupId)
          .where('readBy', whereNotIn: [userId])
          .get();

      // 배치 업데이트
      final batch = _firebaseService.firestore.batch();
      
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId])
        });
      }

      await batch.commit();

    } catch (e) {
      // 전체 메시지 읽음 처리 실패
    }
  }

  // 그룹의 읽지 않은 메시지 수 조회
  Future<int> getUnreadMessageCount(String groupId, String userId) async {
    try {
      final unreadMessages = await _messagesCollection
          .where('groupId', isEqualTo: groupId)
          .where('readBy', whereNotIn: [userId])
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      // 읽지 않은 메시지 수 조회 실패
      return 0;
    }
  }

  // 특정 메시지 삭제 (관리자용)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).delete();
    } catch (e) {
      // 메시지 삭제 실패
      throw Exception('메시지 삭제에 실패했습니다: $e');
    }
  }

  // 그룹 채팅방 삭제 (그룹 해체 시)
  Future<void> deleteChatRoom(String groupId) async {
    try {

      // 해당 그룹의 모든 메시지 조회
      final messages = await _messagesCollection
          .where('groupId', isEqualTo: groupId)
          .get();

      // 배치 삭제
      final batch = _firebaseService.firestore.batch();
      
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      

    } catch (e) {
      // 채팅방 삭제 실패
      throw Exception('채팅방 삭제에 실패했습니다: $e');
    }
  }

  // 사용자가 보낸 모든 메시지 삭제 (계정 삭제 시)
  Future<void> deleteUserMessages(String userId) async {
    try {

      // 사용자가 보낸 모든 메시지 조회 (시스템 메시지 제외)
      final messages = await _messagesCollection
          .where('senderId', isEqualTo: userId)
          .where('type', isNotEqualTo: 'system')
          .get();

      // 배치 삭제
      final batch = _firebaseService.firestore.batch();
      
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      

    } catch (e) {
      // 사용자 메시지 삭제 실패
    }
  }

  // 메시지 검색
  Future<List<MessageModel>> searchMessages({
    required String groupId,
    required String query,
    int limit = 50,
  }) async {
    try {
      // Firestore의 전문 검색 제한으로 인해 클라이언트 사이드 필터링 사용
      final allMessages = await _messagesCollection
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2) // 더 많이 가져와서 필터링
          .get();

      final messages = allMessages.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .where((message) => 
              message.content.toLowerCase().contains(query.toLowerCase()) ||
              message.senderNickname.toLowerCase().contains(query.toLowerCase()))
          .take(limit)
          .toList();

      return messages;
    } catch (e) {
      // 메시지 검색 실패
      return [];
    }
  }

  // 최근 메시지 조회 (페이징)
  Future<List<MessageModel>> getRecentMessages({
    required String groupId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _messagesCollection
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final result = await query.get();
      
      return result.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

    } catch (e) {
      // 최근 메시지 조회 실패
      return [];
    }
  }
}

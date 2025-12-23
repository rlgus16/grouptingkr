import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/chatroom_model.dart';
import 'firebase_service.dart';
import 'user_service.dart';

class ChatroomService {
  final FirebaseService _firebaseService = FirebaseService();
  final UserService _userService = UserService();

  CollectionReference<Map<String, dynamic>> get _chatroomsCollection =>
      _firebaseService.firestore.collection('chatrooms');

  /// Retrieves an existing chatroom or creates it if it doesn't exist.
  /// Also ensures the participant list is up-to-date.
  Future<ChatroomModel> getOrCreateChatroom({
    required String chatRoomId,
    required String groupId,
    required List<String> participants,
  }) async {
    try {
      final docRef = _chatroomsCollection.doc(chatRoomId);
      final doc = await docRef.get();

      if (doc.exists) {
        final existingChatroom = ChatroomModel.fromDocument(doc);

        // Check if we need to update participants (e.g., a new member joined)
        final currentSet = Set.from(existingChatroom.participants);
        final newSet = Set.from(participants);

        if (!currentSet.containsAll(newSet)) {
          debugPrint('Syncing participants for chatroom $chatRoomId');
          // Use arrayUnion to add new members without duplicates
          await docRef.update({
            'participants': FieldValue.arrayUnion(participants),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return existingChatroom;
      }

      // Create new chatroom
      debugPrint('Creating new chatroom: $chatRoomId');
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

      // set() with merge: true is safer than set() alone for race conditions
      await docRef.set(newChatroom.toFirestore(), SetOptions(merge: true));

      return newChatroom;
    } catch (e) {
      debugPrint('Error in getOrCreateChatroom: $e');
      throw ('Failed to initialize chatroom: $e');
    }
  }

  Stream<ChatroomModel?> getChatroomStream(String chatRoomId) {
    return _chatroomsCollection
        .doc(chatRoomId)
        .snapshots(includeMetadataChanges: false)
        .map((doc) => doc.exists ? ChatroomModel.fromDocument(doc) : null);
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Fetch latest user details for the message snapshot
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

      // Atomically add the message to the array and update stats
      await _chatroomsCollection.doc(chatRoomId).update({
        'messages': FieldValue.arrayUnion([newMessage.toFirestore()]),
        'lastMessage': newMessage.toFirestore(),
        'lastMessageId': messageId, // Required for Cloud Function to detect new messages and send push notifications
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('SendMessage failed: $e');
      throw Exception('Failed to send message: $e');
    }
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

      await _chatroomsCollection.doc(chatRoomId).update({
        'messages': FieldValue.arrayUnion([systemMessage.toFirestore()]),
        'lastMessage': systemMessage.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('System message failed: $e');
      throw Exception('Failed to send system message: $e');
    }
  }

  // 메시지 읽음 처리
  Future<void> markAsRead(String chatRoomId) async {
    try {
      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) return;

      final docRef = _chatroomsCollection.doc(chatRoomId);
      final doc = await docRef.get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      // lastMessage 업데이트 (홈 화면 버튼 색상용)
      final lastMessageData = data['lastMessage'] as Map<String, dynamic>?;

      if (lastMessageData != null) {
        final List<dynamic> readBy = lastMessageData['readBy'] ?? [];
        // 내 ID가 readBy 목록에 없으면 추가
        if (!readBy.contains(currentUser.uid)) {
          readBy.add(currentUser.uid);

          // Firestore에 업데이트 (필드 하나만 부분 업데이트)
          await docRef.update({
            'lastMessage.readBy': readBy,
          });
        }
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }
}
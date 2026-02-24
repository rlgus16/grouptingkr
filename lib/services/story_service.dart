import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/story_model.dart';
import '../models/story_comment_model.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String collectionName = 'stories';

  Future<void> createStory({
    required String authorId,
    required String authorNickname,
    String? authorGender,
    String? authorProfileUrl,
    String? text,
    File? imageFile,
  }) async {
    String? imageUrl;

    if (imageFile != null) {
      final fileName = const Uuid().v4();
      final ref = _storage.ref().child('stories/$authorId/$fileName.jpg');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );
      
      await ref.putFile(imageFile, metadata);
      imageUrl = await ref.getDownloadURL();
    }

    final newRef = _firestore.collection(collectionName).doc();
    final story = StoryModel(
      id: newRef.id,
      authorId: authorId,
      authorNickname: authorNickname,
      authorGender: authorGender,
      authorProfileUrl: authorProfileUrl,
      text: text,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      likes: [],
    );

    await newRef.set(story.toFirestore());
  }

  // 2. Read Stories Stream (Real-Time Updates)
  Stream<List<StoryModel>> getStoriesStream() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _firestore
        .collection(collectionName)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => StoryModel.fromFirestore(doc)).toList();
    });
  }

  // 3. Toggle Like
  Future<void> toggleLike(String storyId, String uid) async {
    final storyRef = _firestore.collection(collectionName).doc(storyId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(storyRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      List<String> likes = List<String>.from(data['likes'] ?? []);

      if (likes.contains(uid)) {
        likes.remove(uid);
      } else {
        likes.add(uid);
      }

      transaction.update(storyRef, {'likes': likes});
    });
  }

  // 4. Delete Story
  Future<void> deleteStory(String storyId, String? imageUrl) async {
    // Delete image from storage if it exists
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      } catch (e) {
        // Log error but proceed to delete document
        debugPrint('Error deleting image: $e');
      }
    }

    // Delete Firestore document
    await _firestore.collection(collectionName).doc(storyId).delete();
  }

  // 5. Add Comment
  Future<void> addComment({
    required String storyId,
    required String authorId,
    required String authorNickname,
    String? authorProfileUrl,
    required String text,
  }) async {
    final newRef = _firestore
        .collection(collectionName)
        .doc(storyId)
        .collection('comments')
        .doc();

    final comment = StoryCommentModel(
      id: newRef.id,
      storyId: storyId,
      authorId: authorId,
      authorNickname: authorNickname,
      authorProfileUrl: authorProfileUrl,
      text: text,
      createdAt: DateTime.now(),
    );

    await newRef.set(comment.toFirestore());
  }

  // 6. Read Comments Stream
  Stream<List<StoryCommentModel>> getCommentsStream(String storyId) {
    return _firestore
        .collection(collectionName)
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StoryCommentModel.fromFirestore(doc))
          .toList();
    });
  }

  // 7. Delete Comment
  Future<void> deleteComment(String storyId, String commentId) async {
    await _firestore
        .collection(collectionName)
        .doc(storyId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
}

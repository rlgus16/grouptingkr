import 'package:cloud_firestore/cloud_firestore.dart';

class StoryCommentModel {
  final String id;
  final String storyId;
  final String authorId;
  final String authorNickname;
  final String? authorProfileUrl;
  final String text;
  final DateTime createdAt;

  StoryCommentModel({
    required this.id,
    required this.storyId,
    required this.authorId,
    required this.authorNickname,
    this.authorProfileUrl,
    required this.text,
    required this.createdAt,
  });

  factory StoryCommentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StoryCommentModel(
      id: doc.id,
      storyId: data['storyId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorNickname: data['authorNickname'] ?? 'Unknown User',
      authorProfileUrl: data['authorProfileUrl'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'storyId': storyId,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorProfileUrl': authorProfileUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  StoryCommentModel copyWith({
    String? id,
    String? storyId,
    String? authorId,
    String? authorNickname,
    String? authorProfileUrl,
    String? text,
    DateTime? createdAt,
  }) {
    return StoryCommentModel(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      authorId: authorId ?? this.authorId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorProfileUrl: authorProfileUrl ?? this.authorProfileUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

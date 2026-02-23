import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String authorId;
  final String authorNickname;
  final String? authorProfileUrl;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> likes;

  StoryModel({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    this.authorProfileUrl,
    this.text,
    this.imageUrl,
    required this.createdAt,
    required this.likes,
  });

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorNickname: data['authorNickname'] ?? 'Unknown',
      authorProfileUrl: data['authorProfileUrl'],
      text: data['text'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      likes: List<String>.from(data['likes'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorProfileUrl': authorProfileUrl,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
    };
  }

  StoryModel copyWith({
    String? id,
    String? authorId,
    String? authorNickname,
    String? authorProfileUrl,
    String? text,
    String? imageUrl,
    DateTime? createdAt,
    List<String>? likes,
  }) {
    return StoryModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorNickname: authorNickname ?? this.authorNickname,
      authorProfileUrl: authorProfileUrl ?? this.authorProfileUrl,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
    );
  }
}

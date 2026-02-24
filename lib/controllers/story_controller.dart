import 'dart:io';
import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../models/story_comment_model.dart';
import '../services/story_service.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class StoryController extends ChangeNotifier {
  final StoryService _storyService = StoryService();
  final UserService _userService = UserService();

  List<StoryModel> _stories = [];
  bool _isLoading = false;
  Map<String, UserModel> _authorProfiles = {};

  List<StoryModel> get stories => _stories;
  bool get isLoading => _isLoading;
  
  UserModel? getAuthorProfile(String uid) => _authorProfiles[uid];

  StoryController() {
    _listenToStories();
  }

  void _listenToStories() {
    _storyService.getStoriesStream().listen((fetchedStories) async {
      _stories = fetchedStories;
      notifyListeners();

      // Fetch live user profiles for the authors
      final uniqueAuthorIds = _stories.map((s) => s.authorId).toSet().toList();
      if (uniqueAuthorIds.isNotEmpty) {
        try {
          final authorsList = await _userService.getUsersByIds(uniqueAuthorIds);
          for (var user in authorsList) {
            _authorProfiles[user.uid] = user;
          }
          notifyListeners();
        } catch (e) {
          debugPrint('Failed to fetch author profiles: $e');
        }
      }
    }, onError: (error) {
      debugPrint('Error listening to stories stream: $error');
    });
  }

  Future<void> createStory({
    required String authorId,
    required String authorNickname,
    String? authorGender,
    String? authorProfileUrl,
    String? text,
    File? imageFile,
    double? authorLatitude,
    double? authorLongitude,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storyService.createStory(
        authorId: authorId,
        authorNickname: authorNickname,
        authorGender: authorGender,
        authorProfileUrl: authorProfileUrl,
        text: text,
        imageFile: imageFile,
        authorLatitude: authorLatitude,
        authorLongitude: authorLongitude,
      );
    } catch (e) {
      debugPrint('Failed to create story: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String storyId, String uid) async {
    try {
      await _storyService.toggleLike(storyId, uid);
    } catch (e) {
      debugPrint('Failed to toggle like: $e');
    }
  }

  Future<void> deleteStory(String storyId, String? imageUrl) async {
    try {
      await _storyService.deleteStory(storyId, imageUrl);
    } catch (e) {
      debugPrint('Failed to delete story: $e');
      rethrow;
    }
  }

  // --- Comments ---
  
  Stream<List<StoryCommentModel>> getCommentsStream(String storyId) {
    return _storyService.getCommentsStream(storyId);
  }

  Future<void> addComment({
    required String storyId,
    required String authorId,
    required String authorNickname,
    String? authorProfileUrl,
    required String text,
  }) async {
    try {
      await _storyService.addComment(
        storyId: storyId,
        authorId: authorId,
        authorNickname: authorNickname,
        authorProfileUrl: authorProfileUrl,
        text: text,
      );
    } catch (e) {
      debugPrint('Failed to add comment: $e');
      rethrow;
    }
  }

  Future<void> deleteComment(String storyId, String commentId) async {
    try {
      await _storyService.deleteComment(storyId, commentId);
    } catch (e) {
      debugPrint('Failed to delete comment: $e');
      rethrow;
    }
  }
}

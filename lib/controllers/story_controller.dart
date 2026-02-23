import 'dart:io';
import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';

class StoryController extends ChangeNotifier {
  final StoryService _storyService = StoryService();

  List<StoryModel> _stories = [];
  bool _isLoading = false;

  List<StoryModel> get stories => _stories;
  bool get isLoading => _isLoading;

  StoryController() {
    _listenToStories();
  }

  void _listenToStories() {
    _storyService.getStoriesStream().listen((fetchedStories) {
      _stories = fetchedStories;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to stories stream: $error');
    });
  }

  Future<void> createStory({
    required String authorId,
    required String authorNickname,
    String? authorProfileUrl,
    String? text,
    File? imageFile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storyService.createStory(
        authorId: authorId,
        authorNickname: authorNickname,
        authorProfileUrl: authorProfileUrl,
        text: text,
        imageFile: imageFile,
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
}

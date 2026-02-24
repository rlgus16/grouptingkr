import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/story_controller.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class CreateStoryView extends StatefulWidget {
  const CreateStoryView({super.key});

  @override
  State<CreateStoryView> createState() => _CreateStoryViewState();
}

class _CreateStoryViewState extends State<CreateStoryView> {
  final TextEditingController _textController = TextEditingController();
  File? _selectedImage;
  bool _isPosting = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1920,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storyImageSelectError)),
      );
    }
  }

  Future<void> _handlePost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      return; // Cannot post empty
    }

    final authController = context.read<AuthController>();
    final storyController = context.read<StoryController>();
    final user = authController.currentUserModel;

    if (user == null) return;

    setState(() {
      _isPosting = true;
    });

    try {
      await storyController.createStory(
        authorId: user.uid,
        authorNickname: user.nickname,
        authorGender: user.gender,
        authorProfileUrl: user.mainProfileImage,
        text: text.isNotEmpty ? text : null,
        imageFile: _selectedImage,
      );

      if (mounted) {
        Navigator.pop(context); // Go back once done
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonErrorWithValue(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isButtonEnabled = _textController.text.trim().isNotEmpty || _selectedImage != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.storyCreateTitle),
        actions: [
          TextButton(
            onPressed: (_isPosting || !isButtonEnabled) ? null : _handlePost,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Text(
                    l10n.storyCreatePostButton,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isButtonEnabled 
                          ? AppTheme.primaryColor 
                          : AppTheme.gray400,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: null,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: l10n.storyCreateContentHint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                  onPressed: _pickImage,
                  tooltip: 'Add Photo',
                ),
                // Additional media buttons could go here
              ],
            ),
          ),
        ],
      ),
    );
  }
}

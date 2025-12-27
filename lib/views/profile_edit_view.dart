import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/user_service.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'location_picker_view.dart';

class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _introductionController = TextEditingController();
  final _heightController = TextEditingController();
  final _activityAreaController = TextEditingController();

  double _latitude = 0.0;
  double _longitude = 0.0;

  List<dynamic> _imageSlots = List.filled(6, null);
  List<String> _imagesToDelete = [];
  final ImagePicker _picker = ImagePicker();
  bool _isPickerActive = false;
  int _mainProfileIndex = 0;

  bool _isCheckingNickname = false;
  String? _nicknameValidationMessage;
  String _originalNickname = '';
  String _originalActivityArea = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;

    if (user != null) {
      _nicknameController.text = user.nickname;
      _originalNickname = user.nickname;
      _introductionController.text = user.introduction;
      _heightController.text = user.height.toString();
      _activityAreaController.text = user.activityArea;
      _originalActivityArea = user.activityArea;

      _latitude = user.latitude;
      _longitude = user.longitude;

      List<String> originalImages = user.profileImages.where((imageUrl) {
        return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
      }).toList();

      for (int i = 0; i < _imageSlots.length; i++) {
        if (i < originalImages.length) {
          _imageSlots[i] = originalImages[i];
        } else {
          _imageSlots[i] = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introductionController.dispose();
    _heightController.dispose();
    _activityAreaController.dispose();
    super.dispose();
  }

  Future<void> _checkNicknameDuplicate(String nickname) async {
    final l10n = AppLocalizations.of(context)!;
    if (nickname.isEmpty || nickname.length < 2 || nickname.trim() == _originalNickname) {
      setState(() {
        _nicknameValidationMessage = null;
        _isCheckingNickname = false;
      });
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _nicknameValidationMessage = null;
    });

    try {
      final profileController = context.read<ProfileController>();
      final isDuplicate = await profileController.isNicknameDuplicate(nickname);

      if (mounted) {
        setState(() {
          _isCheckingNickname = false;
          _nicknameValidationMessage = isDuplicate ? l10n.profileEditNicknameDuplicate : l10n.profileEditNicknameAvailable;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingNickname = false;
          _nicknameValidationMessage = l10n.profileEditNicknameCheckError;
        });
      }
    }
  }

  Future<void> _selectSingleImage(int index) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isPickerActive) return;

    if (!kIsWeb && Platform.isAndroid) {
      PermissionStatus status = await Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.storage.request();
      }
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) _showPermissionDialog();
        return;
      }
    }

    try {
      _isPickerActive = true;
      final image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          if (_imageSlots[index] is String) {
            _imagesToDelete.add(_imageSlots[index] as String);
          }
          _imageSlots[index] = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEditImageError)),
        );
      }
    } finally {
      _isPickerActive = false;
    }
  }

  void _showPermissionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileEditPermissionTitle),
        content: Text(l10n.profileEditPermissionContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(l10n.profileEditGoToSettings),
          ),
        ],
      ),
    );
  }

  void _removeImageFromSlot(int index) {
    setState(() {
      final currentImage = _imageSlots[index];
      if (currentImage is String) {
        _imagesToDelete.add(currentImage);
      }
      _imageSlots[index] = null;

      if (_mainProfileIndex == index) {
        _mainProfileIndex = _imageSlots.indexWhere((img) => img != null);
        if (_mainProfileIndex == -1) _mainProfileIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: Text(l10n.myPageEditProfile),
        elevation: 0,
        backgroundColor: AppTheme.gray50,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          Consumer<ProfileController>(
            builder: (context, profileController, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: profileController.isLoading ? null : _saveProfile,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  child: profileController.isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(l10n.commonConfirm),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthController, ProfileController>(
        builder: (context, authController, profileController, _) {
          final user = authController.currentUserModel;
          if (user == null) return const Center(child: CircularProgressIndicator());

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profile Photos Section
                  _buildSectionHeader(l10n.registerPhotos),
                  _buildImageSection(l10n),

                  const SizedBox(height: 24),

                  // 2. Basic Info Section
                  _buildSectionHeader(l10n.profileDetailBasicInfo),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nicknameController,
                          label: l10n.registerNickname,
                          hint: l10n.registerNicknameHint,
                          icon: Icons.person_outline,
                          maxLength: 10,
                          onChanged: (value) {
                            setState(() {}); // Refresh to show cost indicator
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (_nicknameController.text == value) {
                                _checkNicknameDuplicate(value);
                              }
                            });
                          },
                          suffix: _isCheckingNickname
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                          validationMessage: _nicknameValidationMessage,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return l10n.profileEditNicknameEmpty;
                            if (value.trim().length < 2) return l10n.profileEditNicknameTooShort;
                            return null;
                          },
                          l10n: l10n,
                        ),
                        // 닉네임 변경 비용 안내 (처음 설정하는 경우는 표시 안함)
                        if (_originalNickname.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 14, color: AppTheme.warningColor),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.profileEditNicknameChangeCost,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _heightController,
                          label: l10n.registerHeight,
                          hint: l10n.profileEditHeightHint,
                          icon: Icons.height,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return l10n.profileEditHeightEmpty;
                            final height = int.tryParse(value.trim());
                            if (height == null || height < 140 || height > 220) return l10n.profileEditHeightRange;
                            return null;
                          },
                          l10n: l10n,
                        ),
                        const SizedBox(height: 20),
                        _buildLocationField(l10n),
                        // 활동지역 변경 비용 안내 (처음 설정하는 경우는 표시 안함)
                        if (_originalActivityArea.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 14, color: AppTheme.warningColor),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.profileEditActivityAreaChangeCost,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Introduction Section
                  _buildSectionHeader(l10n.profileDetailIntro),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextFormField(
                      controller: _introductionController,
                      decoration: InputDecoration(
                        hintText: l10n.registerIntroHint,
                        hintStyle: const TextStyle(color: AppTheme.gray400, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.gray50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 5,
                      maxLength: 200,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return l10n.profileEditIntroEmpty;
                        if (value.trim().length < 5) return l10n.profileEditIntroTooShort;
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Account Info Section (Read-only)
                  _buildSectionHeader(l10n.registerAccountInfo),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      children: [
                        _buildReadOnlyRow(l10n.profileEditEmailLabel, context.read<AuthController>().firebaseService.currentUser?.email ?? ''),
                        const Divider(height: 1, color: AppTheme.gray100),
                        _buildReadOnlyRow(l10n.registerPhone, _formatPhoneNumber(user.phoneNumber)),
                        const Divider(height: 1, color: AppTheme.gray100),
                        _buildReadOnlyRow(l10n.profileEditBirthDateLabel, _formatBirthDate(user.birthDate)),
                        const Divider(height: 1, color: AppTheme.gray100),
                        _buildReadOnlyRow(l10n.profileEditGenderLabel, user.gender == '남' ? l10n.myPageMale : l10n.myPageFemale),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Error message display
                  if (profileController.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              profileController.errorMessage!,
                              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- UI Component Methods ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  // Image section UI
  Widget _buildImageSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.registerPhotosLongPress,
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_imageSlots.where((e) => e != null).length}/6',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: itemWidth,
                    height: itemWidth,
                    child: _buildImageGridSlot(index, l10n),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageGridSlot(int index, AppLocalizations l10n) {
    final imageData = _imageSlots[index];
    final hasImage = imageData != null;
    final isMainProfile = index == _mainProfileIndex && hasImage;

    return GestureDetector(
      onTap: !hasImage ? () => _selectSingleImage(index) : null,
      onLongPress: hasImage ? () => _setMainProfile(index) : null,
      child: Container(
        decoration: BoxDecoration(
          color: hasImage ? Colors.white : AppTheme.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMainProfile ? AppTheme.primaryColor : AppTheme.gray200,
            width: isMainProfile ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Image display
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildImageWidget(imageData),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: AppTheme.gray400, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      l10n.registerPhotosAdd,
                      style: const TextStyle(color: AppTheme.gray400, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // Delete button
            if (hasImage)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImageFromSlot(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                  ),
                ),
              ),

            // Main profile tag
            if (isMainProfile)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.registerPhotosMain,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Custom text field builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required AppLocalizations l10n,
    TextInputType? keyboardType,
    int? maxLength,
    ValueChanged<String>? onChanged,
    Widget? suffix,
    String? validationMessage,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.gray400, fontSize: 14),
            prefixIcon: Icon(icon, color: AppTheme.gray400, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppTheme.gray50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.errorColor),
            ),
          ),
        ),
        if (validationMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              validationMessage,
              style: TextStyle(
                fontSize: 12,
                color: validationMessage == l10n.profileEditNicknameAvailable ? AppTheme.successColor : AppTheme.errorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // Location field
  Widget _buildLocationField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.registerActivityArea, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LocationPickerView()),
            );
            if (result != null) {
              if (result is Map<String, dynamic>) {
                setState(() {
                  _activityAreaController.text = result['address'];
                  _latitude = result['latitude'];
                  _longitude = result['longitude'];
                });
              } else if (result is String) {
                setState(() => _activityAreaController.text = result);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppTheme.gray400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _activityAreaController.text.isEmpty ? l10n.registerActivityAreaHint : _activityAreaController.text,
                    style: TextStyle(
                      color: _activityAreaController.text.isEmpty ? AppTheme.gray400 : AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.gray400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- Logic methods ---

  String _formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length == 11) {
      return '${phoneNumber.substring(0, 3)}-${phoneNumber.substring(3, 7)}-${phoneNumber.substring(7)}';
    }
    return phoneNumber;
  }

  String _formatBirthDate(String birthDate) {
    if (birthDate.length == 8) {
      return '${birthDate.substring(0, 4)}-${birthDate.substring(4, 6)}-${birthDate.substring(6)}';
    }
    return birthDate;
  }

  Widget _buildImageWidget(dynamic imageData) {
    if (imageData is XFile) {
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: imageData.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
            }
            return Container(color: AppTheme.gray100, child: const Center(child: CircularProgressIndicator()));
          },
        );
      } else {
        return Image.file(File(imageData.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
    } else if (imageData is String) {
      return _buildProfileImage(imageData);
    }
    return const SizedBox();
  }

  Widget _buildProfileImage(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(color: AppTheme.gray100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (context, url, error) => const Icon(Icons.person, color: AppTheme.textSecondary),
      );
    } else {
      return const Icon(Icons.person, color: AppTheme.textSecondary);
    }
  }

  void _setMainProfile(int index) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _mainProfileIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.profileEditMainPhotoChanged),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_nicknameValidationMessage == l10n.profileEditNicknameDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileEditNicknameDuplicate)));
      return;
    }

    final hasImages = _imageSlots.any((image) => image != null);
    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.registerPhotosMin)));
      return;
    }

    final profileController = context.read<ProfileController>();
    final authController = context.read<AuthController>();
    final user = authController.currentUserModel;
    if (user == null) return;

    // 닉네임 변경 시 10 Ting 차감 (처음 설정하는 경우는 무료)
    final newNickname = _nicknameController.text.trim();
    final isNicknameChanged = newNickname != _originalNickname && _originalNickname.isNotEmpty;
    
    // 활동지역 변경 시 5 Ting 차감 (처음 설정하는 경우는 무료)
    final newActivityArea = _activityAreaController.text.trim();
    final isActivityAreaChanged = newActivityArea != _originalActivityArea && _originalActivityArea.isNotEmpty;
    
    // 총 Ting 비용 계산
    int totalTingCost = 0;
    if (isNicknameChanged) totalTingCost += 10;
    if (isActivityAreaChanged) totalTingCost += 5;
    
    debugPrint('Nickname: original="$_originalNickname", new="$newNickname", changed=$isNicknameChanged');
    debugPrint('ActivityArea: original="$_originalActivityArea", new="$newActivityArea", changed=$isActivityAreaChanged');
    debugPrint('Total Ting Cost: $totalTingCost');
    
    // Ting 차감이 필요한 경우 확인 다이얼로그 표시
    if (totalTingCost > 0) {
      // 잔액 확인
      if (user.tingBalance < totalTingCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEditInsufficientTings)),
        );
        return;
      }
      
      // 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.profileEditTotalCostTitle),
          content: Text(l10n.profileEditTotalCostConfirm(totalTingCost)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.commonConfirm),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Ting 차감
      final userService = UserService();
      final deducted = await userService.deductTings(user.uid, totalTingCost);
      if (!deducted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.profileEditInsufficientTings)),
          );
        }
        return;
      }
    }

    for (String imageUrl in _imagesToDelete) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (e) {
        debugPrint('Image deletion failed: $e');
      }
    }

    List<String> finalImages = [];
    List<dynamic> sortedImageSlots = List.from(_imageSlots);

    if (_mainProfileIndex >= 0 && _mainProfileIndex < sortedImageSlots.length) {
      final mainImage = sortedImageSlots.removeAt(_mainProfileIndex);
      if (mainImage != null) {
        sortedImageSlots.insert(0, mainImage);
      }
    }

    for (final image in sortedImageSlots) {
      if (image is String) {
        finalImages.add(image);
      } else if (image is XFile) {
        try {
          final fileName = '${user.uid}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = FirebaseStorage.instance.ref().child('profile_images').child(user.uid).child(fileName);

          late UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            uploadTask = ref.putData(bytes);
          } else {
            uploadTask = ref.putFile(File(image.path));
          }

          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          finalImages.add(downloadUrl);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileEditUploadFailed)));
          }
          return;
        }
      }
    }

    final success = await profileController.updateProfile(
      nickname: _nicknameController.text.trim(),
      introduction: _introductionController.text.trim(),
      height: int.parse(_heightController.text.trim()),
      activityArea: _activityAreaController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      profileImages: finalImages,
    );

    if (success && mounted) {
      await authController.refreshCurrentUser();
      Navigator.pop(context);
    } else if (mounted && profileController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(profileController.errorMessage!)));
    }
  }
}
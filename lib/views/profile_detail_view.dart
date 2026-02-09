import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../controllers/auth_controller.dart';
import '../services/user_service.dart';

class ProfileDetailView extends StatefulWidget {
  final UserModel user;
  final String? openChatroomId;
  final bool isChatRoomOwner;
  final bool isTargetUserInChatroom;

  const ProfileDetailView({
    super.key, 
    required this.user,
    this.openChatroomId,
    this.isChatRoomOwner = false,
    this.isTargetUserInChatroom = true,
  });

  @override
  State<ProfileDetailView> createState() => _ProfileDetailViewState();
}

class _ProfileDetailViewState extends State<ProfileDetailView> {
  int _currentImageIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isExempted = false;
  int _userRating = 0; // 0 means no rating, 1-5 are actual ratings
  double _averageRating = 0.0; // Average rating from last 50 ratings

  @override
  void initState() {
    super.initState();
    _checkExemptionStatus();
    _fetchUserRating();
    _fetchAverageRating();
  }

  // Fetch average rating from last 50 ratings
  Future<void> _fetchAverageRating() async {
    try {
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('ratedUserId', isEqualTo: widget.user.uid)
          .get();

      if (ratingsQuery.docs.isEmpty) {
        if (mounted) {
          setState(() => _averageRating = 0.0);
        }
        return;
      }

      // Sort by updatedAt and take last 50
      final ratings = ratingsQuery.docs;
      ratings.sort((a, b) {
        final aTime = a.data()['updatedAt'] as Timestamp?;
        final bTime = b.data()['updatedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // descending order
      });

      // Take only the last 50 ratings
      final last50Ratings = ratings.take(50).toList();

      double sum = 0.0;
      for (var doc in last50Ratings) {
        final data = doc.data();
        sum += (data['rating'] ?? 0).toDouble();
      }

      final average = sum / last50Ratings.length;

      if (mounted) {
        setState(() => _averageRating = average);
      }
    } catch (e) {
      debugPrint('Error fetching average rating: $e');
      if (mounted) {
        setState(() => _averageRating = 0.0);
      }
    }
  }

  Future<void> _checkExemptionStatus() async {
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;
    
    final exemptDocId = '${currentUser.uid}_${widget.user.uid}';
    final doc = await FirebaseFirestore.instance
        .collection('matchExemptions')
        .doc(exemptDocId)
        .get();
    
    if (mounted) {
      setState(() {
        _isExempted = doc.exists;
      });
    }
  }

  // Fetch user's rating for this profile
  Future<void> _fetchUserRating() async {
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;
    
    final ratingDocId = '${currentUser.uid}_${widget.user.uid}';
    final doc = await FirebaseFirestore.instance
        .collection('ratings')
        .doc(ratingDocId)
        .get();
    
    if (mounted && doc.exists) {
      final data = doc.data();
      setState(() {
        _userRating = data?['rating'] ?? 0;
      });
    }
  }

  // Show rating dialog
  void _showRatingDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    int tempRating = _userRating;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.ratingDialogTitle(widget.user.nickname)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.ratingDialogPrompt, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => tempRating = starValue);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starValue <= tempRating ? Icons.star : Icons.star_border,
                        size: 40,
                        color: starValue <= tempRating ? Colors.pink : AppTheme.gray400,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: tempRating > 0 ? () async {
                await _saveRating(tempRating);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.ratingSaved)),
                  );
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.ratingDialogSubmit),
            ),
          ],
        ),
      ),
    );
  }

  // Save rating to Firestore
  Future<void> _saveRating(int rating) async {
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;
    
    final ratingDocId = '${currentUser.uid}_${widget.user.uid}';
    
    await FirebaseFirestore.instance.collection('ratings').doc(ratingDocId).set({
      'raterId': currentUser.uid,
      'ratedUserId': widget.user.uid,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    if (mounted) {
      setState(() => _userRating = rating);
      // Refresh average rating to reflect the new rating
      await _fetchAverageRating();
    }
  }

  // Remove user from chatroom functionality
  void _showRemoveFromChatroomDialog(BuildContext context) {
    if (widget.openChatroomId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('강퇴하기'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text('${widget.user.nickname}님을 내보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Implement removal logic here
                final chatroomRef = FirebaseFirestore.instance
                    .collection('openChatrooms')
                    .doc(widget.openChatroomId);

                await chatroomRef.update({
                  'participants': FieldValue.arrayRemove([widget.user.uid]),
                  'participantCount': FieldValue.increment(-1),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close profile view
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.user.nickname}님을 내보냈습니다.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('강퇴'),
          ),
        ],
      ),
    );
  }



  // Report user functionality
  void _showReportDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final reasons = [
      l10n.profileDetailReasonBadPhoto,
      l10n.profileDetailReasonAbuse,
      l10n.profileDetailReasonSpam,
      l10n.profileDetailReasonFraud,
      l10n.profileDetailReasonOther,
    ];
    String selectedReason = reasons[0];
    final ImagePicker picker = ImagePicker();
    XFile? attachedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.profileDetailReportTitle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profileDetailReportReason, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedReason = value);
                    }
                  },
                  child: Column(
                    children: reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppTheme.errorColor,
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: l10n.profileDetailReportContent,
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) setState(() => attachedImage = image);
                    } catch (e) {
                      debugPrint('Image selection error: $e');
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(attachedImage == null ? l10n.profileDetailReportPhoto : l10n.profileDetailReportPhotoChange),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.gray300),
                  ),
                ),
                if (attachedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.successColor, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            attachedImage!.name,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailReportEnterContent)),
                  );
                  return;
                }
                try {
                  final currentUser = context.read<AuthController>().currentUserModel;
                  if (currentUser == null) return;
                  Navigator.pop(context);

                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': currentUser.uid,
                    'reportedUserId': widget.user.uid,
                    'category': selectedReason,
                    'description': reasonController.text.trim(),
                    'hasImage': attachedImage != null,
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  await _sendReportEmail(
                    reporter: currentUser,
                    targetUser: widget.user,
                    category: selectedReason,
                    description: reasonController.text.trim(),
                    imagePath: attachedImage?.path,
                  );
                } catch (e) {
                  debugPrint('Report failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(l10n.profileDetailReportSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReportEmail({
    required UserModel reporter,
    required UserModel targetUser,
    required String category,
    required String description,
    String? imagePath,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    const String developerEmail = 'sprt.groupting@gmail.com';
    final String body = '''
[User Report]
- Reporter: ${reporter.nickname} (${reporter.uid})
- Target: ${targetUser.nickname} (${targetUser.uid})
- Reason: $category
- Content: $description
--------------------------------
App Version: 1.0.0
Platform: ${Theme.of(context).platform}
''';

    final Email email = Email(
      body: body,
      subject: '[Groupting Report] ${targetUser.nickname} User Report',
      recipients: [developerEmail],
      attachmentPaths: imagePath != null ? [imagePath] : null,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDetailEmailFailed)),
        );
      }
    }
  }

  // Block user functionality
  void _showBlockDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDetailBlockTitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.profileDetailBlockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = context.read<AuthController>().currentUserModel;
                if (currentUser == null) return;
                final blockDocId = '${currentUser.uid}_${widget.user.uid}';

                await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).set({
                  'blockerId': currentUser.uid,
                  'blockerNickname': currentUser.nickname,
                  'blockedId': widget.user.uid,
                  'blockedNickname': widget.user.nickname,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailBlocked)),
                  );
                }
              } catch (e) {
                debugPrint('Block failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.profileDetailBlock),
          ),
        ],
      ),
    );
  }

  // Exempt from matching functionality
  void _showExemptFromMatchingDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = context.read<AuthController>().currentUserModel;
    if (currentUser == null) return;
    
    // Check Ting balance first
    const int exemptionCost = 5;
    if (currentUser.tingBalance < exemptionCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileEditInsufficientTings)),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDetailExemptTitle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.profileDetailExemptConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authController = context.read<AuthController>();
                final user = authController.currentUserModel;
                if (user == null) return;
                
                // Deduct Ting first
                final userService = UserService();
                final deducted = await userService.deductTings(user.uid, exemptionCost);
                if (!deducted) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.profileEditInsufficientTings)),
                    );
                  }
                  return;
                }
                
                final exemptDocId = '${user.uid}_${widget.user.uid}';

                await FirebaseFirestore.instance.collection('matchExemptions').doc(exemptDocId).set({
                  'exempterId': user.uid,
                  'exempterNickname': user.nickname,
                  'exemptedId': widget.user.uid,
                  'exemptedNickname': widget.user.nickname,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  // Refresh user data to update Ting balance
                  await authController.refreshCurrentUser();
                  setState(() => _isExempted = true);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailExempted)),
                  );
                }
              } catch (e) {
                debugPrint('Exempt from matching failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.profileDetailExempt),
          ),
        ],
      ),
    );
  }

  // Unexempt from matching functionality
  void _showUnexemptDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDetailUnexempt),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(l10n.profileDetailUnexemptConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = context.read<AuthController>().currentUserModel;
                if (currentUser == null) return;
                final exemptDocId = '${currentUser.uid}_${widget.user.uid}';

                await FirebaseFirestore.instance.collection('matchExemptions').doc(exemptDocId).delete();

                if (mounted) {
                  setState(() => _isExempted = false);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileDetailUnexempted)),
                  );
                }
              } catch (e) {
                debugPrint('Unexempt failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l10n.profileDetailUnexempt),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.watch<AuthController>();
    final isBlocked = authController.blockedUserIds.contains(widget.user.uid);
    final isMe = authController.currentUserModel?.uid == widget.user.uid;
    final themeColor = widget.user.gender == '여' ? AppTheme.secondaryColor : AppTheme.primaryColor;

    if (isBlocked) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0, 
          backgroundColor: Colors.white, 
          foregroundColor: Colors.black,
          actions: isMe ? [] : [
            IconButton(
              icon: const Icon(Icons.more_vert, size: 28),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                          title: Text(l10n.profileDetailReport),
                          onTap: () {
                            Navigator.pop(context);
                            _showReportDialog(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            _isExempted ? Icons.person_add_outlined : Icons.person_off_outlined, 
                            color: _isExempted ? AppTheme.primaryColor : Colors.orange,
                          ),
                          title: Text(_isExempted ? l10n.profileDetailUnexempt : l10n.profileDetailExempt),
                          subtitle: _isExempted ? null : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.info_outline, size: 12, color: AppTheme.warningColor),
                              SizedBox(width: 4),
                              Text('5 Ting', style: TextStyle(color: AppTheme.warningColor, fontSize: 12)),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (_isExempted) {
                              _showUnexemptDialog(context);
                            } else {
                              _showExemptFromMatchingDialog(context);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.block_outlined, color: AppTheme.primaryColor),
                          title: Text(l10n.settingsUnblock),
                          onTap: () async {
                            final currentUser = context.read<AuthController>().currentUserModel;
                            if (currentUser == null) return;
                            final blockDocId = '${currentUser.uid}_${widget.user.uid}';
                            await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).delete();
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.profileDetailUnblocked)),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 60, color: AppTheme.gray400),
              const SizedBox(height: 16),
              Text(l10n.profileDetailBlockedUser, style: const TextStyle(color: AppTheme.gray600, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. SliverAppBar with flexible image header
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.55,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCircleButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: isMe ? [] : [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildCircleButton(
                  icon: Icons.more_vert,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isChatRoomOwner && widget.openChatroomId != null && widget.isTargetUserInChatroom)
                              ListTile(
                                leading: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor),
                                title: Text(
                                  '강퇴하기', // TODO: Add to l10n
                                  style: const TextStyle(color: AppTheme.errorColor),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showRemoveFromChatroomDialog(context);
                                },
                              ),
                            ListTile(
                              leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                              title: Text(l10n.profileDetailReport),
                              onTap: () {
                                Navigator.pop(context);
                                _showReportDialog(context);
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                _isExempted ? Icons.person_add_outlined : Icons.person_off_outlined, 
                                color: _isExempted ? AppTheme.primaryColor : Colors.orange,
                              ),
                              title: Text(_isExempted ? l10n.profileDetailUnexempt : l10n.profileDetailExempt),
                              subtitle: _isExempted ? null : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.info_outline, size: 12, color: AppTheme.warningColor),
                                  SizedBox(width: 4),
                                  Text('5 Ting', style: TextStyle(color: AppTheme.warningColor, fontSize: 12)),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                if (_isExempted) {
                                  _showUnexemptDialog(context);
                                } else {
                                  _showExemptFromMatchingDialog(context);
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.block, color: Colors.red),
                              title: Text(l10n.profileDetailBlock),
                              onTap: () {
                                Navigator.pop(context);
                                _showBlockDialog(context);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image slider
                  PageView.builder(
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemCount: widget.user.profileImages.length,
                    itemBuilder: (context, index) {
                      return _buildProfileImage(widget.user.profileImages[index]);
                    },
                  ),
                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha:0.4)],
                        ),
                      ),
                    ),
                  ),
                  // Page indicator
                  if (widget.user.profileImages.length > 1)
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.user.profileImages.length,
                              (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index ? Colors.white : Colors.white.withValues(alpha:0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Bottom sheet style info container
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and age header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.user.nickname,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Pretender',
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: themeColor.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      l10n.myPageAge(widget.user.age),
                                      style: TextStyle(
                                        color: themeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Rating display - show for all profiles
                        GestureDetector(
                          onTap: isMe ? null : () {
                            if (_userRating > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.ratingAlreadyRated)),
                              );
                            } else {
                              _showRatingDialog(context);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 20, color: Colors.pink),
                                const SizedBox(width: 4),
                                Text(
                                  _averageRating > 0 ? '${_averageRating.toStringAsFixed(1)}/5' : '0.0/5',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: AppTheme.gray200),
                    const SizedBox(height: 32),

                    // Basic info (chip style)
                    Text(l10n.profileDetailBasicInfo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInfoChip(Icons.height_rounded, '${widget.user.height}cm'),
                        _buildInfoChip(Icons.location_on_outlined, widget.user.activityArea),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Introduction
                    if (widget.user.introduction.isNotEmpty) ...[
                      Text(l10n.profileDetailIntro, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.gray50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.user.introduction,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Circle button widget for app bar
  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 24),
      ),
    );
  }

  // Info chip widget
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Profile image widget (Cover mode)
  Widget _buildProfileImage(String imageUrl) {
    ImageProvider? imageProvider;

    if (imageUrl.startsWith('local://') || imageUrl.startsWith('temp://')) {
      final path = imageUrl.startsWith('local://') ? imageUrl.substring(8) : imageUrl.substring(7);
      imageProvider = FileImage(File(path));
    } else {
      imageProvider = CachedNetworkImageProvider(imageUrl);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray200,
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
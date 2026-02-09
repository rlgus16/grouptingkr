import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../controllers/auth_controller.dart';
import '../services/user_service.dart';
import '../utils/user_action_helper.dart';

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
                  UserActionHelper.showUserOptionsBottomSheet(
                    context: context,
                    targetUser: widget.user,
                    openChatroomId: widget.openChatroomId,
                    isChatRoomOwner: widget.isChatRoomOwner,
                    isTargetUserInChatroom: widget.isTargetUserInChatroom,
                    onExemptionChanged: (isExempted) {
                      if (mounted) setState(() => _isExempted = isExempted);
                    },
                    onBlockChanged: (isBlocked) {
                       if (mounted) setState(() {});
                    }
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
                    UserActionHelper.showUserOptionsBottomSheet(
                      context: context,
                      targetUser: widget.user,
                      openChatroomId: widget.openChatroomId,
                      isChatRoomOwner: widget.isChatRoomOwner,
                      isTargetUserInChatroom: widget.isTargetUserInChatroom,
                      onExemptionChanged: (isExempted) {
                        if (mounted) setState(() => _isExempted = isExempted);
                      },
                      onBlockChanged: (isBlocked) {
                         if (mounted) setState(() {});
                      }
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
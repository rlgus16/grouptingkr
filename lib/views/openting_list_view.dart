import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/custom_toast.dart';
import '../widgets/member_avatar.dart';
import '../models/user_model.dart';
import 'profile_detail_view.dart';

class OpenChatroomListView extends StatefulWidget {
  const OpenChatroomListView({super.key});

  @override
  State<OpenChatroomListView> createState() => _OpenChatroomListViewState();
}

class _OpenChatroomListViewState extends State<OpenChatroomListView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _joiningRooms = <String>{};
  int _selectedMaxParticipants = 10;
  double _maxDistance = 100.0; // Distance filter in km

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _showCreateRoomDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(l10n.opentingCreateRoomTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.opentingRoomTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: l10n.opentingRoomTitleHint,
                        hintStyle: const TextStyle(color: AppTheme.gray400),
                        filled: true,
                        fillColor: AppTheme.gray50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.opentingMaxParticipants,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedMaxParticipants,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.gray600),
                          items: List.generate(9, (index) => index + 2)
                              .map((number) => DropdownMenuItem<int>(
                                    value: number,
                                    child: Text(
                                      l10n.opentingParticipantsCount(number),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMaxParticipants = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () {
                    _titleController.clear();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppTheme.gray600),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () async {
                    if (_titleController.text.trim().isEmpty) {
                      CustomToast.showError(context, l10n.opentingEnterRoomTitle);
                      return;
                    }
                    Navigator.pop(context);
                    await _createOpenChatroom();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createOpenChatroom() async {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;

    if (currentUser == null) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.chatInputHint);
      }
      return;
    }

    try {
      final now = DateTime.now();
      final chatroomData = {
        'title': _titleController.text.trim(),
        'creatorId': currentUser.uid,
        'creatorNickname': currentUser.nickname ?? 'Unknown',
        'participants': [currentUser.uid],
        'participantCount': 1,
        'maxParticipants': _selectedMaxParticipants,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isActive': true,
      };

      await _firestore.collection('openChatrooms').add(chatroomData);

      _titleController.clear();

      if (mounted) {
        CustomToast.showSuccess(context, AppLocalizations.of(context)!.opentingCreateSuccess);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.opentingCreateFailed);
      }
    }
  }

  Future<void> _joinChatroom(String roomId, List<dynamic> participants, int participantCount, int maxParticipants) async {
    if (_joiningRooms.contains(roomId)) return;

    final authController = context.read<AuthController>();
    final currentUser = authController.currentUserModel;

    if (currentUser == null) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.chatInputHint);
      }
      return;
    }

    if (participants.contains(currentUser.uid)) {
      // Already joined, nothing to do (user will see chat view automatically)
      return;
    }

    // Check if chatroom is full
    if (participantCount >= maxParticipants) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.opentingRoomFull(maxParticipants));
      }
      return;
    }

    setState(() {
      _joiningRooms.add(roomId);
    });

    try {
      await _firestore.collection('openChatrooms').doc(roomId).update({
        'participants': FieldValue.arrayUnion([currentUser.uid]),
        'participantCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        CustomToast.showSuccess(context, AppLocalizations.of(context)!.opentingJoinSuccess);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, AppLocalizations.of(context)!.opentingJoinFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _joiningRooms.remove(roomId);
        });
      }
    }
  }

  Future<UserModel?> _fetchSingleProfile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
    } catch (e) {
      // Failed to load user
    }
    return null;
  }

  Future<List<QueryDocumentSnapshot>> _filterChatroomsByDistance(
    List<QueryDocumentSnapshot> chatrooms,
    UserModel? currentUser,
  ) async {
    if (currentUser == null || _maxDistance >= 100) {
      return chatrooms; // No filtering if not logged in or max distance
    }

    if (currentUser.latitude == 0 || currentUser.longitude == 0) {
      return chatrooms; // No filtering if user has no location
    }

    final List<QueryDocumentSnapshot> filtered = [];

    for (final chatroom in chatrooms) {
      final data = chatroom.data() as Map<String, dynamic>;
      final creatorId = data['creatorId'] ?? '';

      try {
        final creatorProfile = await _fetchSingleProfile(creatorId);
        if (creatorProfile != null) {
          // Calculate distance
          if (creatorProfile.latitude != 0 && creatorProfile.longitude != 0) {
            final distance = Geolocator.distanceBetween(
              currentUser.latitude,
              currentUser.longitude,
              creatorProfile.latitude,
              creatorProfile.longitude,
            ) / 1000; // Convert to km

            if (distance <= _maxDistance) {
              filtered.add(chatroom);
            }
          } else {
            // Include chatrooms where creator has no location
            filtered.add(chatroom);
          }
        }
      } catch (e) {
        // Include chatrooms where we can't fetch creator profile
        filtered.add(chatroom);
      }
    }

    return filtered;
  }

  void _showDistanceFilterSheet() {
    final l10n = AppLocalizations.of(context)!;
    double currentDistance = _maxDistance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.gray300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.opentingDistanceFilter,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gray800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Distance Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.opentingMaxDistance,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray700,
                        ),
                      ),
                      Text(
                        currentDistance >= 100 ? "100km+" : "${currentDistance.round()}km",
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: AppTheme.gray200,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                    ),
                    child: Slider(
                      value: currentDistance,
                      min: 2,
                      max: 100,
                      divisions: 49,
                      onChanged: (double value) {
                        setModalState(() => currentDistance = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Apply Button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _maxDistance = currentDistance;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.homeFilterApply,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authController = context.watch<AuthController>();
    final currentUserId = authController.currentUserModel?.uid;

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: const Text('오픈팅'),
        backgroundColor: AppTheme.gray50,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            iconSize: 28,
            tooltip: l10n.opentingDistanceFilter,
            onPressed: _showDistanceFilterSheet,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('openChatrooms')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(l10n.opentingLoadError);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          }

          final chatrooms = snapshot.data?.docs ?? [];

          if (chatrooms.isEmpty) {
            return _buildEmptyState(l10n);
          }

          // Filter chatrooms by distance
          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _filterChatroomsByDistance(chatrooms, authController.currentUserModel),
            builder: (context, distanceSnapshot) {
              if (distanceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                );
              }

              final filteredChatrooms = distanceSnapshot.data ?? [];

              if (filteredChatrooms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.filter_list_off,
                          size: 48,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.opentingNoRoomsFound,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.opentingAdjustFilter(_maxDistance.round()),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: filteredChatrooms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final chatroom = filteredChatrooms[index];
                  final data = chatroom.data() as Map<String, dynamic>;
              final roomId = chatroom.id;
              final title = data['title'] ?? 'Untitled';
              final creatorId = data['creatorId'] ?? '';
              final creatorNickname = data['creatorNickname'] ?? 'Unknown';
              final participantCount = data['participantCount'] ?? 0;
              final maxParticipants = data['maxParticipants'] ?? 10;
              final participants = List<dynamic>.from(data['participants'] ?? []);
              final isJoining = _joiningRooms.contains(roomId);
              final hasJoined = currentUserId != null && participants.contains(currentUserId);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.softShadow,
                  border: Border.all(color: AppTheme.gray100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Owner's avatar (larger, tappable)
                          FutureBuilder<UserModel?>(
                            future: _fetchSingleProfile(creatorId),
                            builder: (context, snapshot) {
                              final ownerProfile = snapshot.data;
                              return GestureDetector(
                                onTap: ownerProfile != null
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProfileDetailView(user: ownerProfile),
                                          ),
                                        );
                                      }
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: MemberAvatar(
                                    imageUrl: ownerProfile?.mainProfileImage ?? '',
                                    name: creatorNickname,
                                    isOwner: true,
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    fontFamily: 'Pretendard',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.group_outlined,
                                      size: 14,
                                      color: AppTheme.gray500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$participantCount/$maxParticipants',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (hasJoined || isJoining)
                              ? null
                              : () => _joinChatroom(roomId, participants, participantCount, maxParticipants),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasJoined
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isJoining
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  hasJoined ? l10n.opentingJoined : l10n.opentingJoinRoom,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Pretendard',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.opentingCreateRoom,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.opentingNoRooms,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.opentingBeFirst,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

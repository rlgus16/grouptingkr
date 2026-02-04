import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:groupting/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../utils/app_theme.dart';
import '../widgets/member_avatar.dart';
import '../l10n/generated/app_localizations.dart';
import 'invite_friend_view.dart';
import 'invitation_list_view.dart';
import 'profile_detail_view.dart';
import 'my_page_view.dart';
import 'chat_view.dart';
import 'profile_edit_view.dart';
import 'openting_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chatroom_service.dart';
import '../models/chatroom_model.dart';

// 프로필 검증 결과 클래스
class ProfileValidationResult {
  final bool isValid;
  final List<String> missingFields;

  ProfileValidationResult({
    required this.isValid,
    required this.missingFields,
  });
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

// SingleTickerProviderStateMixin (애니메이션 사용을 위해 필요)
class _HomeViewState extends State<HomeView> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ChatroomService _chatroomService = ChatroomService();
  bool _isProfileCardHidden = false;
  GroupController? _groupController; // 컨트롤러 인스턴스 저장
  late AnimationController _animationController; // 애니메이션 컨트롤러 정의

  @override
  void initState() {
    super.initState();
    // 앱 생명주기 감지 시작
    WidgetsBinding.instance.addObserver(this);

    // 애니메이션 컨트롤러 초기화 (2초마다 반복 회전)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // 반복 실행

    // 로그인 상태 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });

    // 프로필 카드 숨김 상태 로드
    _loadProfileCardVisibility();

    // 그룹 컨트롤러 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _groupController = context.read<GroupController>();
        await _groupController!.initialize();

        // 매칭 완료 콜백 설정
        _groupController!.onMatchingCompleted = _onMatchingCompleted;
      }
    });
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러 해제
    _animationController.dispose();

    // 매칭 완료 콜백 제거 (안전하게 처리)
    try {
      _groupController?.onMatchingCompleted = null;
    } catch (e) {
      debugPrint('GroupController 콜백 제거 중 에러 (무시됨): $e');
    }

    // 앱 생명주기 감지 해제
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 로그인 상태 체크
  void _checkLoginStatus() {
    final authController = context.read<AuthController>();
    if (!authController.isLoggedIn) {
      // 로그인되지 않았으면 로그인 화면으로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      });
    }
  }

  // 프로필 카드 숨김 상태 로드
  Future<void> _loadProfileCardVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authController = context.read<AuthController>();
      final userId = authController.currentUserModel?.uid ??
          authController.firebaseService.currentUser?.uid;

      if (userId != null) {
        final isHidden = prefs.getBool('profile_card_hidden_$userId') ?? false;
        if (mounted) {
          setState(() {
            _isProfileCardHidden = isHidden;
          });
        }
      }
    } catch (e) {
      debugPrint('프로필 카드 상태 로드 실패: $e');
    }
  }

  // 프로필 카드 숨김 상태 저장
  Future<void> _hideProfileCard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authController = context.read<AuthController>();
      final userId = authController.currentUserModel?.uid ??
          authController.firebaseService.currentUser?.uid;

      if (userId != null) {
        await prefs.setBool('profile_card_hidden_$userId', true);
        if (mounted) {
          setState(() {
            _isProfileCardHidden = true;
          });

          try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.homeProfileCardHidden),
                  duration: Duration(seconds: 3),
                ),
              );
          } catch (e) {
            // 위젯이 이미 dispose된 경우 무시
          }
        }
      }
    } catch (e) {
      debugPrint('프로필 카드 숨김 실패: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && mounted) {
      // 앱이 포그라운드로 돌아왔을 때 자동 새로고침
      try {
        final groupController = _groupController ?? context.read<GroupController>();
        groupController.onAppResumed();
      } catch (e) {
        debugPrint('앱 생명주기 변경 중 GroupController 접근 실패: $e');
      }
    }
  }

  // 매칭 완료 시 처리 - 개선된 버전
  void _onMatchingCompleted() {
    if (!mounted) return;

    // 상대방 그룹 정보 가져오기
    final groupController = _groupController ?? context.read<GroupController>();
    final currentGroup = groupController.currentGroup;

    String dialogContent = AppLocalizations.of(context)!.homeMatchSuccessDesc;

    if (currentGroup != null) {
      dialogContent = AppLocalizations.of(context)!.homeMatchSuccessDesc;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.successColor),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.homeMatchSuccess),
          ],
        ),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.homeLater),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 짧은 딩레이 후 채팅방 이동 (매칭 데이터 동기화 대기)
              Future.delayed(const Duration(milliseconds: 500), () {
                _navigateToChat();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.homeGoToChat),
          ),
        ],
      ),
    );
  }

  String _getChatRoomId(GroupController groupController) {
    if (groupController.currentGroup == null) return '';

    if (groupController.isMatched &&
        groupController.currentGroup!.matchedGroupId != null) {
      final currentGroupId = groupController.currentGroup!.id;
      final matchedGroupId = groupController.currentGroup!.matchedGroupId!;
      return currentGroupId.compareTo(matchedGroupId) < 0
          ? '${currentGroupId}_${matchedGroupId}'
          : '${matchedGroupId}_${currentGroupId}';
    } else {
      return groupController.currentGroup!.id;
    }
  }

  // 채팅방으로 이동
  void _navigateToChat() {
    if (!mounted) return;

    try {
      final groupController = _groupController ?? context.read<GroupController>();

      if (groupController.currentGroup != null) {
        String chatRoomId;

        // 매칭된 경우 통합 채팅방 ID 사용
        if (groupController.isMatched &&
            groupController.currentGroup!.matchedGroupId != null) {
          // 두 그룹 ID 중 작은 것을 채팅방 ID로 사용 (일관성 보장)
          final currentGroupId = groupController.currentGroup!.id;
          final matchedGroupId = groupController.currentGroup!.matchedGroupId!;
          chatRoomId = currentGroupId.compareTo(matchedGroupId) < 0
              ? '${currentGroupId}_${matchedGroupId}'
              : '${matchedGroupId}_${currentGroupId}';
        } else {
          // 매칭되지 않은 경우 기존 그룹 ID 사용
          chatRoomId = groupController.currentGroup!.id;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatView(groupId: chatRoomId),
          ),
        );
      }
    } catch (e) {
      debugPrint('채팅방 이동 중 에러: $e');
    }
  }

// 매칭 필터 설정 다이얼로그
  void _showMatchFilterDialog() {
    final groupController = context.read<GroupController>();
    final group = groupController.currentGroup;

    // --- 초기값 설정 ---
    double initMinAge = (group?.minAge.toDouble() ?? 19.0).clamp(19.0, 60.0);
    double initMaxAge = (group?.maxAge.toDouble() ?? 60.0).clamp(19.0, 60.0);
    if (initMinAge > initMaxAge) initMinAge = initMaxAge;
    RangeValues currentAgeRange = RangeValues(initMinAge, initMaxAge);

    double initMinHeight = (group?.minHeight.toDouble() ?? 150.0).clamp(150.0, 190.0);
    double initMaxHeight = (group?.maxHeight.toDouble() ?? 190.0).clamp(150.0, 190.0);
    if (initMinHeight > initMaxHeight) initMinHeight = initMaxHeight;
    RangeValues currentHeightRange = RangeValues(initMinHeight, initMaxHeight);

    double initMaxDistance = (group?.maxDistance.toDouble() ?? 100.0).clamp(2.0, 100.0);
    double currentDistance = initMaxDistance;

    String selectedGender = group?.preferredGender ?? '상관없음';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSaving = false;

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
                  // 상단 핸들 바
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

                  // 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.homeFilterTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gray800,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.gray600),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 성별 섹션
                  _buildFilterSectionTitle(AppLocalizations.of(context)!.homeFilterGender),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterMale, selectedGender, (val) => setModalState(() => selectedGender = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterFemale, selectedGender, (val) => setModalState(() => selectedGender = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterMixed, selectedGender, (val) => setModalState(() => selectedGender = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterAny, selectedGender, (val) => setModalState(() => selectedGender = val))),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 나이 섹션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFilterSectionTitle(AppLocalizations.of(context)!.homeFilterAge),
                      Text(
                        '${currentAgeRange.start.round()}세 - ${currentAgeRange.end.round() >= 60 ? "60세+" : "${currentAgeRange.end.round()}세"}',
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
                      overlayColor: AppTheme.primaryColor.withValues(alpha:0.1),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                    ),
                    child: RangeSlider(
                      values: currentAgeRange,
                      min: 19,
                      max: 60,
                      divisions: 41,
                      onChanged: (RangeValues values) {
                        setModalState(() => currentAgeRange = values);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 키 섹션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFilterSectionTitle(AppLocalizations.of(context)!.homeFilterHeight),
                      Text(
                        '${currentHeightRange.start.round()}cm - ${currentHeightRange.end.round() >= 190 ? "190cm+" : "${currentHeightRange.end.round()}cm"}',
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
                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                    ),
                    child: RangeSlider(
                      values: currentHeightRange,
                      min: 150,
                      max: 190,
                      divisions: 40,
                      onChanged: (RangeValues values) {
                        setModalState(() => currentHeightRange = values);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 거리 섹션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFilterSectionTitle(AppLocalizations.of(context)!.homeFilterDistance),
                      Text(
                        currentDistance >= 100 ? "100km+" : "${currentDistance.round()}km 이내",
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

                  const SizedBox(height: 40),

                  // 적용 버튼
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      setModalState(() => isSaving = true);
                      try {
                        final success = await groupController.saveMatchFilters(
                          preferredGender: selectedGender,
                          minAge: currentAgeRange.start.round(),
                          maxAge: currentAgeRange.end.round() >= 60 ? 100 : currentAgeRange.end.round(),
                          minHeight: currentHeightRange.start.round(),
                          maxHeight: currentHeightRange.end.round() >= 190 ? 200 : currentHeightRange.end.round(),
                          maxDistance: currentDistance.round() >= 100 ? 50000 : currentDistance.round(),
                        );

                        if (!mounted) return;
                        Navigator.pop(context);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.homeFilterSuccess),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(groupController.errorMessage ?? AppLocalizations.of(context)!.homeFilterFailed)),
                          );
                        }
                      } catch (e) {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    )
                        : Text(
                      AppLocalizations.of(context)!.homeFilterApply,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 섹션 타이틀 위젯
  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.gray700,
      ),
    );
  }

  // 개선된 성별 선택 칩 위젯
  Widget _buildGenderChip(String label, String currentSelection, Function(String) onSelected) {
    final bool isSelected = label == currentSelection;
    // '상관없음' 텍스트가 너무 길 경우를 대비해 폰트 사이즈 조정
    final double fontSize = label.length > 3 ? 12 : 13;

    return GestureDetector(
      onTap: () => onSelected(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.gray300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha:0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.gray600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: fontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final authController = context.read<AuthController>();
        final groupController = context.read<GroupController>();

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들 바
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 메뉴 아이템들
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(AppLocalizations.of(context)!.homeMenuReceivedInvites),
                trailing: groupController.receivedInvitations.isNotEmpty
                    ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${groupController.receivedInvitations.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvitationListView(),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(AppLocalizations.of(context)!.homeMenuMyPage),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyPageView()),
                  );
                },
              ),

              const Divider(height: 1),

              if (groupController.currentGroup != null)
                ListTile(
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: AppTheme.errorColor,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.homeMenuLeaveGroup,
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmed = await _showLeaveGroupDialog();
                    if (confirmed) {
                      final success = await groupController.leaveGroup();
                      if (success && mounted) {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.homeLeaveGroupSuccess)),
                          );
                          // UI 새로고침을 위해 setState 호출
                          setState(() {});
                        } catch (e) {
                          // 위젯이 이미 dispose된 경우 무시
                        }
                      } else if (mounted &&
                          groupController.errorMessage != null) {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(groupController.errorMessage!)),
                          );
                        } catch (e) {
                          // 위젯이 이미 dispose된 경우 무시
                        }
                      }
                    }
                  },
                ),

              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                  title: Text(
                    AppLocalizations.of(context)!.homeMenuLogout,
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _showLogoutDialog();
                  if (confirmed) {
                    try {
                      debugPrint('홈 화면에서 로그아웃 시작');
                      await authController.signOut();
                      debugPrint('홈 화면에서 로그아웃 완료');

                      // AuthWrapper가 자동으로 LoginView로 전환되지만,
                      // 혹시 모를 경우를 대비해 수동 네비게이션도 추가
                      if (context.mounted) {
                        // 잠시 대기 후 상태 확인
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (!authController.isLoggedIn) {
                          debugPrint('로그아웃 확인됨, LoginView로 네비게이션 대기 중...');
                          // AuthWrapper가 처리하도록 대기
                        } else {
                          debugPrint('⚠️ 로그아웃 후에도 로그인 상태가 남아있음 - 강제 네비게이션');
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                                (route) => false,
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('로그아웃 중 오류: $e');
                      if (context.mounted) {
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${AppLocalizations.of(context)!.homeLogoutError}: $e')),
                          );
                        } catch (scaffoldError) {
                          // 위젯이 이미 dispose된 경우 무시
                        }
                      }
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showLeaveGroupDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.homeLeaveGroupTitle),
        content: Text(AppLocalizations.of(context)!.homeLeaveGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: Text(AppLocalizations.of(context)!.homeLeaveGroupBtn),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<bool> _showLogoutDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.homeLogoutTitle),
        content: Text(AppLocalizations.of(context)!.homeLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: Text(AppLocalizations.of(context)!.homeMenuLogout),
          ),
        ],
      ),
    ) ??
        false;
  }






  // 프로필 카드 표시 여부 결정 (새로운 로직)
  bool _shouldShowProfileCard(AuthController authController) {
    final user = authController.currentUserModel;
    final firebaseUser = authController.firebaseService.currentUser;

    // 1. 사용자 데이터가 없는 경우 - 계정 자체에 문제가 있음
    if (user == null || firebaseUser?.email == null) {
      return true; // 회원가입 유도
    }

    // 2. 기본 정보 부족 여부 체크
    final hasBasicInfo = user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty;

    if (!hasBasicInfo) {
      return true; // 기본 정보 입력 유도
    }

    // 3. 프로필 완성 여부 체크
    final hasCompleteProfile = user.nickname.isNotEmpty &&
        user.height > 0 &&
        user.activityArea.isNotEmpty &&
        user.introduction.isNotEmpty;

    if (!hasCompleteProfile) {
      return true; // 프로필 완성 유도
    }

    // 4. 모든 정보가 완성된 경우
    return false;
  }

  // 프로필 카드 상태별 메시지 생성 (새로운 로직)
  String _getProfileCardTitle(UserModel? user, User? firebaseUser, AppLocalizations l10n) {
    if (user == null || firebaseUser?.email == null) {
      return l10n.homeProfileSignup;
    }

    final hasBasicInfo = user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty;

    if (!hasBasicInfo) {
      return l10n.homeProfileBasicInfo;
    }

    return l10n.homeProfileComplete;
  }

  String _getProfileCardSubtitle(UserModel? user, User? firebaseUser, AppLocalizations l10n) {
    if (user == null || firebaseUser?.email == null) {
      return l10n.homeProfileSignupDesc;
    }

    final hasBasicInfo = user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty;

    if (!hasBasicInfo) {
      return l10n.homeProfileBasicInfoDesc;
    }

    return l10n.homeProfileCompleteDesc;
  }

  String _getProfileCardDescription(UserModel? user, User? firebaseUser, AppLocalizations l10n) {
    if (user == null || firebaseUser?.email == null) {
      return l10n.homeProfileSignupDesc;
    }

    final hasBasicInfo = user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty;

    if (!hasBasicInfo) {
      return l10n.homeProfileBasicInfoLong;
    }

    return l10n.homeProfileCompleteLong;
  }

  String _getProfileCardButtonText(UserModel? user, User? firebaseUser, AppLocalizations l10n) {
    if (user == null || firebaseUser?.email == null) {
      return l10n.homeProfileSignup;
    }

    final hasBasicInfo = user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty;

    if (!hasBasicInfo) {
      return l10n.homeProfileBasicInfo;
    }

    return l10n.homeProfileNow;
  }

  void _handleProfileCardAction(UserModel? user, User? firebaseUser) {
    if (user == null || firebaseUser?.email == null) {
      // 회원가입 페이지로 이동
      Navigator.pushNamed(context, '/register');
      return;
    }

    final hasBasicInfo = user.phoneNumber.isNotEmpty &&
        user.birthDate.isNotEmpty &&
        user.gender.isNotEmpty;

    if (!hasBasicInfo) {
      // 기본 정보가 부족한 경우 회원가입 페이지로 이동 (기본 정보 입력용)
      Navigator.pushNamed(context, '/register');
    } else {
      // 프로필 완성 페이지로 이동
      Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileEditView()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // 홈 화면이므로 0
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.gray400,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        onTap: (index) {
          switch (index) {
            case 0:
            // 이미 홈 화면이므로 아무것도 하지 않음
              break;
            case 1:
            // 받은 초대
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvitationListView(),
                ),
              );
              break;
            case 2:
            // 마이페이지
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyPageView()),
              );
              break;
            case 3:
            // 오픈팅
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OpentingView(),
                ),
              );
              break;
          }
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: AppLocalizations.of(context)!.homeNavHome),
          BottomNavigationBarItem(
            icon: Consumer<GroupController>(
              builder: (context, groupController, _) {
                if (groupController.receivedInvitations.isNotEmpty) {
                  return Stack(
                    children: [
                      const Icon(Icons.mail_outline),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const Icon(Icons.mail_outline);
              },
            ),
            label: AppLocalizations.of(context)!.homeNavInvitations,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: AppLocalizations.of(context)!.homeNavMyPage,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.forum_outlined),
            label: AppLocalizations.of(context)!.opentingTitle,
          ),
        ],
      ),
      body: Container(
        color: AppTheme.surfaceColor, // 전체 배경색 변경
        child: SafeArea(
          child: Column(
            children: [
              // 커스텀 헤더
              _buildCustomHeader(),

              Expanded(
                child: Consumer2<GroupController, AuthController>(
                  builder: (context, groupController, authController, _) {
                    if (authController.isLoggedIn) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        groupController.updateBlockedUsers(authController.blockedUserIds);
                      });
                    }

                    // 로그인 상태 실시간 체크
                    if (!authController.isLoggedIn) {
                      // ... (기존 로직 유지)
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                                (route) => false,
                          );
                        }
                      });
                      return const Center(child: CircularProgressIndicator());
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 프로필 미완성 카드
                          if (!_isProfileCardHidden && _shouldShowProfileCard(authController)) ...[
                            _buildProfileIncompleteCard(),
                            const SizedBox(height: 24),
                          ],

                          // 현재 그룹 상태 처리
                          if (groupController.isLoading) ...[
                            _buildLoadingCard(),
                          ] else if (groupController.errorMessage != null) ...[
                            _buildErrorCard(groupController),
                          ] else if (groupController.currentGroup != null) ...[
                            // 그룹 상태 카드 (그라디언트 적용)
                            _buildGroupStatusCard(groupController),
                            const SizedBox(height: 24),

                            // 멤버 섹션
                            _buildGroupMembersSection(groupController, authController),
                            const SizedBox(height: 100), // 하단 여백 확보
                          ] else ...[
                            _buildNoGroupCard(),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildProfileIncompleteCard() {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        final user = authController.currentUserModel;
        final firebaseUser = authController.firebaseService.currentUser;

        // 디버깅용 로그
        if (user != null) {
          debugPrint('홈 화면 - 사용자 정보: uid=${user.uid}, email=${firebaseUser?.email ?? ""}, phone=${user.phoneNumber}, isComplete=${user.isProfileComplete}');
        } else {
          debugPrint('홈 화면 - 사용자 정보 없음 (currentUserModel이 null)');
          debugPrint('홈 화면 - Firebase Auth 상태: ${authController.isLoggedIn}');
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.orange.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getProfileCardTitle(user, firebaseUser, AppLocalizations.of(context)!),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getProfileCardSubtitle(user, firebaseUser, AppLocalizations.of(context)!),
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _getProfileCardDescription(user, firebaseUser, AppLocalizations.of(context)!),
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _hideProfileCard,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade600,
                          side: BorderSide(color: Colors.orange.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(AppLocalizations.of(context)!.homeLater),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleProfileCardAction(user, firebaseUser),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(_getProfileCardButtonText(user, firebaseUser, AppLocalizations.of(context)!)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 로딩 상태 카드
  Widget _buildLoadingCard() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.homeLoadingGroup,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.homeLoadingWait,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 에러 상태 카드
  Widget _buildErrorCard(GroupController groupController) {
    final isNetworkError = groupController.errorMessage?.contains('firestore') == true ||
        groupController.errorMessage?.contains('network') == true ||
        groupController.errorMessage?.contains('connection') == true ||
        groupController.errorMessage?.contains('resolve host') == true;

    return Center(
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNetworkError ? Icons.wifi_off : Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                isNetworkError ? AppLocalizations.of(context)!.homeErrorNetwork : AppLocalizations.of(context)!.homeErrorLoad,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isNetworkError
                    ? AppLocalizations.of(context)!.homeErrorNetworkDesc
                    : groupController.errorMessage ?? AppLocalizations.of(context)!.homeErrorUnknown,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await groupController.refreshData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context)!.homeErrorRetry),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (isNetworkError) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () {
                        // 네트워크 설정으로 이동하거나 오프라인 모드 안내
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.homeErrorCheckConnectionDesc),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: Text(AppLocalizations.of(context)!.homeErrorCheckConnection),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoGroupCard() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add_rounded, size: 48, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.homeNoGroup,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.homeNoGroupDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (!mounted) return;

                  try {
                    // === 프로필 완성도 종합 검증 ===
                    final authController = context.read<AuthController>();
                    final profileValidation = _validateProfileForGroupCreation(authController);

                    if (!profileValidation.isValid) {
                      if (mounted) {
                        // 프로필 미완성 알림
                        showDialog(
                          context: context,
                          barrierDismissible: false, // 프로필 완성을 강제하려면 false로 설정
                          builder: (context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)!.homeProfileRequiredTitle),
                            content: Text(AppLocalizations.of(context)!.homeProfileRequiredDesc),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // 다이얼로그 닫기

                                  // ProfileEditView로 이동하여 프로필 완성 유도
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ProfileEditView()),
                                  );
                                },
                                child: Text(AppLocalizations.of(context)!.homeProfileRequiredBtn),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    // 프로필이 완성된 경우에만 그룹 생성 진행 가능하도록 구현하기
                    final groupController = _groupController ?? context.read<GroupController>();
                    await groupController.createGroup();
                  } catch (e) {
                    // 그룹 생성 단계에서 에러
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.homeCreateGroup, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 커스텀 헤더 위젯
  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.homeTitle,
                style: GoogleFonts.gugi(
                  fontSize: 28,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // 매칭 필터 버튼 (조건에 따라 표시)
              Consumer<GroupController>(
                builder: (context, groupController, _) {
                  // 조건:
                  if (groupController.isOwner && // 방장이어야 함 (isOwner)
                      !groupController.isMatched && // 매칭 완료 상태가 아니어야 함 (!isMatched)
                      !groupController.isMatching) { // 매칭 진행 중 상태가 아니어야 함 (!isMatching)
                    return IconButton(
                      icon: const Icon(Icons.tune),
                      iconSize: 30,
                      tooltip: '매칭 필터',
                      onPressed: _showMatchFilterDialog,
                    );
                  }
                  // 조건에 맞지 않으면 숨김
                  return const SizedBox.shrink();
                },
              ),
              // 더보기 메뉴
              GestureDetector(
                onTap: _showMoreOptions, // _showMoreOptions 메서드는 그대로 활용
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.gray100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: AppTheme.gray800, size: 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupStatusCard(GroupController groupController) {
    final bool isMatched = groupController.isMatched;
    final bool isMatching = groupController.isMatching;

    // 현재 채팅방 ID 가져오기
    final chatRoomId = _getChatRoomId(groupController);
    final currentUserId = context.read<AuthController>().firebaseService.currentUserId;

    final BoxDecoration cardDecoration = isMatched
        ? BoxDecoration(
      gradient: AppTheme.matchedGradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    )
        : BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppTheme.softShadow,
    );

    return Container(
      decoration: cardDecoration,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      isMatched ? AppLocalizations.of(context)!.homeMatchedStatus : (isMatching ? AppLocalizations.of(context)!.homeMatchingStatus : AppLocalizations.of(context)!.homeWaitingStatus),
                    style: TextStyle(
                      color: isMatched ? Colors.white : AppTheme.gray800,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                    Text(
                      isMatched
                          ? AppLocalizations.of(context)!.homeMatchedDesc
                          : (isMatching ? AppLocalizations.of(context)!.homeMatchingDesc : AppLocalizations.of(context)!.homeWaitingDesc),
                    style: TextStyle(
                      color: isMatched ? Colors.white.withValues(alpha: 0.9) : AppTheme.gray600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMatched ? Colors.white.withValues(alpha: 0.2) : AppTheme.gray50,
                  shape: BoxShape.circle,
                ),
                child: isMatching
                    ? RotationTransition(
                  turns: _animationController,
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                )
                    : Icon(
                  isMatched ? Icons.favorite : Icons.people_outline,
                  color: isMatched ? Colors.white : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 매칭 상태에 따른 버튼 영역 (StreamBuilder 적용)
          if (isMatched)
            SizedBox(
              width: double.infinity,
              child: StreamBuilder<ChatroomModel?>(
                stream: _chatroomService.getChatroomStream(chatRoomId),
                builder: (context, snapshot) {
                  bool hasUnread = false;
                  // 데이터가 있고, 마지막 메시지를 내가 보낸 게 아니라면 '새 메시지'로 간주
                  if (snapshot.hasData && snapshot.data != null && currentUserId != null) {
                    final chatroom = snapshot.data!;
                    if (chatroom.lastMessage != null &&
                        chatroom.lastMessage!.senderId != currentUserId) {

                      // readBy 리스트에 내 ID가 없으면 '안 읽음'으로 간주
                      final readBy = chatroom.lastMessage!.readBy;
                      if (!readBy.contains(currentUserId)) {
                        hasUnread = true;
                      }
                    }
                  }

                  return ElevatedButton(
                    onPressed: _navigateToChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasUnread ? Colors.orange : Colors.white, // 오렌지색 적용
                      foregroundColor: hasUnread ? Colors.white : AppTheme.successColor,
                      elevation: hasUnread ? 4 : 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      hasUnread ? AppLocalizations.of(context)!.homeNewMessage : AppLocalizations.of(context)!.homeEnterChat,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            )
          else
            Column(
              children: [
                if (groupController.isOwner)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: groupController.currentGroup!.memberIds.length < 1
                              ? null
                              : isMatching
                              ? groupController.cancelMatching
                              : groupController.startMatching,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMatching ? AppTheme.gray200 : AppTheme.primaryColor,
                            foregroundColor: isMatching ? AppTheme.gray700 : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                              isMatching ? AppLocalizations.of(context)!.homeCancelMatching : AppLocalizations.of(context)!.homeStartMatching,
                              style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // 대기 채팅방 버튼 (StreamBuilder 적용)
                SizedBox(
                  width: double.infinity,
                  child: StreamBuilder<ChatroomModel?>(
                      stream: _chatroomService.getChatroomStream(chatRoomId),
                      builder: (context, snapshot) {
                        bool hasUnread = false;
                        if (snapshot.hasData && snapshot.data != null && currentUserId != null) {
                          final chatroom = snapshot.data!;
                          if (chatroom.lastMessage != null &&
                              chatroom.lastMessage!.senderId != currentUserId) {

                            // readBy 리스트에 내 ID가 없으면 '안 읽음'으로 간주
                            final readBy = chatroom.lastMessage!.readBy;
                            if (!readBy.contains(currentUserId)) {
                              hasUnread = true;
                            }
                          }
                        }

                        return OutlinedButton.icon(
                          onPressed: _navigateToChat,
                          label: Text(
                            hasUnread ? AppLocalizations.of(context)!.homeNewMessage : AppLocalizations.of(context)!.homeEnterChat,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: hasUnread ? Colors.orange : null, // 오렌지색 적용
                            foregroundColor: hasUnread ? Colors.white : AppTheme.gray700,
                            side: BorderSide(
                              color: hasUnread ? Colors.orange : AppTheme.gray300,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        );
                      }
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGroupMembersSection(GroupController groupController, AuthController authController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.homeCurrentMembers,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gray800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.group_rounded,
                      size: 13,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${groupController.groupMembers.length}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 멤버 리스트 (Wrap -> Row 또는 Grid로 변경하되, 가로 스크롤 등으로 세련되게)
          // 여기서는 심플하게 유지하되 디자인 폴리싱
          Wrap(
            spacing: 20.0,
            runSpacing: 20.0,
            children: [
              // 오너를 먼저 배치하고 나머지 멤버 배치
              ...(groupController.groupMembers.toList()
                ..sort((a, b) {
                  final aIsOwner = groupController.currentGroup!.isOwner(a.uid);
                  final bIsOwner = groupController.currentGroup!.isOwner(b.uid);
                  if (aIsOwner && !bIsOwner) return -1;
                  if (!aIsOwner && bIsOwner) return 1;
                  return 0;
                }))
                .map((member) {
                final isBlocked = authController.blockedUserIds.contains(member.uid);
                final isOwner = groupController.currentGroup!.isOwner(member.uid);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileDetailView(user: member),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Stack(
                        children: [
                            MemberAvatar(
                              imageUrl: isBlocked ? null : member.mainProfileImage,
                              name: member.nickname,
                              isOwner: isOwner,
                              gender: member.gender,
                              size: 56,
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text(
                        member.nickname,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.gray800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }),

              // 친구 초대 버튼
              if (groupController.isOwner &&
                  !groupController.isMatched &&
                  groupController.groupMembers.length < 5)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InviteFriendView(),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.gray50,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.gray200,
                            width: 1,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppTheme.gray500,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.homeInvite,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }

  // 그룹 생성을 위한 프로필 완성도 검증
  ProfileValidationResult _validateProfileForGroupCreation(AuthController authController) {
    final user = authController.currentUserModel;
    final firebaseUser = authController.firebaseService.currentUser;

    List<String> missingFields = [];

    // 1. 기본 계정 정보 확인
    if (user == null || firebaseUser?.email == null) {
      missingFields.add('계정 정보');
      return ProfileValidationResult(isValid: false, missingFields: missingFields);
    }

    // 2. 기본 회원 정보 확인 (회원가입 시 입력하는 필수 정보)
    if (user.phoneNumber.isEmpty) {
      missingFields.add('전화번호');
    }
    if (user.birthDate.isEmpty) {
      missingFields.add('생년월일');
    }
    if (user.gender.isEmpty) {
      missingFields.add('성별');
    }

    // 3. 프로필 정보 확인 (그룹 생성을 위한 필수 정보)
    if (user.nickname.isEmpty) {
      missingFields.add('닉네임');
    }
    if (user.introduction.isEmpty) {
      missingFields.add('소개글');
    }
    if (user.height <= 0) {
      missingFields.add('키');
    }
    if (user.activityArea.isEmpty) {
      missingFields.add('활동지역');
    }
    if (user.profileImages.isEmpty) {
      missingFields.add('프로필 사진');
    }

    // 4. 프로필 완성 플래그 확인
    if (!user.isProfileComplete) {
      if (missingFields.isEmpty) {
        // 모든 필드가 채워져 있는데 플래그가 false면 플래그 문제
        missingFields.add('프로필 완성 처리');
      }
    }

    return ProfileValidationResult(
      isValid: missingFields.isEmpty,
      missingFields: missingFields,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/group_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class MatchFilterDialog extends StatefulWidget {
  const MatchFilterDialog({super.key});

  @override
  State<MatchFilterDialog> createState() => _MatchFilterDialogState();
}

class _MatchFilterDialogState extends State<MatchFilterDialog> {
  late RangeValues currentAgeRange;
  late RangeValues currentHeightRange;
  late double currentDistance;
  late String selectedGender;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final groupController = context.read<GroupController>();
    final group = groupController.currentGroup;

    double initMinAge = (group?.minAge.toDouble() ?? 19.0).clamp(19.0, 60.0);
    double initMaxAge = (group?.maxAge.toDouble() ?? 60.0).clamp(19.0, 60.0);
    if (initMinAge > initMaxAge) initMinAge = initMaxAge;
    currentAgeRange = RangeValues(initMinAge, initMaxAge);

    double initMinHeight = (group?.minHeight.toDouble() ?? 150.0).clamp(150.0, 190.0);
    double initMaxHeight = (group?.maxHeight.toDouble() ?? 190.0).clamp(150.0, 190.0);
    if (initMinHeight > initMaxHeight) initMinHeight = initMaxHeight;
    currentHeightRange = RangeValues(initMinHeight, initMaxHeight);

    double initMaxDistance = (group?.maxDistance.toDouble() ?? 100.0).clamp(2.0, 100.0);
    currentDistance = initMaxDistance;

    selectedGender = group?.preferredGender ?? 'Any';
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

  // 개선된 성별 선택 칩 위젯 (label: 표시용 로컬라이즈 텍스트, value: Firestore 저장용 영문값)
  Widget _buildGenderChip(String label, String value, String currentSelection, Function(String) onSelected) {
    final bool isSelected = value == currentSelection;
    // 텍스트가 너무 길 경우를 대비해 폰트 사이즈 조정
    final double fontSize = label.length > 3 ? 12 : 13;

    return GestureDetector(
      onTap: () => onSelected(value),
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

  @override
  Widget build(BuildContext context) {
    final groupController = context.watch<GroupController>();

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
                style: const TextStyle(
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
              Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterMale, 'Male', selectedGender, (val) => setState(() => selectedGender = val))),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterFemale, 'Female', selectedGender, (val) => setState(() => selectedGender = val))),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterMixed, 'Mixed', selectedGender, (val) => setState(() => selectedGender = val))),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderChip(AppLocalizations.of(context)!.homeFilterAny, 'Any', selectedGender, (val) => setState(() => selectedGender = val))),
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
                setState(() => currentAgeRange = values);
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
            data: const SliderThemeData(
              trackHeight: 6,
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.gray200,
              thumbColor: Colors.white,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
              rangeThumbShape: RoundRangeSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
            ),
            child: RangeSlider(
              values: currentHeightRange,
              min: 150,
              max: 190,
              divisions: 40,
              onChanged: (RangeValues values) {
                setState(() => currentHeightRange = values);
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
            data: const SliderThemeData(
              trackHeight: 6,
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.gray200,
              thumbColor: Colors.white,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
            ),
            child: Slider(
              value: currentDistance,
              min: 2,
              max: 100,
              divisions: 49,
              onChanged: (double value) {
                setState(() => currentDistance = value);
              },
            ),
          ),

          const SizedBox(height: 40),

          // 적용 버튼
          ElevatedButton(
            onPressed: isSaving
                ? null
                : () async {
              setState(() => isSaving = true);
              try {
                final success = await groupController.saveMatchFilters(
                  preferredGender: selectedGender,
                  minAge: currentAgeRange.start.round(),
                  maxAge: currentAgeRange.end.round() >= 60 ? 100 : currentAgeRange.end.round(),
                  minHeight: currentHeightRange.start.round(),
                  maxHeight: currentHeightRange.end.round() >= 190 ? 200 : currentHeightRange.end.round(),
                  maxDistance: currentDistance.round() >= 100 ? 50000 : currentDistance.round(),
                );

                if (!context.mounted) return;
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
                if (context.mounted) Navigator.pop(context);
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
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

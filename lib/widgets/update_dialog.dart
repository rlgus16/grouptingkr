import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class UpdateDialog extends StatefulWidget {
  final String storeUrl;
  final String message;

  const UpdateDialog({
    super.key,
    required this.storeUrl,
    required this.message,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _doNotShowToday = false;

  Future<void> _launchStore() async {
    final Uri uri = Uri.parse(widget.storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch ${widget.storeUrl}';
      }
    } catch (e) {
      debugPrint('스토어 이동 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.system_update_alt, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 20),
          Text(
            l10n.updateTitle,
            style: const TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15, 
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _launchStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.updateButton, 
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Do not show today checkbox
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _doNotShowToday,
                  onChanged: (value) {
                    setState(() {
                      _doNotShowToday = value ?? false;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _doNotShowToday = !_doNotShowToday;
                  });
                },
                child: Text(
                  '오늘 하루 보지 않기', // Add this to localizations ideally, using hardcoded for now to match style
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                if (_doNotShowToday) {
                  final prefs = await SharedPreferences.getInstance();
                  final now = DateTime.now();
                  final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  await prefs.setString('update_dialog_hidden_date', dateString);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.gray500,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.homeLater, 
                style: const TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.w600
                )
              ),
            ),
          ),
        ],
      ),
    );
  }
}

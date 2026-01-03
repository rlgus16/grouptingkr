import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsHelp),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section
            _buildSectionCard(
              title: l10n.helpFAQSection,
              icon: Icons.help_outline,
              child: Column(
                children: [
                  _buildFAQItem(question: l10n.helpFAQ1Q, answer: l10n.helpFAQ1A),
                  _buildFAQItem(question: l10n.helpFAQ4Q, answer: l10n.helpFAQ4A),
                  _buildFAQItem(question: l10n.helpFAQ5Q, answer: l10n.helpFAQ5A),
                  _buildFAQItem(question: l10n.helpFAQ6Q, answer: l10n.helpFAQ6A),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // User Guide Section
            _buildSectionCard(
              title: l10n.helpGuideSection,
              icon: Icons.book_outlined,
              child: Column(
                children: [
                  _buildGuideItem(
                    icon: Icons.person_add,
                    title: l10n.helpGuideSignup,
                    description: l10n.helpGuideSignupDesc,
                    onTap: () => _showGuideDetail(context, l10n.helpGuideSignup, l10n.helpGuideSignupContent, l10n),
                  ),
                  _buildGuideItem(
                    icon: Icons.group_add,
                    title: l10n.helpGuideGroup,
                    description: l10n.helpGuideGroupDesc,
                    onTap: () => _showGuideDetail(context, l10n.helpGuideGroup, l10n.helpGuideGroupContent, l10n),
                  ),
                  _buildGuideItem(
                    icon: Icons.tune,
                    title: l10n.helpGuideFilter,
                    description: l10n.helpGuideFilterDesc,
                    onTap: () => _showGuideDetail(context, l10n.helpGuideFilter, l10n.helpGuideFilterContent, l10n),
                  ),
                  _buildGuideItem(
                    icon: Icons.favorite,
                    title: l10n.helpGuideMatch,
                    description: l10n.helpGuideMatchDesc,
                    onTap: () => _showGuideDetail(context, l10n.helpGuideMatch, l10n.helpGuideMatchContent, l10n),
                  ),
                  _buildGuideItem(
                    icon: Icons.chat,
                    title: l10n.helpGuideChat,
                    description: l10n.helpGuideChatDesc,
                    onTap: () => _showGuideDetail(context, l10n.helpGuideChat, l10n.helpGuideChatContent, l10n),
                  ),
                  _buildGuideItem(
                    icon: Icons.security,
                    title: l10n.helpGuideSafety,
                    description: l10n.helpGuideSafetyDesc,
                    onTap: () => _showGuideDetail(context, l10n.helpGuideSafety, l10n.helpGuideSafetyContent, l10n),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Contact Section
            _buildSectionCard(
              title: l10n.helpContactSection,
              icon: Icons.contact_support_outlined,
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.email_outlined,
                    title: l10n.helpEmailContact,
                    subtitle: 'sprt.groupting@gmail.com',
                    onTap: () => _sendEmail(),
                  ),
                  _buildContactItem(
                    icon: Icons.bug_report_outlined,
                    title: l10n.helpBugReportTitle,
                    subtitle: l10n.helpBugReportSubtitle,
                    onTap: () => _showBugReportDialog(context, l10n),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Service Info Section
            _buildSectionCard(
              title: l10n.helpServiceSection,
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.helpCustomerService,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.helpOperatingHours,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.helpResponseTime,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.helpResponseEmail,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showGuideDetail(BuildContext context, String title, String content, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'sprt.groupting@gmail.com',
      query: 'subject=[Groupting Inquiry]&body=Inquiry content:\n',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'Could not launch email';
      }
    } catch (e) {
      // Email app not available
    }
  }


  void _showBugReportDialog(BuildContext context, AppLocalizations l10n) {
    final TextEditingController contentController = TextEditingController();
    XFile? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {

            Future<void> pickImage() async {
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() {
                  selectedImage = image;
                });
              }
            }

            Future<void> sendEmail() async {
              String body = "Bug content:\n${contentController.text}";

              final Email email = Email(
                body: body,
                subject: '[Groupting Bug Report]',
                recipients: ['sprt.groupting@gmail.com'],
                attachmentPaths: selectedImage != null ? [selectedImage!.path] : [],
                isHTML: false,
              );

              try {
                await FlutterEmailSender.send(email);
                Navigator.pop(context);
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.helpEmailFailed)),
                );
              }
            }

            return AlertDialog(
              title: Text(l10n.helpBugReportTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.helpBugReportContent),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: l10n.helpBugReportHint,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.photo_camera),
                          label: Text(l10n.helpPhotoAttach),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87, elevation: 0),
                        ),
                        const SizedBox(width: 10),
                        if (selectedImage != null)
                          Expanded(
                            child: Text(
                              l10n.helpPhotoSelected,
                              style: const TextStyle(color: Colors.green),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    if (selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Image.file(
                          File(selectedImage!.path),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: sendEmail,
                  child: Text(l10n.helpSend),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
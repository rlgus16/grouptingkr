import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../controllers/group_controller.dart';
import '../models/invitation_model.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/custom_toast.dart';

class InviteFriendView extends StatefulWidget {
  const InviteFriendView({super.key});

  @override
  State<InviteFriendView> createState() => _InviteFriendViewState();
}

class _InviteFriendViewState extends State<InviteFriendView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController(); // Chanaged from _nicknameController
  final _messageController = TextEditingController();
  String _selectedCountryCode = '+82';

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    final l10n = AppLocalizations.of(context)!;
    
    // 권한 요청
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (mounted) {
        CustomToast.showError(context, '연락처 접근 권한이 필요합니다.');
      }
      return;
    }

    // 연락처 선택 화면 열기
    final contact = await FlutterContacts.openExternalPick();
    
    if (contact != null && contact.phones.isNotEmpty) {
      String phoneNumber = contact.phones.first.number;
      
      // 특수문자 제거 (숫자만 남김)
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // 국가코드 처리 (+82 등)
      String cleanCountryCode = _selectedCountryCode.replaceAll('+', '');
      
      if (phoneNumber.startsWith(_selectedCountryCode)) {
        phoneNumber = phoneNumber.substring(_selectedCountryCode.length);
      } else if (phoneNumber.startsWith(cleanCountryCode)) {
        phoneNumber = phoneNumber.substring(cleanCountryCode.length);
      } else if (phoneNumber.startsWith('+')) {
         // 다른 국가코드인 경우, 현재 선택된 국가코드로 변경하거나 경고?
         // 일단은 그대로 입력 필드에 넣지만, 사용자 경험상 
         // 현재 선택된 국가코드와 다르면 알림을 주는 것이 좋을 수 있음
         // 여기서는 단순화하여 입력 필드에 넣음
         phoneNumber = phoneNumber.replaceAll('+', '');
      }

      // 맨 앞 0 처리 (이미 한국 010 형식이면 그대로 둠, 
      // 하지만 이 앱의 로직에서는 +82가 선택되어 있으면 나중에 0을 뗌, 
      // 즉 입력 필드에는 010...으로 들어가야 자연스러움)
      
       setState(() {
        _phoneNumberController.text = phoneNumber;
      });
    }
  }

  Future<void> _inviteFriend() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    final groupController = context.read<GroupController>();

    String phoneNumber = _phoneNumberController.text.trim();
    
    // 한국 번호인 경우 맨 앞의 0 제거
    if (_selectedCountryCode == '+82' && phoneNumber.startsWith('0')) {
      phoneNumber = phoneNumber.substring(1);
    }
    
    final fullPhoneNumber = '$_selectedCountryCode$phoneNumber';

    try {
      await groupController.inviteFriend(
        phoneNumber: fullPhoneNumber, // Changed parameter
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      );

      if (mounted) {
        CustomToast.showSuccess(context, l10n.inviteSentSuccess);
        _phoneNumberController.clear();
        _messageController.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.inviteTitle),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                _buildGuideBox(context, l10n),
                const SizedBox(height: 24),

                _buildGroupStatusCard(l10n),
                const SizedBox(height: 24),

                Text(
                  l10n.inviteWho,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Phone Number Label
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    l10n.invitePhoneLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      child: CountryCodePicker(
                        onChanged: (country) {
                          setState(() {
                            _selectedCountryCode = country.dialCode!;
                          });
                        },
                        initialSelection: 'KR',
                        favorite: const ['KR'],
                        showFlag: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        textStyle: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneNumberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: l10n.invitePhoneHint,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.invitePhoneEmpty;
                          }
                          // Simple phone number validation
                          final phoneRegex = RegExp(r'^\d{9,11}$');
                          if (!phoneRegex.hasMatch(value.trim())) {
                            return l10n.invitePhoneInvalid;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.contacts_rounded, color: AppTheme.textPrimary),
                        onPressed: _pickContact,
                        tooltip: '연락처에서 가져오기',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: l10n.inviteMessageLabel,
                    hintText: l10n.inviteMessagePlaceholder,
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  maxLines: 1,
                  maxLength: 50,
                ),
                const SizedBox(height: 32),

                Consumer<GroupController>(
                  builder: (context, groupController, _) {
                    return ElevatedButton(
                      onPressed: groupController.isLoading ? null : _inviteFriend,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: groupController.isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(l10n.inviteSendButton),
                    );
                  },
                ),

                const SizedBox(height: 40),

                Consumer<GroupController>(
                  builder: (context, groupController, _) {
                    if (groupController.sentInvitations.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.inviteSentList,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.gray200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${groupController.sentInvitations.length}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...groupController.sentInvitations.map((invitation) {
                          return _buildInvitationCard(context, invitation, l10n);
                        }),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideBox(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inviteGuide,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.inviteGuideDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupStatusCard(AppLocalizations l10n) {
    return Consumer<GroupController>(
      builder: (context, groupController, _) {
        final currentCount = groupController.currentGroup?.memberCount ?? 1;
        const maxCount = 5;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: AppTheme.gray100),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.inviteCurrentMember,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$currentCount',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' / $maxCount',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(maxCount, (index) {
                  final bool isFilled = index < currentCount;
                  return Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isFilled ? AppTheme.primaryColor : AppTheme.gray200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvitationCard(BuildContext context, InvitationModel invitation, AppLocalizations l10n) {
    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    switch (invitation.status) {
      case InvitationStatus.pending:
        statusColor = const Color(0xFFFFB74D);
        statusBgColor = const Color(0xFFFFF3E0);
        statusText = l10n.inviteStatusPending;
        statusIcon = Icons.access_time_rounded;
        break;
      case InvitationStatus.accepted:
        statusColor = AppTheme.successColor;
        statusBgColor = AppTheme.successColor.withValues(alpha: 0.1);
        statusText = l10n.inviteStatusAccepted;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case InvitationStatus.rejected:
        statusColor = AppTheme.errorColor;
        statusBgColor = AppTheme.errorColor.withValues(alpha: 0.1);
        statusText = l10n.inviteStatusRejected;
        statusIcon = Icons.highlight_off_rounded;
        break;
      default:
        statusColor = AppTheme.gray500;
        statusBgColor = AppTheme.gray200;
        statusText = l10n.inviteStatusExpired;
        statusIcon = Icons.timer_off_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.gray100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.gray100,
          radius: 22,
          child: Icon(
            Icons.mail_outline_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          invitation.toUserNickname,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          invitation.message ?? l10n.inviteNoMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusBgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
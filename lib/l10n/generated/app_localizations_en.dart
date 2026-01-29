// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Groupting';

  @override
  String get appSubtitle => 'Start of new encounters\nenjoyed with friends';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonComplete => 'Done';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonNext => 'Next';

  @override
  String get commonLater => 'Later';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonRetry => 'Retry';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'example@email.com';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'Enter your password';

  @override
  String get loginButton => 'Login';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginRegister => 'Sign Up';

  @override
  String get loginErrorEmailEmpty => 'Please enter your email.';

  @override
  String get loginErrorEmailInvalid => 'Please enter a valid email address.';

  @override
  String get loginErrorPasswordEmpty => 'Please enter your password.';

  @override
  String get loginErrorPasswordShort =>
      'Password must be at least 6 characters.';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginForgotPasswordTitle => 'Reset Password';

  @override
  String get loginForgotPasswordDesc =>
      'Enter the email you used to sign up\nand we\'ll send you a reset link.';

  @override
  String get loginForgotPasswordSent =>
      'Password reset email sent. Please check your inbox.';

  @override
  String get loginForgotPasswordError =>
      'Failed to send email. Please check the email address.';

  @override
  String get loginForgotPasswordSendButton => 'Send Email';

  @override
  String get registerTitle => 'Sign Up';

  @override
  String get registerWelcome => 'Welcome!';

  @override
  String get registerWelcomeDesc =>
      'Ready to meet new people?\nStart by entering some simple info.';

  @override
  String get registerAccountInfo => 'Account Info';

  @override
  String get registerPasswordHint8Chars => '8+ characters';

  @override
  String get registerPasswordConfirm => 'Confirm Password';

  @override
  String get registerPasswordConfirmHint => 'Re-enter password';

  @override
  String get registerPersonalInfo => 'Personal Info';

  @override
  String get registerPhone => 'Phone Number';

  @override
  String get registerPhoneVerify => 'Verify';

  @override
  String get registerPhoneComplete => 'Verified';

  @override
  String get registerVerificationCode => '6-digit code';

  @override
  String get registerBirthDate => 'Birth Date';

  @override
  String get registerBirthDateHint => '19950315';

  @override
  String get registerBirthDateHelper => 'Format: YYYYMMDD';

  @override
  String get registerGender => 'Gender';

  @override
  String get registerMale => 'Male';

  @override
  String get registerFemale => 'Female';

  @override
  String get registerTerms => 'Terms & Conditions';

  @override
  String get registerTermsService => '[Required] Agree to Terms of Service';

  @override
  String get registerTermsPrivacy => '[Required] Agree to Privacy Policy';

  @override
  String get registerButton => 'Sign Up';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerLoginLink => 'Login';

  @override
  String get registerErrorPasswordMismatch => 'Passwords do not match.';

  @override
  String get registerErrorGender => 'Please select your gender.';

  @override
  String get registerErrorTerms =>
      'Please agree to the Terms of Service and Privacy Policy.';

  @override
  String get homeTabHome => 'Home';

  @override
  String get homeTabInvite => 'Invites';

  @override
  String get homeTabMyPage => 'My Page';

  @override
  String get homeTabMore => 'More';

  @override
  String get homeProfileCardTitle => 'Complete Your Profile';

  @override
  String get homeProfileCardDesc =>
      'Add your nickname, height, bio, and location\nto start creating groups and matching!';

  @override
  String get homeProfileCardButton => 'Complete Now';

  @override
  String get homeNoGroupTitle => 'No Group Yet';

  @override
  String get homeNoGroupDesc => 'Create a new group\nand invite your friends!';

  @override
  String get homeCreateGroupButton => 'Create New Group';

  @override
  String get homeGroupStatusMatching => 'Matching in progress...';

  @override
  String get homeGroupStatusMatched => 'Matched! 🎉';

  @override
  String get homeGroupStatusWaiting => 'Waiting for match';

  @override
  String get homeGroupDescMatching => 'Looking for a match partner...';

  @override
  String get homeGroupDescMatched => 'Start a conversation with new people';

  @override
  String get homeGroupDescWaiting => 'Chat with your friends';

  @override
  String get homeStartMatching => 'Start Matching';

  @override
  String get homeCancelMatching => 'Cancel Matching';

  @override
  String get homeEnterChat => 'Enter Chat';

  @override
  String get homeGroupMembers => 'Current Members';

  @override
  String get homeInviteFriend => 'Invite';

  @override
  String get homeDialogMatchedTitle => 'Match Success! 🎉';

  @override
  String get homeDialogMatchedContent =>
      'You are matched!\nSay hello in the chat room 👋';

  @override
  String get homeDialogGoToChat => 'Go to Chat';

  @override
  String get homeMenuLeaveGroup => 'Leave Group';

  @override
  String get homeMenuLogout => 'Logout';

  @override
  String get dialogLeaveGroupTitle => 'Leave Group';

  @override
  String get dialogLeaveGroupContent =>
      'Are you sure you want to leave the group?';

  @override
  String get dialogLogoutTitle => 'Logout';

  @override
  String get dialogLogoutContent => 'Are you sure you want to logout?';

  @override
  String get dialogLeaveGroupAction => 'Leave';

  @override
  String get myPageTitle => 'My Page';

  @override
  String get myPageEmptyProfile => 'Create your profile';

  @override
  String get myPageEmptyDesc => 'Ready to meet new people?';

  @override
  String get myPageCreateProfile => 'Create Profile';

  @override
  String get myPageBasicInfo => 'Basic Info';

  @override
  String get myPagePhone => 'Phone';

  @override
  String get myPageHeight => 'Height';

  @override
  String get myPageLocation => 'Location';

  @override
  String get myPageIntro => 'Bio';

  @override
  String get myPageMenuSettings => 'Settings';

  @override
  String get myPageMenuStore => 'Store';

  @override
  String get myPageMenuHelp => 'Help';

  @override
  String get myPageMenuAppInfo => 'App Info';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditImage => 'Profile Photos';

  @override
  String get profileEditImageGuide => 'Long press to set main photo';

  @override
  String get profileEditImageAdd => 'Add Photo';

  @override
  String get profileEditImageMain => 'Main';

  @override
  String get profileEditNickname => 'Nickname';

  @override
  String get profileEditNicknameHint => 'Enter nickname (2~10 chars)';

  @override
  String get profileEditHeight => 'Height (cm)';

  @override
  String get profileEditLocation => 'Location';

  @override
  String get profileEditLocationHint => 'Tap to select location';

  @override
  String get profileEditIntro => 'Bio';

  @override
  String get profileEditIntroHint =>
      'Write a cool intro about yourself.\n(Hobbies, interests, personality, etc.)';

  @override
  String get profileEditAccountInfo => 'Account Info';

  @override
  String get profileEditErrorImages => 'Please upload at least 1 photo.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNotification => 'Notifications';

  @override
  String get settingsNotiMatch => 'Match Alerts';

  @override
  String get settingsNotiInvite => 'Invite Alerts';

  @override
  String get settingsNotiChat => 'Message Alerts';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsChangePw => 'Change Password';

  @override
  String get settingsBlock => 'Blocked Users';

  @override
  String get settingsBlockEmpty => 'No blocked users';

  @override
  String get settingsUnblock => 'Unblock';

  @override
  String get settingsExemption => 'Match Exemptions';

  @override
  String get settingsExemptionEmpty => 'No exempted users';

  @override
  String get settingsExemptionRemove => 'Remove';

  @override
  String get settingsDeleteAccount => 'Delete Account';

  @override
  String get settingsInfo => 'Info & Support';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsAppVersion => 'App Version';

  @override
  String get settingsDeleteAccountConfirm => 'Permanently delete account.';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatMatchingTitle => 'Match Chat';

  @override
  String get chatGroupTitle => 'Group Chat';

  @override
  String get chatInputHint => 'Send a message';

  @override
  String get chatEmptyMatched => 'Matched! 🎉';

  @override
  String get chatEmptyGroup => 'Group Chat Started 👋';

  @override
  String get inviteTitle => 'Invite Friends';

  @override
  String get inviteGuide => 'Invitation Guide';

  @override
  String get inviteGuideDesc =>
      'Please enter the friend\'s nickname correctly\nYou can form a group of up to 5 people';

  @override
  String get inviteCurrentMember => 'Current Members';

  @override
  String get inviteNicknameLabel => 'Friend Nickname';

  @override
  String get inviteNicknameHint => 'Enter friend\'s nickname';

  @override
  String get inviteMessageLabel => 'Message (Optional)';

  @override
  String get inviteMessageHint => 'Enter a message for your friend';

  @override
  String get inviteButton => 'Invite';

  @override
  String get inviteSentList => 'Sent Invites';

  @override
  String get inviteStatusPending => 'Pending';

  @override
  String get inviteStatusAccepted => 'Accepted';

  @override
  String get inviteStatusRejected => 'Rejected';

  @override
  String get inviteStatusExpired => 'Expired';

  @override
  String get invitationListTitle => 'Received Invites';

  @override
  String get invitationEmpty => 'No invitations received';

  @override
  String invitationFrom(Object name) {
    return 'Invite from $name';
  }

  @override
  String get invitationExpired => 'Invitation expired';

  @override
  String get invitationAccept => 'Accept';

  @override
  String get invitationReject => 'Reject';

  @override
  String get invitationMoveGroupTitle => 'Move Group';

  @override
  String get invitationMoveGroupContent =>
      'Do you want to leave your current group and join the new one?';

  @override
  String get locationPickerTitle => 'Select Location';

  @override
  String get locationPickerSearching => 'Searching location...';

  @override
  String get locationPickerSelect => 'Set this location';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpFAQ => 'FAQ';

  @override
  String get helpGuide => 'User Guide';

  @override
  String get helpContact => 'Contact Us';

  @override
  String get helpEmail => 'Email Inquiry';

  @override
  String get helpBugReport => 'Report Bug';

  @override
  String get helpServiceInfo => 'Service Info';

  @override
  String get profileDetailReport => 'Report';

  @override
  String get profileDetailBlock => 'Block';

  @override
  String get profileDetailBlockConfirm =>
      'Blocking will hide profiles from each other,\nand prevent chats or invites.\nAre you sure you want to block?';

  @override
  String get updateTitle => 'Update Required';

  @override
  String get updateButton => 'Update Now';

  @override
  String get locationPickerError => 'Address not found.';

  @override
  String get inviteSentSuccess => 'Invitation sent!';

  @override
  String get inviteWho => 'Who would you like to invite?';

  @override
  String get inviteNicknameEmpty => 'Please enter a nickname.';

  @override
  String get inviteMessagePlaceholder => 'Let\'s groupting together!';

  @override
  String get inviteSendButton => 'Send Invitation';

  @override
  String get inviteNoMessage => 'No message';

  @override
  String get invitationNewGroup => 'You\'ve been invited to a new group!';

  @override
  String get invitationExpiredLabel => 'This invitation has expired';

  @override
  String get invitationJoinedSuccess => 'Joined the group!';

  @override
  String get invitationRejectedInfo => 'Invitation rejected';

  @override
  String get invitationMoveAction => 'Move';

  @override
  String get invitationEmptyTitle => 'No invitations yet';

  @override
  String get invitationEmptyDesc => 'Invites from friends will appear here';

  @override
  String chatParticipating(Object count) {
    return '$count participants';
  }

  @override
  String get chatFindingMatch => 'Finding a match for you...';

  @override
  String get chatInviteFriend => 'Invite Friends';

  @override
  String chatWaitingResponse(Object count) {
    return '$count friends awaiting response';
  }

  @override
  String get chatEmptyMatchedDesc =>
      'Start an exciting conversation.\nGet to know each other!';

  @override
  String get chatEmptyGroupWithFriends => 'Chat freely with your friends!';

  @override
  String get chatEmptyAlone =>
      'You\'re alone in the group.\nInvite some friends!';

  @override
  String myPageAge(Object age) {
    return '$age y/o';
  }

  @override
  String get myPageMale => 'Male';

  @override
  String get myPageFemale => 'Female';

  @override
  String get myPageLogoutError => 'Error during logout.';

  @override
  String get myPageAppName => 'Groupting';

  @override
  String get myPageAppVersion => 'Version 1.0.0';

  @override
  String get myPageAppDesc => 'A dating platform with friends';

  @override
  String get homeReceivedInvite => 'Received Invites';

  @override
  String get homeLeftGroup => 'Left the group.';

  @override
  String get homeFilterTitle => 'Match Filter Settings';

  @override
  String get homeFilterGender => 'Preferred Gender';

  @override
  String get homeFilterAge => 'Average Age';

  @override
  String get homeFilterHeight => 'Average Height';

  @override
  String get homeFilterDistance => 'Distance Range';

  @override
  String get homeFilterApply => 'Apply Filter';

  @override
  String get homeFilterSuccess => 'Filters applied successfully.';

  @override
  String get homeFilterFailed => 'Failed to apply filters';

  @override
  String get homeGenderMale => 'Male';

  @override
  String get homeGenderFemale => 'Female';

  @override
  String get homeGenderMixed => 'Mixed';

  @override
  String get homeGenderAny => 'Any';

  @override
  String get homeProfileHiddenMsg =>
      'Profile reminder hidden. You can complete your profile anytime in My Page.';

  @override
  String get homeLogoutError => 'Error during logout.';

  @override
  String get profileDetailReportTitle => 'Report User';

  @override
  String get profileDetailReportReason => 'Please select a reason.';

  @override
  String get profileDetailReportContent => 'Please describe in detail.';

  @override
  String get profileDetailReportPhoto => 'Attach Evidence';

  @override
  String get profileDetailReportPhotoChange => 'Change Photo';

  @override
  String get profileDetailReportEnterContent => 'Please enter report content.';

  @override
  String get profileDetailReportSubmit => 'Submit Report';

  @override
  String get profileDetailEmailFailed => 'Cannot open email app.';

  @override
  String get profileDetailBlockTitle => 'Block User';

  @override
  String get profileDetailBlocked => 'User has been blocked.';

  @override
  String get profileDetailUnblocked => 'User has been unblocked.';

  @override
  String get profileDetailBlockedUser => 'This user is blocked.';

  @override
  String get profileDetailBasicInfo => 'Basic Info';

  @override
  String get profileDetailIntro => 'Bio';

  @override
  String get profileDetailReasonBadPhoto => 'Inappropriate photo';

  @override
  String get profileDetailReasonAbuse => 'Abusive language';

  @override
  String get profileDetailReasonSpam => 'Spam/Promotion';

  @override
  String get profileDetailReasonFraud => 'Impersonation/Fraud';

  @override
  String get profileDetailReasonOther => 'Other';

  @override
  String get profileDetailExemptTitle => 'Exempt from Matching';

  @override
  String get profileDetailExempt => 'Exempt from Matching';

  @override
  String get profileDetailExemptConfirm =>
      'Exempt this user from matching?\nYou won\'t be matched with groups containing this user.\n\n5 Ting will be deducted.';

  @override
  String get profileDetailExempted =>
      'User exempted from matching. (5 Ting deducted)';

  @override
  String get profileDetailExemptCost => 'Exempting from matching costs 5 Ting.';

  @override
  String get profileDetailUnexempt => 'Remove Exemption';

  @override
  String get profileDetailUnexemptConfirm =>
      'Remove matching exemption for this user?';

  @override
  String get profileDetailUnexempted => 'Matching exemption removed.';

  @override
  String get profileEditNicknameChangeCost =>
      'Changing nickname costs 10 Ting.';

  @override
  String get profileEditNicknameChangeConfirm =>
      'Change your nickname?\n10 Ting will be deducted.';

  @override
  String get profileEditInsufficientTings =>
      'Insufficient Ting. Please recharge at the Store.';

  @override
  String get profileEditNicknameChangeSuccess =>
      'Nickname changed. (10 Ting deducted)';

  @override
  String get profileEditActivityAreaChangeCost =>
      'Changing activity area costs 5 Ting.';

  @override
  String get profileEditActivityAreaChangeConfirm =>
      'Change your activity area?\n5 Ting will be deducted.';

  @override
  String profileEditTotalCostConfirm(Object cost) {
    return 'Saving profile will deduct $cost Ting.\nDo you want to continue?';
  }

  @override
  String get profileEditTotalCostTitle => 'Ting Deduction Notice';

  @override
  String get profileEditNicknameDuplicate => 'This nickname is already in use.';

  @override
  String get profileEditNicknameAvailable => 'This nickname is available.';

  @override
  String get profileEditNicknameCheckError => 'Error checking nickname.';

  @override
  String get profileEditImageError => 'Error selecting image.';

  @override
  String get profileEditPermissionTitle => 'Permission Required';

  @override
  String get profileEditPermissionContent =>
      'Gallery access is required to upload profile photos.\nPlease enable it in settings.';

  @override
  String get profileEditGoToSettings => 'Go to Settings';

  @override
  String get profileEditMainPhotoChanged =>
      'Main profile photo has been changed.';

  @override
  String get profileEditNicknameEmpty => 'Please enter a nickname.';

  @override
  String get profileEditNicknameTooShort =>
      'Nickname must be at least 2 characters.';

  @override
  String get profileEditHeightEmpty => 'Please enter your height.';

  @override
  String get profileEditHeightRange => 'Please enter between 140-220cm.';

  @override
  String get profileEditHeightHint => 'Enter your height';

  @override
  String get profileEditIntroEmpty => 'Please enter a bio.';

  @override
  String get profileEditIntroTooShort => 'Please enter at least 5 characters.';

  @override
  String get profileEditUploadFailed => 'Image upload failed';

  @override
  String get profileEditSuccess => 'Profile updated.';

  @override
  String get profileEditFailed => 'Failed to update profile';

  @override
  String get profileEditEmailLabel => 'Email';

  @override
  String get profileEditBirthDateLabel => 'Birth Date';

  @override
  String get profileEditGenderLabel => 'Gender';

  @override
  String get registerEmailInUse => 'Email already in use.';

  @override
  String get registerEmailAvailable => 'Email is available.';

  @override
  String get registerEmailError => 'Error checking email.';

  @override
  String get registerPhoneInUse => 'Phone number already in use.';

  @override
  String get registerPhoneAvailable => 'Phone number is available.';

  @override
  String get registerPhoneError => 'Error checking phone number.';

  @override
  String get registerPhoneValid => 'Please enter a valid phone number.';

  @override
  String get registerCodeSent => 'Verification code sent.';

  @override
  String get registerPhoneVerified => 'Phone verification complete.';

  @override
  String get registerPassword8Chars =>
      'Password must be at least 8 characters.';

  @override
  String get registerPasswordConfirmEmpty => 'Please confirm your password.';

  @override
  String get registerBirthDateEmpty => 'Please enter your birth date.';

  @override
  String get registerBirthDate8Digits => 'Must be 8 digits.';

  @override
  String get registerYearInvalid => 'Please enter a valid year.';

  @override
  String get registerMonthInvalid => 'Please enter a valid month.';

  @override
  String get registerDayInvalid => 'Please enter a valid day.';

  @override
  String get registerAgeRestriction => 'Must be at least 18 years old.';

  @override
  String get registerDateInvalid => 'Please enter a valid date.';

  @override
  String get registerTermsServiceFull => 'Terms of Service (EULA)';

  @override
  String get registerTermsServiceContent =>
      'Article 1 (Purpose)\nThese terms govern the rights and obligations between the company and users regarding the Groupting service.\n\n(See full terms in Settings)';

  @override
  String get registerPrivacyPolicyFull => 'Privacy Policy';

  @override
  String get registerPrivacyPolicyContent =>
      '1. Personal Information Collected\n- Email, phone number, birth date, gender, etc.\n\n2. Purpose\n- Identity verification and service provision\n\n(See full policy in Settings)';

  @override
  String get registerPhoneVerifyNeeded => 'Please verify your phone number.';

  @override
  String get registerSuccess => 'Welcome! Please complete your profile.';

  @override
  String get registerTermsView => 'View';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(Object count) {
    return '${count}m ago';
  }

  @override
  String timeHoursAgo(Object count) {
    return '${count}h ago';
  }

  @override
  String timeDaysAgo(Object count) {
    return '${count}d ago';
  }

  @override
  String timeMonthDay(Object day, Object month) {
    return '$month/$day';
  }

  @override
  String get helpFAQSection => 'FAQ';

  @override
  String get helpGuideSection => 'User Guide';

  @override
  String get helpContactSection => 'Contact Us';

  @override
  String get helpServiceSection => 'Service Info';

  @override
  String get helpEmailContact => 'Email Inquiry';

  @override
  String get helpBugReportTitle => 'Report Bug';

  @override
  String get helpBugReportSubtitle => 'Having issues with the app?';

  @override
  String get helpBugReportHint => 'e.g., Button doesn\'t work on login screen.';

  @override
  String get helpBugReportContent => 'Please describe the bug in detail.';

  @override
  String get helpPhotoAttach => 'Attach Photo';

  @override
  String get helpPhotoSelected => 'Photo selected';

  @override
  String get helpSend => 'Send';

  @override
  String get helpEmailFailed =>
      'Cannot open email app. Please check your default mail app.';

  @override
  String get helpCustomerService => 'Customer Service Hours';

  @override
  String get helpOperatingHours =>
      'Weekdays: 09:00 - 18:00\nWeekends & Holidays: Closed';

  @override
  String get helpResponseTime => 'Response Time';

  @override
  String get helpResponseEmail => 'Email: Within 24 hours';

  @override
  String get helpFAQ1Q => 'How do I get started with Groupting?';

  @override
  String get helpFAQ1A =>
      '1. Complete your profile\n2. Invite friends or start matching alone\n3. Chat with matches when completed\n4. Plan real-life meetups';

  @override
  String get helpFAQ2Q =>
      'What\'s the difference between 1:1 and group matching?';

  @override
  String get helpFAQ2A =>
      '1:1 matching: Match with one other person by yourself.\nGroup matching: Match with another group of 2-5 people together with your friends.';

  @override
  String get helpFAQ3Q => 'What criteria is used for matching?';

  @override
  String get helpFAQ3A =>
      'Matching is based on:\n- Same or nearby activity area\n- Same group size\n- Currently waiting for match';

  @override
  String get helpFAQ4Q => 'How many profile photos can I upload?';

  @override
  String get helpFAQ4A =>
      'You can upload up to 6 photos.\nThe first photo becomes your main profile picture, and the rest are shown as additional photos.';

  @override
  String get helpFAQ5Q => 'I want to leave my group.';

  @override
  String get helpFAQ5A =>
      'Select \"Leave Group\" from the menu in the top right of the home screen.\nAfter leaving, you\'ll need to be invited again or create a new group.';

  @override
  String get helpFAQ6Q => 'Why am I not getting matched?';

  @override
  String get helpFAQ6A =>
      'Matching may be difficult when:\n- No groups waiting in your area\n- No groups with the same size\n- Few active users during matching hours';

  @override
  String get helpGuideSignup => 'Sign Up';

  @override
  String get helpGuideSignupDesc =>
      'Enter basic info and complete your profile';

  @override
  String get helpGuideSignupContent =>
      '1. Enter ID, password, phone, birth date, and gender\n2. Upload profile photos (up to 6)\n3. Enter height, nickname, location, and bio\n4. Start matching after completing your profile';

  @override
  String get helpGuideGroup => 'Create Group';

  @override
  String get helpGuideGroupDesc => 'Invite friends to form a group';

  @override
  String get helpGuideGroupContent =>
      '1. Press \"Create Group\" button on home\n2. Invite friends via \"Invite Friends\"\n3. Group is formed when friends accept\n4. Up to 5 people per group';

  @override
  String get helpGuideFilter => 'Apply Filters';

  @override
  String get helpGuideFilterDesc => 'Match with groups you prefer';

  @override
  String get helpGuideFilterContent =>
      '1. After creating a group, tap the filter button in top right\n2. Adjust filters\n3. Press Apply';

  @override
  String get helpGuideMatch => 'Start Matching';

  @override
  String get helpGuideMatchDesc => 'Start 1:1 or group matching';

  @override
  String get helpGuideMatchContent =>
      '1. \"Start Matching\" activates when group is ready\n2. Select \"Start 1:1 Matching\" if alone\n3. Select \"Start Group Matching\" if in a group\n4. You\'ll be notified when matched';

  @override
  String get helpGuideChat => 'Chat';

  @override
  String get helpGuideChatDesc => 'Chat with your matches';

  @override
  String get helpGuideChatContent =>
      '1. \"Chat\" button appears when matched\n2. Talk with your match in the chat room\n3. Get to know each other\n4. Plan real-life meetups';

  @override
  String get helpGuideSafety => 'Stay Safe';

  @override
  String get helpGuideSafetyDesc => 'Check safety guidelines for meetups';

  @override
  String get helpGuideSafetyContent =>
      '🔒 Protect Personal Info\n- Don\'t share personal info (address, workplace) until you trust them\n\n👥 First Meeting\n- Meet in public places\n- Meeting with friends is recommended\n\n🚨 Report\n- Report inappropriate users immediately\n- Screenshot and report offensive messages or photos';

  @override
  String get myPageEditProfile => 'Edit Profile';

  @override
  String get registerPhotos => 'Profile Photos';

  @override
  String get registerNickname => 'Nickname';

  @override
  String get registerNicknameHint => 'Enter nickname (2-10 characters)';

  @override
  String get registerHeight => 'Height (cm)';

  @override
  String get registerIntroHint =>
      'Write a nice bio about yourself.\n(Hobbies, interests, personality, etc.)';

  @override
  String get registerPhotosLongPress => 'Long press to set main photo';

  @override
  String get registerPhotosAdd => 'Add Photo';

  @override
  String get registerPhotosMain => 'Main';

  @override
  String get registerActivityArea => 'Activity Area';

  @override
  String get registerActivityAreaHint => 'Tap map to select location';

  @override
  String get registerPhotosMin => 'Please upload at least 1 photo.';

  @override
  String get settingsBlockConfirm =>
      'Blocking will hide each other\'s profiles,\nand prevent chats and invitations.\nAre you sure you want to block?';

  @override
  String get settingsReport => 'Report';

  @override
  String get settingsHelp => 'Help';

  @override
  String get homeTitle => 'Groupting';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeNavInvitations => 'Invites';

  @override
  String get homeNavMyPage => 'My Page';

  @override
  String get homeNavMore => 'More';

  @override
  String get homeMenuReceivedInvites => 'Received Invites';

  @override
  String get homeMenuMyPage => 'My Page';

  @override
  String get homeLeaveGroupTitle => 'Leave Group';

  @override
  String get homeLeaveGroupConfirm =>
      'Are you sure you want to leave the group?';

  @override
  String get homeLeaveGroupBtn => 'Leave';

  @override
  String get homeLeaveGroupSuccess => 'You have left the group.';

  @override
  String get homeLogoutTitle => 'Logout';

  @override
  String get homeLogoutConfirm => 'Are you sure you want to logout?';

  @override
  String get homeMatchSuccess => 'Match Success! 🎉';

  @override
  String get homeMatchSuccessDesc =>
      'You\'ve been matched!\nSay hello in the chat room 👋';

  @override
  String get homeLater => 'Later';

  @override
  String get homeGoToChat => 'Go to Chat';

  @override
  String get homeFilterMale => 'Male';

  @override
  String get homeFilterFemale => 'Female';

  @override
  String get homeFilterMixed => 'Mixed';

  @override
  String get homeFilterAny => 'Any';

  @override
  String homeFilterDistanceValue(Object km) {
    return 'Within ${km}km';
  }

  @override
  String get homeProfileCardHidden =>
      'Profile reminder hidden. You can complete your profile anytime from My Page.';

  @override
  String get homeProfileSignup => 'Sign Up';

  @override
  String get homeProfileBasicInfo => 'Enter Basic Info';

  @override
  String get homeProfileComplete => 'Complete Profile';

  @override
  String get homeProfileSignupDesc =>
      'Please complete sign up\nto use Groupting services!';

  @override
  String get homeProfileBasicInfoDesc =>
      'Phone, birth date, and gender required!';

  @override
  String get homeProfileCompleteDesc =>
      'Please enter nickname, height, area, etc!';

  @override
  String get homeProfileBasicInfoLong =>
      'Some required info is missing from sign up.\nPlease enter basic info and complete your profile!';

  @override
  String get homeProfileCompleteLong =>
      'Add nickname, height, bio, and activity area\nto use group creation and matching!';

  @override
  String get homeProfileNow => 'Complete Now';

  @override
  String get homeLoadingGroup => 'Loading group info...';

  @override
  String get homeLoadingWait => 'Please wait a moment.';

  @override
  String get homeErrorNetwork => 'Network Connection Error';

  @override
  String get homeErrorLoad => 'Failed to Load Data';

  @override
  String get homeErrorNetworkDesc =>
      'Please check your internet connection and try again.';

  @override
  String get homeErrorUnknown => 'An unknown error occurred.';

  @override
  String get homeErrorRetry => 'Retry';

  @override
  String get homeErrorCheckConnection => 'Check Connection';

  @override
  String get homeErrorWifiCheck =>
      'Please check your Wi-Fi or mobile data connection.';

  @override
  String get homeNoGroup => 'No Group';

  @override
  String get homeCreateGroup => 'Create New Group';

  @override
  String get homeProfileRequiredTitle => 'Profile Required';

  @override
  String get homeProfileRequiredDesc =>
      'Complete your profile to use the service.';

  @override
  String get homeProfileRequiredBtn => 'Complete Profile';

  @override
  String get homeMatchedStatus => 'Match Success! 🎉';

  @override
  String get homeMatchingStatus => 'Matching...';

  @override
  String get homeWaitingStatus => 'Waiting for Match';

  @override
  String get homeMatchedDesc => 'Start a conversation with your new match';

  @override
  String get homeMatchingDesc => 'Looking for a match...';

  @override
  String get homeWaitingDesc => 'Chat with your friends';

  @override
  String get homeNewMessage => 'New Message 💬';

  @override
  String get homeCurrentMembers => 'Current Members';

  @override
  String homeMemberCount(Object count) {
    return '$count members';
  }

  @override
  String get homeInvite => 'Invite';

  @override
  String get homeMatchFilter => 'Match Filter';

  @override
  String get homeErrorCheckConnectionDesc =>
      'Please check your Wi-Fi or mobile data connection.';

  @override
  String get storeTitle => 'Store';

  @override
  String get storeRestorePurchases => 'Restore';

  @override
  String get storeUnavailable => 'Store Unavailable';

  @override
  String get storeUnavailableDesc =>
      'The store is currently unavailable.\nPlease try again later.';

  @override
  String get storeError => 'An error occurred';

  @override
  String get storePremiumTitle => 'Groupting Premium';

  @override
  String get storePremiumSubtitle => 'Unlock more features';

  @override
  String get storeBenefit1 => 'Unlimited profile views';

  @override
  String get storeBenefit2 => 'Priority matching';

  @override
  String get storeBenefit3 => 'Special emoticons';

  @override
  String get storePremiumSection => 'Premium Subscription';

  @override
  String get storeCoinsSection => 'Coin Packages';

  @override
  String get storeMonthlyPlan => 'Monthly';

  @override
  String get storeYearlyPlan => 'Yearly';

  @override
  String get storePopular => 'Popular';

  @override
  String get storePurchased => 'Active';

  @override
  String get storeBuyButton => 'Buy';

  @override
  String get storeCoins => 'Coins';

  @override
  String get storeNoProducts => 'No products available';

  @override
  String get storeNoProductsDesc =>
      'No products are available at this time.\nPlease check back later.';

  @override
  String get storeRechargeTitle => 'Recharge Ting';

  @override
  String get storeRechargeDesc => 'Recharge Ting for matching';

  @override
  String get storeBonusPromo => 'Buy more, get more bonus!';

  @override
  String get storeTingPackages => 'Ting Packages';

  @override
  String storeBonus(Object amount) {
    return '+$amount Bonus';
  }

  @override
  String get storeSecurePayment => 'Secure Payment';

  @override
  String get storeSecurePaymentDesc =>
      'Safe payment via Google Play / App Store';

  @override
  String storePurchaseStart(Object amount) {
    return 'Starting purchase of $amount Ting...';
  }

  @override
  String get storePurchase => 'Purchase';

  @override
  String storePurchaseSuccess(Object amount) {
    return '$amount Ting has been added! 🎉';
  }

  @override
  String get storePurchaseFailed => 'Purchase failed. Please try again.';

  @override
  String ratingDialogTitle(Object nickname) {
    return 'Rate attractiveness of $nickname';
  }

  @override
  String get ratingDialogPrompt => 'Tap a star to rate:';

  @override
  String get ratingDialogSubmit => 'Submit';

  @override
  String get ratingSaved => 'Rating saved!';

  @override
  String get ratingAlreadyRated => 'You have already rated this user';

  @override
  String get opentingTitle => 'Open Chat';

  @override
  String get opentingLeaveChat => 'Leave Open Chat';

  @override
  String get opentingNoMembers => 'No members';

  @override
  String get opentingWelcome => 'Welcome to the chatroom!';

  @override
  String get opentingStartConversation =>
      'Start a conversation with other participants';

  @override
  String get opentingCreateRoomTitle => 'Create Open Chatroom';

  @override
  String get opentingRoomTitle => 'Room Title';

  @override
  String get opentingRoomTitleHint => 'Enter room title';

  @override
  String get opentingMaxParticipants => 'Max Participants';

  @override
  String opentingParticipantsCount(Object count) {
    return '$count participants';
  }

  @override
  String get opentingEnterRoomTitle => 'Please enter a room title';

  @override
  String get opentingCreateSuccess => 'Open chatroom created successfully!';

  @override
  String get opentingCreateFailed => 'Failed to create chatroom';

  @override
  String opentingRoomFull(Object count) {
    return 'Chatroom is full ($count/$count)';
  }

  @override
  String get opentingJoinSuccess => 'Joined chatroom successfully!';

  @override
  String get opentingJoinFailed => 'Failed to join chatroom';

  @override
  String get opentingDistanceFilter => 'Distance Filter';

  @override
  String get opentingMaxDistance => 'Maximum Distance';

  @override
  String get opentingLoadError => 'Error loading chatrooms';

  @override
  String get opentingNoRoomsFound => 'No Chatrooms Found';

  @override
  String opentingAdjustFilter(Object distance) {
    return 'Try adjusting your distance filter (${distance}km)';
  }

  @override
  String get opentingJoined => 'Joined';

  @override
  String get opentingJoinRoom => 'Join Room';

  @override
  String get opentingCreateRoom => 'Create Room';

  @override
  String get opentingNoRooms => 'No Open Chatrooms';

  @override
  String get opentingBeFirst => 'Be the first to create an open chatroom!';
}

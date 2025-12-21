import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹팅'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'친구들과 함께 즐기는\n새로운 만남의 시작'**
  String get appSubtitle;

  /// No description provided for @commonConfirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get commonConfirm;

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// No description provided for @commonComplete.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get commonComplete;

  /// No description provided for @commonSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get commonEdit;

  /// No description provided for @commonNext.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get commonNext;

  /// No description provided for @commonLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get commonLater;

  /// No description provided for @commonYes.
  ///
  /// In ko, this message translates to:
  /// **'예'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In ko, this message translates to:
  /// **'아니요'**
  String get commonNo;

  /// No description provided for @commonLoading.
  ///
  /// In ko, this message translates to:
  /// **'로딩 중...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In ko, this message translates to:
  /// **'오류'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get commonRetry;

  /// No description provided for @loginTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get loginTitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In ko, this message translates to:
  /// **'example@email.com'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 입력해주세요'**
  String get loginPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get loginButton;

  /// No description provided for @loginNoAccount.
  ///
  /// In ko, this message translates to:
  /// **'계정이 없으신가요?'**
  String get loginNoAccount;

  /// No description provided for @loginRegister.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get loginRegister;

  /// No description provided for @loginErrorEmailEmpty.
  ///
  /// In ko, this message translates to:
  /// **'이메일을 입력해주세요.'**
  String get loginErrorEmailEmpty;

  /// No description provided for @loginErrorEmailInvalid.
  ///
  /// In ko, this message translates to:
  /// **'올바른 이메일 형식을 입력해주세요.'**
  String get loginErrorEmailInvalid;

  /// No description provided for @loginErrorPasswordEmpty.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 입력해주세요.'**
  String get loginErrorPasswordEmpty;

  /// No description provided for @loginErrorPasswordShort.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 6자 이상이어야 합니다.'**
  String get loginErrorPasswordShort;

  /// No description provided for @registerTitle.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get registerTitle;

  /// No description provided for @registerWelcome.
  ///
  /// In ko, this message translates to:
  /// **'환영합니다!'**
  String get registerWelcome;

  /// No description provided for @registerWelcomeDesc.
  ///
  /// In ko, this message translates to:
  /// **'새로운 인연을 만날 준비가 되셨나요?\n간단한 정보 입력으로 시작해보세요.'**
  String get registerWelcomeDesc;

  /// No description provided for @registerAccountInfo.
  ///
  /// In ko, this message translates to:
  /// **'계정 정보'**
  String get registerAccountInfo;

  /// No description provided for @registerPasswordHint8Chars.
  ///
  /// In ko, this message translates to:
  /// **'8자 이상 입력'**
  String get registerPasswordHint8Chars;

  /// No description provided for @registerPasswordConfirm.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 확인'**
  String get registerPasswordConfirm;

  /// No description provided for @registerPasswordConfirmHint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 재입력'**
  String get registerPasswordConfirmHint;

  /// No description provided for @registerPersonalInfo.
  ///
  /// In ko, this message translates to:
  /// **'개인 정보'**
  String get registerPersonalInfo;

  /// No description provided for @registerPhone.
  ///
  /// In ko, this message translates to:
  /// **'전화번호'**
  String get registerPhone;

  /// No description provided for @registerPhoneVerify.
  ///
  /// In ko, this message translates to:
  /// **'인증'**
  String get registerPhoneVerify;

  /// No description provided for @registerPhoneComplete.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get registerPhoneComplete;

  /// No description provided for @registerVerificationCode.
  ///
  /// In ko, this message translates to:
  /// **'인증번호 6자리'**
  String get registerVerificationCode;

  /// No description provided for @registerBirthDate.
  ///
  /// In ko, this message translates to:
  /// **'생년월일'**
  String get registerBirthDate;

  /// No description provided for @registerBirthDateHint.
  ///
  /// In ko, this message translates to:
  /// **'19950315'**
  String get registerBirthDateHint;

  /// No description provided for @registerBirthDateHelper.
  ///
  /// In ko, this message translates to:
  /// **'YYYYMMDD 형태로 입력해주세요'**
  String get registerBirthDateHelper;

  /// No description provided for @registerGender.
  ///
  /// In ko, this message translates to:
  /// **'성별'**
  String get registerGender;

  /// No description provided for @registerMale.
  ///
  /// In ko, this message translates to:
  /// **'남성'**
  String get registerMale;

  /// No description provided for @registerFemale.
  ///
  /// In ko, this message translates to:
  /// **'여성'**
  String get registerFemale;

  /// No description provided for @registerTerms.
  ///
  /// In ko, this message translates to:
  /// **'약관 동의'**
  String get registerTerms;

  /// No description provided for @registerTermsService.
  ///
  /// In ko, this message translates to:
  /// **'[필수] 서비스 이용약관 동의'**
  String get registerTermsService;

  /// No description provided for @registerTermsPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'[필수] 개인정보 처리방침 동의'**
  String get registerTermsPrivacy;

  /// No description provided for @registerButton.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get registerButton;

  /// No description provided for @registerHaveAccount.
  ///
  /// In ko, this message translates to:
  /// **'이미 계정이 있으신가요?'**
  String get registerHaveAccount;

  /// No description provided for @registerLoginLink.
  ///
  /// In ko, this message translates to:
  /// **'로그인하기'**
  String get registerLoginLink;

  /// No description provided for @registerErrorPasswordMismatch.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 일치하지 않습니다.'**
  String get registerErrorPasswordMismatch;

  /// No description provided for @registerErrorGender.
  ///
  /// In ko, this message translates to:
  /// **'성별을 선택해주세요.'**
  String get registerErrorGender;

  /// No description provided for @registerErrorTerms.
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용약관 및 개인정보 처리방침에 동의해주세요.'**
  String get registerErrorTerms;

  /// No description provided for @homeTabHome.
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get homeTabHome;

  /// No description provided for @homeTabInvite.
  ///
  /// In ko, this message translates to:
  /// **'초대'**
  String get homeTabInvite;

  /// No description provided for @homeTabMyPage.
  ///
  /// In ko, this message translates to:
  /// **'마이페이지'**
  String get homeTabMyPage;

  /// No description provided for @homeTabMore.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get homeTabMore;

  /// No description provided for @homeProfileCardTitle.
  ///
  /// In ko, this message translates to:
  /// **'프로필 완성하기'**
  String get homeProfileCardTitle;

  /// No description provided for @homeProfileCardDesc.
  ///
  /// In ko, this message translates to:
  /// **'닉네임, 키, 소개글, 활동지역을 추가하면\n그룹 생성과 매칭 기능을 사용할 수 있어요!'**
  String get homeProfileCardDesc;

  /// No description provided for @homeProfileCardButton.
  ///
  /// In ko, this message translates to:
  /// **'지금 완성하기'**
  String get homeProfileCardButton;

  /// No description provided for @homeNoGroupTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹이 없습니다'**
  String get homeNoGroupTitle;

  /// No description provided for @homeNoGroupDesc.
  ///
  /// In ko, this message translates to:
  /// **'새로운 그룹을 만들어\n친구들과 함께하세요!'**
  String get homeNoGroupDesc;

  /// No description provided for @homeCreateGroupButton.
  ///
  /// In ko, this message translates to:
  /// **'새 그룹 만들기'**
  String get homeCreateGroupButton;

  /// No description provided for @homeGroupStatusMatching.
  ///
  /// In ko, this message translates to:
  /// **'매칭 진행중...'**
  String get homeGroupStatusMatching;

  /// No description provided for @homeGroupStatusMatched.
  ///
  /// In ko, this message translates to:
  /// **'매칭 성공! 🎉'**
  String get homeGroupStatusMatched;

  /// No description provided for @homeGroupStatusWaiting.
  ///
  /// In ko, this message translates to:
  /// **'매칭 대기중'**
  String get homeGroupStatusWaiting;

  /// No description provided for @homeGroupDescMatching.
  ///
  /// In ko, this message translates to:
  /// **'매칭 상대를 찾고 있어요...'**
  String get homeGroupDescMatching;

  /// No description provided for @homeGroupDescMatched.
  ///
  /// In ko, this message translates to:
  /// **'새로운 인연과 대화를 시작해보세요'**
  String get homeGroupDescMatched;

  /// No description provided for @homeGroupDescWaiting.
  ///
  /// In ko, this message translates to:
  /// **'친구들과 대화 해보세요'**
  String get homeGroupDescWaiting;

  /// No description provided for @homeStartMatching.
  ///
  /// In ko, this message translates to:
  /// **'매칭 시작'**
  String get homeStartMatching;

  /// No description provided for @homeCancelMatching.
  ///
  /// In ko, this message translates to:
  /// **'매칭 취소'**
  String get homeCancelMatching;

  /// No description provided for @homeEnterChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 입장'**
  String get homeEnterChat;

  /// No description provided for @homeGroupMembers.
  ///
  /// In ko, this message translates to:
  /// **'현재 그룹 멤버'**
  String get homeGroupMembers;

  /// No description provided for @homeInviteFriend.
  ///
  /// In ko, this message translates to:
  /// **'초대하기'**
  String get homeInviteFriend;

  /// No description provided for @homeDialogMatchedTitle.
  ///
  /// In ko, this message translates to:
  /// **'매칭 성공! 🎉'**
  String get homeDialogMatchedTitle;

  /// No description provided for @homeDialogMatchedContent.
  ///
  /// In ko, this message translates to:
  /// **'매칭되었습니다!\n채팅방에서 인사해보세요 👋'**
  String get homeDialogMatchedContent;

  /// No description provided for @homeDialogGoToChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅방으로 이동'**
  String get homeDialogGoToChat;

  /// No description provided for @homeMenuLeaveGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹 나가기'**
  String get homeMenuLeaveGroup;

  /// No description provided for @homeMenuLogout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get homeMenuLogout;

  /// No description provided for @dialogLeaveGroupTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹 나가기'**
  String get dialogLeaveGroupTitle;

  /// No description provided for @dialogLeaveGroupContent.
  ///
  /// In ko, this message translates to:
  /// **'정말로 그룹을 나가시겠습니까?'**
  String get dialogLeaveGroupContent;

  /// No description provided for @dialogLogoutTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get dialogLogoutTitle;

  /// No description provided for @dialogLogoutContent.
  ///
  /// In ko, this message translates to:
  /// **'정말로 로그아웃 하시겠습니까?'**
  String get dialogLogoutContent;

  /// No description provided for @dialogLeaveGroupAction.
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get dialogLeaveGroupAction;

  /// No description provided for @myPageTitle.
  ///
  /// In ko, this message translates to:
  /// **'마이페이지'**
  String get myPageTitle;

  /// No description provided for @myPageEmptyProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필을 만들어주세요'**
  String get myPageEmptyProfile;

  /// No description provided for @myPageEmptyDesc.
  ///
  /// In ko, this message translates to:
  /// **'새로운 인연을 만날 준비가 되셨나요?'**
  String get myPageEmptyDesc;

  /// No description provided for @myPageCreateProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필 만들기'**
  String get myPageCreateProfile;

  /// No description provided for @myPageBasicInfo.
  ///
  /// In ko, this message translates to:
  /// **'기본 정보'**
  String get myPageBasicInfo;

  /// No description provided for @myPagePhone.
  ///
  /// In ko, this message translates to:
  /// **'전화번호'**
  String get myPagePhone;

  /// No description provided for @myPageHeight.
  ///
  /// In ko, this message translates to:
  /// **'키'**
  String get myPageHeight;

  /// No description provided for @myPageLocation.
  ///
  /// In ko, this message translates to:
  /// **'위치'**
  String get myPageLocation;

  /// No description provided for @myPageIntro.
  ///
  /// In ko, this message translates to:
  /// **'자기소개'**
  String get myPageIntro;

  /// No description provided for @myPageMenuSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get myPageMenuSettings;

  /// No description provided for @myPageMenuHelp.
  ///
  /// In ko, this message translates to:
  /// **'도움말'**
  String get myPageMenuHelp;

  /// No description provided for @myPageMenuAppInfo.
  ///
  /// In ko, this message translates to:
  /// **'앱 정보'**
  String get myPageMenuAppInfo;

  /// No description provided for @profileEditTitle.
  ///
  /// In ko, this message translates to:
  /// **'프로필 편집'**
  String get profileEditTitle;

  /// No description provided for @profileEditImage.
  ///
  /// In ko, this message translates to:
  /// **'프로필 사진'**
  String get profileEditImage;

  /// No description provided for @profileEditImageGuide.
  ///
  /// In ko, this message translates to:
  /// **'대표 사진은 길게 눌러 설정하세요'**
  String get profileEditImageGuide;

  /// No description provided for @profileEditImageAdd.
  ///
  /// In ko, this message translates to:
  /// **'사진 추가'**
  String get profileEditImageAdd;

  /// No description provided for @profileEditImageMain.
  ///
  /// In ko, this message translates to:
  /// **'대표'**
  String get profileEditImageMain;

  /// No description provided for @profileEditNickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get profileEditNickname;

  /// No description provided for @profileEditNicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 입력하세요 (2~10자)'**
  String get profileEditNicknameHint;

  /// No description provided for @profileEditHeight.
  ///
  /// In ko, this message translates to:
  /// **'키 (cm)'**
  String get profileEditHeight;

  /// No description provided for @profileEditLocation.
  ///
  /// In ko, this message translates to:
  /// **'활동지역'**
  String get profileEditLocation;

  /// No description provided for @profileEditLocationHint.
  ///
  /// In ko, this message translates to:
  /// **'지도를 눌러 위치를 선택하세요'**
  String get profileEditLocationHint;

  /// No description provided for @profileEditIntro.
  ///
  /// In ko, this message translates to:
  /// **'자기소개'**
  String get profileEditIntro;

  /// No description provided for @profileEditIntroHint.
  ///
  /// In ko, this message translates to:
  /// **'나를 표현하는 멋진 소개글을 작성해보세요.\n(취미, 관심사, 성격 등)'**
  String get profileEditIntroHint;

  /// No description provided for @profileEditAccountInfo.
  ///
  /// In ko, this message translates to:
  /// **'계정 정보'**
  String get profileEditAccountInfo;

  /// No description provided for @profileEditErrorImages.
  ///
  /// In ko, this message translates to:
  /// **'사진을 최소 1장 등록해주세요.'**
  String get profileEditErrorImages;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsNotification.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get settingsNotification;

  /// No description provided for @settingsNotiMatch.
  ///
  /// In ko, this message translates to:
  /// **'매칭 알림'**
  String get settingsNotiMatch;

  /// No description provided for @settingsNotiInvite.
  ///
  /// In ko, this message translates to:
  /// **'초대 알림'**
  String get settingsNotiInvite;

  /// No description provided for @settingsNotiChat.
  ///
  /// In ko, this message translates to:
  /// **'메세지 알림'**
  String get settingsNotiChat;

  /// No description provided for @settingsAccount.
  ///
  /// In ko, this message translates to:
  /// **'계정'**
  String get settingsAccount;

  /// No description provided for @settingsChangePw.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 변경'**
  String get settingsChangePw;

  /// No description provided for @settingsBlock.
  ///
  /// In ko, this message translates to:
  /// **'차단 관리'**
  String get settingsBlock;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'계정 삭제'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsInfo.
  ///
  /// In ko, this message translates to:
  /// **'정보 및 지원'**
  String get settingsInfo;

  /// No description provided for @settingsPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보 처리방침'**
  String get settingsPrivacy;

  /// No description provided for @settingsTerms.
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용약관'**
  String get settingsTerms;

  /// No description provided for @settingsAppVersion.
  ///
  /// In ko, this message translates to:
  /// **'앱 버전'**
  String get settingsAppVersion;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In ko, this message translates to:
  /// **'정말로 삭제합니다.'**
  String get settingsDeleteAccountConfirm;

  /// No description provided for @chatTitle.
  ///
  /// In ko, this message translates to:
  /// **'채팅'**
  String get chatTitle;

  /// No description provided for @chatMatchingTitle.
  ///
  /// In ko, this message translates to:
  /// **'매칭 채팅'**
  String get chatMatchingTitle;

  /// No description provided for @chatGroupTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹 채팅'**
  String get chatGroupTitle;

  /// No description provided for @chatInputHint.
  ///
  /// In ko, this message translates to:
  /// **'메시지 보내기'**
  String get chatInputHint;

  /// No description provided for @chatEmptyMatched.
  ///
  /// In ko, this message translates to:
  /// **'매칭 성공! 🎉'**
  String get chatEmptyMatched;

  /// No description provided for @chatEmptyGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹 채팅 시작 👋'**
  String get chatEmptyGroup;

  /// No description provided for @inviteTitle.
  ///
  /// In ko, this message translates to:
  /// **'친구 초대'**
  String get inviteTitle;

  /// No description provided for @inviteGuide.
  ///
  /// In ko, this message translates to:
  /// **'초대 안내'**
  String get inviteGuide;

  /// No description provided for @inviteGuideDesc.
  ///
  /// In ko, this message translates to:
  /// **'친구의 닉네임을 정확히 입력해주세요\n최대 5명까지 그룹을 구성할 수 있습니다'**
  String get inviteGuideDesc;

  /// No description provided for @inviteCurrentMember.
  ///
  /// In ko, this message translates to:
  /// **'현재 그룹 인원'**
  String get inviteCurrentMember;

  /// No description provided for @inviteNicknameLabel.
  ///
  /// In ko, this message translates to:
  /// **'친구 닉네임'**
  String get inviteNicknameLabel;

  /// No description provided for @inviteNicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'초대할 친구의 닉네임을 입력하세요'**
  String get inviteNicknameHint;

  /// No description provided for @inviteMessageLabel.
  ///
  /// In ko, this message translates to:
  /// **'초대 메세지 (선택사항)'**
  String get inviteMessageLabel;

  /// No description provided for @inviteMessageHint.
  ///
  /// In ko, this message translates to:
  /// **'친구에게 전할 메세지를 입력하세요'**
  String get inviteMessageHint;

  /// No description provided for @inviteButton.
  ///
  /// In ko, this message translates to:
  /// **'초대하기'**
  String get inviteButton;

  /// No description provided for @inviteSentList.
  ///
  /// In ko, this message translates to:
  /// **'보낸 초대'**
  String get inviteSentList;

  /// No description provided for @inviteStatusPending.
  ///
  /// In ko, this message translates to:
  /// **'응답 대기 중'**
  String get inviteStatusPending;

  /// No description provided for @inviteStatusAccepted.
  ///
  /// In ko, this message translates to:
  /// **'수락됨'**
  String get inviteStatusAccepted;

  /// No description provided for @inviteStatusRejected.
  ///
  /// In ko, this message translates to:
  /// **'거절됨'**
  String get inviteStatusRejected;

  /// No description provided for @inviteStatusExpired.
  ///
  /// In ko, this message translates to:
  /// **'만료됨'**
  String get inviteStatusExpired;

  /// No description provided for @invitationListTitle.
  ///
  /// In ko, this message translates to:
  /// **'받은 초대'**
  String get invitationListTitle;

  /// No description provided for @invitationEmpty.
  ///
  /// In ko, this message translates to:
  /// **'받은 초대가 없습니다'**
  String get invitationEmpty;

  /// No description provided for @invitationFrom.
  ///
  /// In ko, this message translates to:
  /// **'{name}님의 초대'**
  String invitationFrom(Object name);

  /// No description provided for @invitationExpired.
  ///
  /// In ko, this message translates to:
  /// **'초대가 만료되었습니다'**
  String get invitationExpired;

  /// No description provided for @invitationAccept.
  ///
  /// In ko, this message translates to:
  /// **'수락'**
  String get invitationAccept;

  /// No description provided for @invitationReject.
  ///
  /// In ko, this message translates to:
  /// **'거절'**
  String get invitationReject;

  /// No description provided for @invitationMoveGroupTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹 이동'**
  String get invitationMoveGroupTitle;

  /// No description provided for @invitationMoveGroupContent.
  ///
  /// In ko, this message translates to:
  /// **'현재 그룹을 떠나고 새 그룹으로 이동하시겠습니까?'**
  String get invitationMoveGroupContent;

  /// No description provided for @locationPickerTitle.
  ///
  /// In ko, this message translates to:
  /// **'활동지역 선택'**
  String get locationPickerTitle;

  /// No description provided for @locationPickerSearching.
  ///
  /// In ko, this message translates to:
  /// **'위치를 탐색 중입니다...'**
  String get locationPickerSearching;

  /// No description provided for @locationPickerSelect.
  ///
  /// In ko, this message translates to:
  /// **'이 위치로 설정'**
  String get locationPickerSelect;

  /// No description provided for @helpTitle.
  ///
  /// In ko, this message translates to:
  /// **'도움말'**
  String get helpTitle;

  /// No description provided for @helpFAQ.
  ///
  /// In ko, this message translates to:
  /// **'자주 묻는 질문'**
  String get helpFAQ;

  /// No description provided for @helpGuide.
  ///
  /// In ko, this message translates to:
  /// **'이용 가이드'**
  String get helpGuide;

  /// No description provided for @helpContact.
  ///
  /// In ko, this message translates to:
  /// **'문의하기'**
  String get helpContact;

  /// No description provided for @helpEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일 문의'**
  String get helpEmail;

  /// No description provided for @helpBugReport.
  ///
  /// In ko, this message translates to:
  /// **'버그 신고'**
  String get helpBugReport;

  /// No description provided for @helpServiceInfo.
  ///
  /// In ko, this message translates to:
  /// **'서비스 정보'**
  String get helpServiceInfo;

  /// No description provided for @profileDetailReport.
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get profileDetailReport;

  /// No description provided for @profileDetailBlock.
  ///
  /// In ko, this message translates to:
  /// **'차단하기'**
  String get profileDetailBlock;

  /// No description provided for @profileDetailBlockConfirm.
  ///
  /// In ko, this message translates to:
  /// **'차단하면 서로의 프로필을 볼 수 없으며,\n채팅 및 초대를 받을 수 없습니다.\n정말 차단하시겠습니까?'**
  String get profileDetailBlockConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

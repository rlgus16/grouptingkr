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

  /// No description provided for @loginForgotPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 잊으셨나요?'**
  String get loginForgotPassword;

  /// No description provided for @loginForgotPasswordTitle.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 찾기'**
  String get loginForgotPasswordTitle;

  /// No description provided for @loginForgotPasswordDesc.
  ///
  /// In ko, this message translates to:
  /// **'가입 시 사용한 이메일을 입력하시면\n비밀번호 재설정 링크를 보내드립니다.'**
  String get loginForgotPasswordDesc;

  /// No description provided for @loginForgotPasswordSent.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 재설정 이메일을 보냈습니다. 이메일을 확인해주세요.'**
  String get loginForgotPasswordSent;

  /// No description provided for @loginForgotPasswordError.
  ///
  /// In ko, this message translates to:
  /// **'이메일 발송에 실패했습니다. 이메일 주소를 확인해주세요.'**
  String get loginForgotPasswordError;

  /// No description provided for @loginForgotPasswordSendButton.
  ///
  /// In ko, this message translates to:
  /// **'이메일 보내기'**
  String get loginForgotPasswordSendButton;

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

  /// No description provided for @myPageMenuStore.
  ///
  /// In ko, this message translates to:
  /// **'스토어'**
  String get myPageMenuStore;

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

  /// No description provided for @settingsBlockEmpty.
  ///
  /// In ko, this message translates to:
  /// **'차단한 사용자가 없습니다'**
  String get settingsBlockEmpty;

  /// No description provided for @settingsUnblock.
  ///
  /// In ko, this message translates to:
  /// **'차단 해제'**
  String get settingsUnblock;

  /// No description provided for @settingsExemption.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외 관리'**
  String get settingsExemption;

  /// No description provided for @settingsExemptionEmpty.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외한 사용자가 없습니다'**
  String get settingsExemptionEmpty;

  /// No description provided for @settingsExemptionRemove.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외 해제'**
  String get settingsExemptionRemove;

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
  /// **'친구의 전화번호를 정확히 입력해주세요\n최대 5명까지 그룹을 구성할 수 있습니다'**
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

  /// No description provided for @invitePhoneLabel.
  ///
  /// In ko, this message translates to:
  /// **'전화번호'**
  String get invitePhoneLabel;

  /// No description provided for @invitePhoneHint.
  ///
  /// In ko, this message translates to:
  /// **'전화번호를 입력해주세요 (- 없이 입력)'**
  String get invitePhoneHint;

  /// No description provided for @invitePhoneEmpty.
  ///
  /// In ko, this message translates to:
  /// **'전화번호를 입력해주세요.'**
  String get invitePhoneEmpty;

  /// No description provided for @invitePhoneInvalid.
  ///
  /// In ko, this message translates to:
  /// **'올바른 전화번호 형식이 아닙니다.'**
  String get invitePhoneInvalid;

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

  /// No description provided for @updateTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 안내'**
  String get updateTitle;

  /// No description provided for @updateButton.
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트'**
  String get updateButton;

  /// No description provided for @locationPickerError.
  ///
  /// In ko, this message translates to:
  /// **'주소를 찾을 수 없습니다.'**
  String get locationPickerError;

  /// No description provided for @inviteSentSuccess.
  ///
  /// In ko, this message translates to:
  /// **'초대를 보냈어요!'**
  String get inviteSentSuccess;

  /// No description provided for @inviteWho.
  ///
  /// In ko, this message translates to:
  /// **'누구를 초대할까요?'**
  String get inviteWho;

  /// No description provided for @inviteNicknameEmpty.
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 입력해주세요.'**
  String get inviteNicknameEmpty;

  /// No description provided for @inviteMessagePlaceholder.
  ///
  /// In ko, this message translates to:
  /// **'같이 그룹팅하자!'**
  String get inviteMessagePlaceholder;

  /// No description provided for @inviteSendButton.
  ///
  /// In ko, this message translates to:
  /// **'초대장 보내기'**
  String get inviteSendButton;

  /// No description provided for @inviteNoMessage.
  ///
  /// In ko, this message translates to:
  /// **'메세지 없음'**
  String get inviteNoMessage;

  /// No description provided for @invitationNewGroup.
  ///
  /// In ko, this message translates to:
  /// **'새로운 그룹에 초대되었어요!'**
  String get invitationNewGroup;

  /// No description provided for @invitationNewPrivateChat.
  ///
  /// In ko, this message translates to:
  /// **'1:1 채팅에 초대되었어요!'**
  String get invitationNewPrivateChat;

  /// No description provided for @invitationExpiredLabel.
  ///
  /// In ko, this message translates to:
  /// **'유효기간이 만료된 초대입니다'**
  String get invitationExpiredLabel;

  /// No description provided for @invitationJoinedSuccess.
  ///
  /// In ko, this message translates to:
  /// **'그룹에 참여했어요!'**
  String get invitationJoinedSuccess;

  /// No description provided for @invitationRejectedInfo.
  ///
  /// In ko, this message translates to:
  /// **'초대를 거절했어요'**
  String get invitationRejectedInfo;

  /// No description provided for @invitationMoveAction.
  ///
  /// In ko, this message translates to:
  /// **'이동하기'**
  String get invitationMoveAction;

  /// No description provided for @invitationEmptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'아직 받은 초대가 없어요'**
  String get invitationEmptyTitle;

  /// No description provided for @invitationEmptyDesc.
  ///
  /// In ko, this message translates to:
  /// **'친구가 초대를 보내면 여기에 표시됩니다'**
  String get invitationEmptyDesc;

  /// No description provided for @chatParticipating.
  ///
  /// In ko, this message translates to:
  /// **'{count}명 참여 중'**
  String chatParticipating(Object count);

  /// No description provided for @chatFindingMatch.
  ///
  /// In ko, this message translates to:
  /// **'매칭 상대를 찾고 있어요...'**
  String get chatFindingMatch;

  /// No description provided for @chatInviteFriend.
  ///
  /// In ko, this message translates to:
  /// **'친구 초대하기'**
  String get chatInviteFriend;

  /// No description provided for @chatWaitingResponse.
  ///
  /// In ko, this message translates to:
  /// **'{count}명의 친구가 응답 대기 중입니다'**
  String chatWaitingResponse(Object count);

  /// No description provided for @chatEmptyMatchedDesc.
  ///
  /// In ko, this message translates to:
  /// **'설레는 대화를 시작해보세요.\n서로에 대해 알아가는 시간이 되길 바래요!'**
  String get chatEmptyMatchedDesc;

  /// No description provided for @chatEmptyGroupWithFriends.
  ///
  /// In ko, this message translates to:
  /// **'친구들과 자유롭게 대화를 나눠보세요!'**
  String get chatEmptyGroupWithFriends;

  /// No description provided for @chatEmptyAlone.
  ///
  /// In ko, this message translates to:
  /// **'아직 그룹에 혼자 있어요.\n친구들을 초대 해보세요!'**
  String get chatEmptyAlone;

  /// No description provided for @myPageAge.
  ///
  /// In ko, this message translates to:
  /// **'{age}세'**
  String myPageAge(Object age);

  /// No description provided for @myPageMale.
  ///
  /// In ko, this message translates to:
  /// **'남성'**
  String get myPageMale;

  /// No description provided for @myPageFemale.
  ///
  /// In ko, this message translates to:
  /// **'여성'**
  String get myPageFemale;

  /// No description provided for @myPageLogoutError.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 중 오류가 발생했습니다.'**
  String get myPageLogoutError;

  /// No description provided for @myPageAppName.
  ///
  /// In ko, this message translates to:
  /// **'Groupting'**
  String get myPageAppName;

  /// No description provided for @myPageAppVersion.
  ///
  /// In ko, this message translates to:
  /// **'Version 1.0.0'**
  String get myPageAppVersion;

  /// No description provided for @myPageAppDesc.
  ///
  /// In ko, this message translates to:
  /// **'친구들과 함께하는 소개팅 플랫폼'**
  String get myPageAppDesc;

  /// No description provided for @homeReceivedInvite.
  ///
  /// In ko, this message translates to:
  /// **'받은 초대'**
  String get homeReceivedInvite;

  /// No description provided for @homeLeftGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹에서 나왔습니다.'**
  String get homeLeftGroup;

  /// No description provided for @homeFilterTitle.
  ///
  /// In ko, this message translates to:
  /// **'필터 설정'**
  String get homeFilterTitle;

  /// No description provided for @homeFilterGender.
  ///
  /// In ko, this message translates to:
  /// **'상대 그룹 성별'**
  String get homeFilterGender;

  /// No description provided for @homeFilterAge.
  ///
  /// In ko, this message translates to:
  /// **'상대 그룹 평균 나이'**
  String get homeFilterAge;

  /// No description provided for @homeFilterHeight.
  ///
  /// In ko, this message translates to:
  /// **'상대 그룹 평균 키'**
  String get homeFilterHeight;

  /// No description provided for @homeFilterDistance.
  ///
  /// In ko, this message translates to:
  /// **'거리 범위 (방장 기준)'**
  String get homeFilterDistance;

  /// No description provided for @homeFilterApply.
  ///
  /// In ko, this message translates to:
  /// **'적용하기'**
  String get homeFilterApply;

  /// No description provided for @homeFilterSuccess.
  ///
  /// In ko, this message translates to:
  /// **'필터가 성공적으로 적용되었습니다.'**
  String get homeFilterSuccess;

  /// No description provided for @homeFilterFailed.
  ///
  /// In ko, this message translates to:
  /// **'필터 적용 실패'**
  String get homeFilterFailed;

  /// No description provided for @homeGenderMale.
  ///
  /// In ko, this message translates to:
  /// **'남자'**
  String get homeGenderMale;

  /// No description provided for @homeGenderFemale.
  ///
  /// In ko, this message translates to:
  /// **'여자'**
  String get homeGenderFemale;

  /// No description provided for @homeGenderMixed.
  ///
  /// In ko, this message translates to:
  /// **'혼성'**
  String get homeGenderMixed;

  /// No description provided for @homeGenderAny.
  ///
  /// In ko, this message translates to:
  /// **'상관없음'**
  String get homeGenderAny;

  /// No description provided for @homeProfileHiddenMsg.
  ///
  /// In ko, this message translates to:
  /// **'프로필 완성하기 알림을 숨겼습니다. 마이페이지에서 언제든 프로필을 완성할 수 있습니다.'**
  String get homeProfileHiddenMsg;

  /// No description provided for @homeLogoutError.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 중 오류가 발생했습니다'**
  String get homeLogoutError;

  /// No description provided for @profileDetailReportTitle.
  ///
  /// In ko, this message translates to:
  /// **'사용자 신고'**
  String get profileDetailReportTitle;

  /// No description provided for @profileDetailReportReason.
  ///
  /// In ko, this message translates to:
  /// **'신고 사유를 선택해주세요.'**
  String get profileDetailReportReason;

  /// No description provided for @profileDetailReportContent.
  ///
  /// In ko, this message translates to:
  /// **'신고 내용을 자세히 적어주세요.'**
  String get profileDetailReportContent;

  /// No description provided for @profileDetailReportPhoto.
  ///
  /// In ko, this message translates to:
  /// **'증거 사진 첨부'**
  String get profileDetailReportPhoto;

  /// No description provided for @profileDetailReportPhotoChange.
  ///
  /// In ko, this message translates to:
  /// **'사진 변경'**
  String get profileDetailReportPhotoChange;

  /// No description provided for @profileDetailReportEnterContent.
  ///
  /// In ko, this message translates to:
  /// **'신고 내용을 입력해주세요.'**
  String get profileDetailReportEnterContent;

  /// No description provided for @profileDetailReportSubmit.
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get profileDetailReportSubmit;

  /// No description provided for @profileDetailEmailFailed.
  ///
  /// In ko, this message translates to:
  /// **'이메일 앱을 실행할 수 없습니다.'**
  String get profileDetailEmailFailed;

  /// No description provided for @profileDetailBlockTitle.
  ///
  /// In ko, this message translates to:
  /// **'사용자 차단'**
  String get profileDetailBlockTitle;

  /// No description provided for @profileDetailBlocked.
  ///
  /// In ko, this message translates to:
  /// **'사용자를 차단했습니다.'**
  String get profileDetailBlocked;

  /// No description provided for @profileDetailUnblocked.
  ///
  /// In ko, this message translates to:
  /// **'차단이 해제되었습니다.'**
  String get profileDetailUnblocked;

  /// No description provided for @profileDetailBlockedUser.
  ///
  /// In ko, this message translates to:
  /// **'차단된 사용자입니다.'**
  String get profileDetailBlockedUser;

  /// No description provided for @profileDetailBasicInfo.
  ///
  /// In ko, this message translates to:
  /// **'기본 정보'**
  String get profileDetailBasicInfo;

  /// No description provided for @profileDetailIntro.
  ///
  /// In ko, this message translates to:
  /// **'소개'**
  String get profileDetailIntro;

  /// No description provided for @profileDetailReasonBadPhoto.
  ///
  /// In ko, this message translates to:
  /// **'부적절한 사진'**
  String get profileDetailReasonBadPhoto;

  /// No description provided for @profileDetailReasonAbuse.
  ///
  /// In ko, this message translates to:
  /// **'욕설/비하 발언'**
  String get profileDetailReasonAbuse;

  /// No description provided for @profileDetailReasonSpam.
  ///
  /// In ko, this message translates to:
  /// **'스팸/홍보'**
  String get profileDetailReasonSpam;

  /// No description provided for @profileDetailReasonFraud.
  ///
  /// In ko, this message translates to:
  /// **'사칭/사기'**
  String get profileDetailReasonFraud;

  /// No description provided for @profileDetailReasonOther.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get profileDetailReasonOther;

  /// No description provided for @profileDetailExemptTitle.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외'**
  String get profileDetailExemptTitle;

  /// No description provided for @profileDetailExempt.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외'**
  String get profileDetailExempt;

  /// No description provided for @profileDetailExemptConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 사용자를 매칭에서 제외하시겠습니까?\n이 사용자가 속한 그룹과는 매칭되지 않습니다.\n\n5 Ting이 차감됩니다.'**
  String get profileDetailExemptConfirm;

  /// No description provided for @profileDetailExempted.
  ///
  /// In ko, this message translates to:
  /// **'매칭에서 제외되었습니다. (5 Ting 차감)'**
  String get profileDetailExempted;

  /// No description provided for @profileDetailExemptCost.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외에 5 Ting이 필요합니다.'**
  String get profileDetailExemptCost;

  /// No description provided for @profileDetailUnexempt.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외 해제'**
  String get profileDetailUnexempt;

  /// No description provided for @profileDetailUnexemptConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 사용자의 매칭 제외를 해제하시겠습니까?'**
  String get profileDetailUnexemptConfirm;

  /// No description provided for @profileDetailUnexempted.
  ///
  /// In ko, this message translates to:
  /// **'매칭 제외가 해제되었습니다.'**
  String get profileDetailUnexempted;

  /// No description provided for @profileEditNicknameChangeCost.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 변경에 10 Ting이 필요합니다.'**
  String get profileEditNicknameChangeCost;

  /// No description provided for @profileEditNicknameChangeConfirm.
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 변경하시겠습니까?\n10 Ting이 차감됩니다.'**
  String get profileEditNicknameChangeConfirm;

  /// No description provided for @profileEditInsufficientTings.
  ///
  /// In ko, this message translates to:
  /// **'Ting이 부족합니다. 스토어에서 충전해주세요.'**
  String get profileEditInsufficientTings;

  /// No description provided for @profileEditNicknameChangeSuccess.
  ///
  /// In ko, this message translates to:
  /// **'닉네임이 변경되었습니다. (10 Ting 차감)'**
  String get profileEditNicknameChangeSuccess;

  /// No description provided for @profileEditActivityAreaChangeCost.
  ///
  /// In ko, this message translates to:
  /// **'활동지역 변경에 5 Ting이 필요합니다.'**
  String get profileEditActivityAreaChangeCost;

  /// No description provided for @profileEditActivityAreaChangeConfirm.
  ///
  /// In ko, this message translates to:
  /// **'활동지역을 변경하시겠습니까?\n5 Ting이 차감됩니다.'**
  String get profileEditActivityAreaChangeConfirm;

  /// No description provided for @profileEditTotalCostConfirm.
  ///
  /// In ko, this message translates to:
  /// **'프로필 저장 시 {cost} Ting이 차감됩니다.\n계속하시겠습니까?'**
  String profileEditTotalCostConfirm(Object cost);

  /// No description provided for @profileEditTotalCostTitle.
  ///
  /// In ko, this message translates to:
  /// **'Ting 차감 안내'**
  String get profileEditTotalCostTitle;

  /// No description provided for @profileEditNicknameDuplicate.
  ///
  /// In ko, this message translates to:
  /// **'이미 사용 중인 닉네임입니다.'**
  String get profileEditNicknameDuplicate;

  /// No description provided for @profileEditNicknameAvailable.
  ///
  /// In ko, this message translates to:
  /// **'사용 가능한 닉네임입니다.'**
  String get profileEditNicknameAvailable;

  /// No description provided for @profileEditNicknameCheckError.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 확인 중 오류가 발생했습니다.'**
  String get profileEditNicknameCheckError;

  /// No description provided for @profileEditImageError.
  ///
  /// In ko, this message translates to:
  /// **'이미지 선택 중 오류가 발생했습니다.'**
  String get profileEditImageError;

  /// No description provided for @profileEditPermissionTitle.
  ///
  /// In ko, this message translates to:
  /// **'권한 설정 필요'**
  String get profileEditPermissionTitle;

  /// No description provided for @profileEditPermissionContent.
  ///
  /// In ko, this message translates to:
  /// **'프로필 사진을 등록하려면 갤러리 접근 권한이 필요합니다.\n설정에서 권한을 허용해주세요.'**
  String get profileEditPermissionContent;

  /// No description provided for @profileEditGoToSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정으로 이동'**
  String get profileEditGoToSettings;

  /// No description provided for @profileEditMainPhotoChanged.
  ///
  /// In ko, this message translates to:
  /// **'대표 프로필 사진이 변경되었습니다.'**
  String get profileEditMainPhotoChanged;

  /// No description provided for @profileEditNicknameEmpty.
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 입력해주세요.'**
  String get profileEditNicknameEmpty;

  /// No description provided for @profileEditNicknameTooShort.
  ///
  /// In ko, this message translates to:
  /// **'닉네임은 2자 이상이어야 합니다.'**
  String get profileEditNicknameTooShort;

  /// No description provided for @profileEditHeightEmpty.
  ///
  /// In ko, this message translates to:
  /// **'키를 입력해주세요.'**
  String get profileEditHeightEmpty;

  /// No description provided for @profileEditHeightRange.
  ///
  /// In ko, this message translates to:
  /// **'140-220cm 사이로 입력해주세요.'**
  String get profileEditHeightRange;

  /// No description provided for @profileEditHeightHint.
  ///
  /// In ko, this message translates to:
  /// **'키를 입력하세요'**
  String get profileEditHeightHint;

  /// No description provided for @profileEditIntroEmpty.
  ///
  /// In ko, this message translates to:
  /// **'소개글을 입력해주세요.'**
  String get profileEditIntroEmpty;

  /// No description provided for @profileEditIntroTooShort.
  ///
  /// In ko, this message translates to:
  /// **'5자 이상 작성해주세요.'**
  String get profileEditIntroTooShort;

  /// No description provided for @profileEditUploadFailed.
  ///
  /// In ko, this message translates to:
  /// **'이미지 업로드 실패'**
  String get profileEditUploadFailed;

  /// No description provided for @profileEditSuccess.
  ///
  /// In ko, this message translates to:
  /// **'프로필이 업데이트되었습니다.'**
  String get profileEditSuccess;

  /// No description provided for @profileEditFailed.
  ///
  /// In ko, this message translates to:
  /// **'프로필 업데이트 실패'**
  String get profileEditFailed;

  /// No description provided for @profileEditEmailLabel.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get profileEditEmailLabel;

  /// No description provided for @profileEditBirthDateLabel.
  ///
  /// In ko, this message translates to:
  /// **'생년월일'**
  String get profileEditBirthDateLabel;

  /// No description provided for @profileEditGenderLabel.
  ///
  /// In ko, this message translates to:
  /// **'성별'**
  String get profileEditGenderLabel;

  /// No description provided for @registerEmailInUse.
  ///
  /// In ko, this message translates to:
  /// **'이미 사용 중인 이메일입니다.'**
  String get registerEmailInUse;

  /// No description provided for @registerEmailAvailable.
  ///
  /// In ko, this message translates to:
  /// **'사용 가능한 이메일입니다.'**
  String get registerEmailAvailable;

  /// No description provided for @registerEmailError.
  ///
  /// In ko, this message translates to:
  /// **'이메일 확인 중 오류가 발생했습니다.'**
  String get registerEmailError;

  /// No description provided for @registerPhoneInUse.
  ///
  /// In ko, this message translates to:
  /// **'이미 사용 중인 전화번호입니다.'**
  String get registerPhoneInUse;

  /// No description provided for @registerPhoneAvailable.
  ///
  /// In ko, this message translates to:
  /// **'사용 가능한 전화번호입니다.'**
  String get registerPhoneAvailable;

  /// No description provided for @registerPhoneError.
  ///
  /// In ko, this message translates to:
  /// **'전화번호 확인 중 오류가 발생했습니다.'**
  String get registerPhoneError;

  /// No description provided for @registerPhoneValid.
  ///
  /// In ko, this message translates to:
  /// **'올바른 전화번호를 입력 후 중복 확인을 완료해주세요.'**
  String get registerPhoneValid;

  /// No description provided for @registerCodeSent.
  ///
  /// In ko, this message translates to:
  /// **'인증번호가 전송되었습니다.'**
  String get registerCodeSent;

  /// No description provided for @registerPhoneVerified.
  ///
  /// In ko, this message translates to:
  /// **'전화번호 인증이 완료되었습니다.'**
  String get registerPhoneVerified;

  /// No description provided for @registerPassword8Chars.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 8자 이상이어야 합니다.'**
  String get registerPassword8Chars;

  /// No description provided for @registerPasswordConfirmEmpty.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 다시 입력해주세요.'**
  String get registerPasswordConfirmEmpty;

  /// No description provided for @registerBirthDateEmpty.
  ///
  /// In ko, this message translates to:
  /// **'생년월일을 입력해주세요.'**
  String get registerBirthDateEmpty;

  /// No description provided for @registerBirthDate8Digits.
  ///
  /// In ko, this message translates to:
  /// **'8자리여야 합니다.'**
  String get registerBirthDate8Digits;

  /// No description provided for @registerYearInvalid.
  ///
  /// In ko, this message translates to:
  /// **'유효한 연도를 입력해주세요.'**
  String get registerYearInvalid;

  /// No description provided for @registerMonthInvalid.
  ///
  /// In ko, this message translates to:
  /// **'유효한 월을 입력해주세요.'**
  String get registerMonthInvalid;

  /// No description provided for @registerDayInvalid.
  ///
  /// In ko, this message translates to:
  /// **'유효한 일을 입력해주세요.'**
  String get registerDayInvalid;

  /// No description provided for @registerAgeRestriction.
  ///
  /// In ko, this message translates to:
  /// **'만 18세 미만은 이용할 수 없습니다.'**
  String get registerAgeRestriction;

  /// No description provided for @registerDateInvalid.
  ///
  /// In ko, this message translates to:
  /// **'유효한 날짜를 입력해주세요.'**
  String get registerDateInvalid;

  /// No description provided for @registerTermsServiceFull.
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용약관 (EULA)'**
  String get registerTermsServiceFull;

  /// No description provided for @registerTermsServiceContent.
  ///
  /// In ko, this message translates to:
  /// **'제1조 (목적)\n이 약관은 그룹팅 서비스 이용과 관련하여 회사와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n(자세한 내용은 앱 설정의 이용약관 전문을 참고하세요)'**
  String get registerTermsServiceContent;

  /// No description provided for @registerPrivacyPolicyFull.
  ///
  /// In ko, this message translates to:
  /// **'개인정보 처리방침'**
  String get registerPrivacyPolicyFull;

  /// No description provided for @registerPrivacyPolicyContent.
  ///
  /// In ko, this message translates to:
  /// **'1. 수집하는 개인정보\n- 이메일, 전화번호, 생년월일, 성별 등\n\n2. 이용목적\n- 본인 확인 및 서비스 제공\n\n(자세한 내용은 앱 설정을 참고하세요)'**
  String get registerPrivacyPolicyContent;

  /// No description provided for @registerPhoneVerifyNeeded.
  ///
  /// In ko, this message translates to:
  /// **'전화번호 인증을 완료해주세요.'**
  String get registerPhoneVerifyNeeded;

  /// No description provided for @registerSuccess.
  ///
  /// In ko, this message translates to:
  /// **'가입되었습니다! 우선 프로필을 완성해주세요.'**
  String get registerSuccess;

  /// No description provided for @registerTermsView.
  ///
  /// In ko, this message translates to:
  /// **'보기'**
  String get registerTermsView;

  /// No description provided for @timeJustNow.
  ///
  /// In ko, this message translates to:
  /// **'방금 전'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In ko, this message translates to:
  /// **'{count}분 전'**
  String timeMinutesAgo(Object count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In ko, this message translates to:
  /// **'{count}시간 전'**
  String timeHoursAgo(Object count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In ko, this message translates to:
  /// **'{count}일 전'**
  String timeDaysAgo(Object count);

  /// No description provided for @timeMonthDay.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일'**
  String timeMonthDay(Object day, Object month);

  /// No description provided for @helpFAQSection.
  ///
  /// In ko, this message translates to:
  /// **'자주 묻는 질문'**
  String get helpFAQSection;

  /// No description provided for @helpGuideSection.
  ///
  /// In ko, this message translates to:
  /// **'이용 가이드'**
  String get helpGuideSection;

  /// No description provided for @helpContactSection.
  ///
  /// In ko, this message translates to:
  /// **'문의하기'**
  String get helpContactSection;

  /// No description provided for @helpServiceSection.
  ///
  /// In ko, this message translates to:
  /// **'서비스 정보'**
  String get helpServiceSection;

  /// No description provided for @helpEmailContact.
  ///
  /// In ko, this message translates to:
  /// **'이메일 문의'**
  String get helpEmailContact;

  /// No description provided for @helpBugReportTitle.
  ///
  /// In ko, this message translates to:
  /// **'버그 신고'**
  String get helpBugReportTitle;

  /// No description provided for @helpBugReportSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 사용 중 문제가 발생했나요?'**
  String get helpBugReportSubtitle;

  /// No description provided for @helpBugReportHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 로그인 화면에서 버튼이 안 눌려요.'**
  String get helpBugReportHint;

  /// No description provided for @helpBugReportContent.
  ///
  /// In ko, this message translates to:
  /// **'버그 내용을 상세히 적어주세요.'**
  String get helpBugReportContent;

  /// No description provided for @helpPhotoAttach.
  ///
  /// In ko, this message translates to:
  /// **'사진 첨부'**
  String get helpPhotoAttach;

  /// No description provided for @helpPhotoSelected.
  ///
  /// In ko, this message translates to:
  /// **'사진 선택됨'**
  String get helpPhotoSelected;

  /// No description provided for @helpSend.
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get helpSend;

  /// No description provided for @helpEmailFailed.
  ///
  /// In ko, this message translates to:
  /// **'이메일 앱을 열 수 없습니다. 기본 메일 앱을 확인해주세요.'**
  String get helpEmailFailed;

  /// No description provided for @helpCustomerService.
  ///
  /// In ko, this message translates to:
  /// **'고객센터 운영시간'**
  String get helpCustomerService;

  /// No description provided for @helpOperatingHours.
  ///
  /// In ko, this message translates to:
  /// **'평일: 09:00 - 18:00\n주말 및 공휴일: 휴무'**
  String get helpOperatingHours;

  /// No description provided for @helpResponseTime.
  ///
  /// In ko, this message translates to:
  /// **'응답시간'**
  String get helpResponseTime;

  /// No description provided for @helpResponseEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일: 24시간 이내'**
  String get helpResponseEmail;

  /// No description provided for @helpFAQ1Q.
  ///
  /// In ko, this message translates to:
  /// **'그룹팅은 어떻게 시작하나요?'**
  String get helpFAQ1Q;

  /// No description provided for @helpFAQ1A.
  ///
  /// In ko, this message translates to:
  /// **'1. 프로필을 완성하세요\n2. 친구들을 초대하거나 혼자 매칭을 시작하세요\n3. 매칭이 완료되면 채팅을 통해 대화를 나누세요\n4. 실제 만남을 계획해보세요'**
  String get helpFAQ1A;

  /// No description provided for @helpFAQ2Q.
  ///
  /// In ko, this message translates to:
  /// **'1:1 매칭과 그룹 매칭의 차이는 무엇인가요?'**
  String get helpFAQ2Q;

  /// No description provided for @helpFAQ2A.
  ///
  /// In ko, this message translates to:
  /// **'1:1 매칭: 혼자서 다른 1명과 매칭되는 방식입니다.\n그룹 매칭: 2-5명의 친구들과 함께 같은 인원 수의 다른 그룹과 매칭되는 방식입니다.'**
  String get helpFAQ2A;

  /// No description provided for @helpFAQ3Q.
  ///
  /// In ko, this message translates to:
  /// **'매칭은 어떤 기준으로 이루어지나요?'**
  String get helpFAQ3Q;

  /// No description provided for @helpFAQ3A.
  ///
  /// In ko, this message translates to:
  /// **'매칭은 다음 기준으로 이루어집니다:\n- 활동지역이 같거나 인접한 지역\n- 그룹 인원 수가 같음\n- 매칭 대기 중인 상태'**
  String get helpFAQ3A;

  /// No description provided for @helpFAQ4Q.
  ///
  /// In ko, this message translates to:
  /// **'프로필 사진은 몇 장까지 등록할 수 있나요?'**
  String get helpFAQ4Q;

  /// No description provided for @helpFAQ4A.
  ///
  /// In ko, this message translates to:
  /// **'최대 6장까지 등록할 수 있습니다.\n1번째 사진이 메인 프로필 사진으로 사용되며, 나머지는 추가 사진으로 표시됩니다.'**
  String get helpFAQ4A;

  /// No description provided for @helpFAQ5Q.
  ///
  /// In ko, this message translates to:
  /// **'그룹에서 나가고 싶어요.'**
  String get helpFAQ5Q;

  /// No description provided for @helpFAQ5A.
  ///
  /// In ko, this message translates to:
  /// **'홈 화면 우상단 메뉴에서 \"그룹 나가기\"를 선택하세요.\n그룹을 나간 후에는 다시 초대를 받거나 새 그룹을 만들어야 합니다.'**
  String get helpFAQ5A;

  /// No description provided for @helpFAQ6Q.
  ///
  /// In ko, this message translates to:
  /// **'매칭이 안 되는 이유가 뭐예요?'**
  String get helpFAQ6Q;

  /// No description provided for @helpFAQ6A.
  ///
  /// In ko, this message translates to:
  /// **'다음 경우에 매칭이 어려울 수 있습니다:\n- 같은 활동지역에 매칭 대기 중인 그룹이 없는 경우\n- 같은 인원 수의 그룹이 없는 경우\n- 매칭 시간대에 활성 사용자가 적은 경우'**
  String get helpFAQ6A;

  /// No description provided for @helpGuideSignup.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get helpGuideSignup;

  /// No description provided for @helpGuideSignupDesc.
  ///
  /// In ko, this message translates to:
  /// **'기본 정보 입력 후 프로필을 완성하세요'**
  String get helpGuideSignupDesc;

  /// No description provided for @helpGuideSignupContent.
  ///
  /// In ko, this message translates to:
  /// **'1. 아이디, 비밀번호, 전화번호, 생년월일, 성별을 입력하세요\n2. 프로필 사진을 업로드하세요 (최대 6장)\n3. 키, 닉네임, 활동지역, 소개글을 작성하세요\n4. 프로필 완성 후 매칭을 시작할 수 있습니다'**
  String get helpGuideSignupContent;

  /// No description provided for @helpGuideGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹 만들기'**
  String get helpGuideGroup;

  /// No description provided for @helpGuideGroupDesc.
  ///
  /// In ko, this message translates to:
  /// **'친구들을 초대해서 그룹을 구성하세요'**
  String get helpGuideGroupDesc;

  /// No description provided for @helpGuideGroupContent.
  ///
  /// In ko, this message translates to:
  /// **'1. 홈 화면에서 \"그룹 만들기\" 버튼을 누르세요\n2. \"친구 초대하기\"를 통해 친구들을 초대하세요\n3. 친구들이 초대를 수락하면 그룹이 구성됩니다\n4. 최대 5명까지 그룹을 구성할 수 있습니다'**
  String get helpGuideGroupContent;

  /// No description provided for @helpGuideFilter.
  ///
  /// In ko, this message translates to:
  /// **'적용하기'**
  String get helpGuideFilter;

  /// No description provided for @helpGuideFilterDesc.
  ///
  /// In ko, this message translates to:
  /// **'내가 원하는 그룹과 매칭되세요'**
  String get helpGuideFilterDesc;

  /// No description provided for @helpGuideFilterContent.
  ///
  /// In ko, this message translates to:
  /// **'1. 그룹을 만든 후, 상단 우측 필터 버튼을 누르세요\n2. 필터를 조절 하세요\n3. 적용하기를 누르세요'**
  String get helpGuideFilterContent;

  /// No description provided for @helpGuideMatch.
  ///
  /// In ko, this message translates to:
  /// **'매칭하기'**
  String get helpGuideMatch;

  /// No description provided for @helpGuideMatchDesc.
  ///
  /// In ko, this message translates to:
  /// **'1:1 또는 그룹 매칭을 시작하세요'**
  String get helpGuideMatchDesc;

  /// No description provided for @helpGuideMatchContent.
  ///
  /// In ko, this message translates to:
  /// **'1. 그룹이 구성되면 \"매칭 시작\" 버튼이 활성화됩니다\n2. 혼자인 경우 \"1:1 매칭 시작\"을 선택하세요\n3. 그룹인 경우 \"그룹 매칭 시작\"을 선택하세요\n4. 매칭이 완료되면 알림이 오고 채팅을 시작할 수 있습니다'**
  String get helpGuideMatchContent;

  /// No description provided for @helpGuideChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅하기'**
  String get helpGuideChat;

  /// No description provided for @helpGuideChatDesc.
  ///
  /// In ko, this message translates to:
  /// **'매칭된 상대방과 채팅을 나누세요'**
  String get helpGuideChatDesc;

  /// No description provided for @helpGuideChatContent.
  ///
  /// In ko, this message translates to:
  /// **'1. 매칭이 완료되면 \"채팅하기\" 버튼이 나타납니다\n2. 채팅방에서 상대방과 대화를 나누세요\n3. 서로를 알아가는 시간을 가져보세요\n4. 실제 만남을 계획해보세요'**
  String get helpGuideChatContent;

  /// No description provided for @helpGuideSafety.
  ///
  /// In ko, this message translates to:
  /// **'안전하게 이용하기'**
  String get helpGuideSafety;

  /// No description provided for @helpGuideSafetyDesc.
  ///
  /// In ko, this message translates to:
  /// **'안전한 만남을 위한 주의사항을 확인하세요'**
  String get helpGuideSafetyDesc;

  /// No description provided for @helpGuideSafetyContent.
  ///
  /// In ko, this message translates to:
  /// **'🔒 개인정보 보호\n- 개인정보(주소, 직장 등)는 충분히 신뢰할 때까지 공개하지 마세요\n\n👥 첫 만남\n- 첫 만남은 공공장소에서 진행하세요\n- 친구들과 함께 만나는 것을 권장합니다\n\n🚨 신고하기\n- 부적절한 행동을 하는 사용자는 즉시 신고해주세요\n- 불쾌한 메세지나 사진을 받으면 스크린샷을 남기고 신고하세요'**
  String get helpGuideSafetyContent;

  /// No description provided for @myPageEditProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필 편집'**
  String get myPageEditProfile;

  /// No description provided for @registerPhotos.
  ///
  /// In ko, this message translates to:
  /// **'프로필 사진'**
  String get registerPhotos;

  /// No description provided for @registerNickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get registerNickname;

  /// No description provided for @registerNicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 입력하세요 (2~10자)'**
  String get registerNicknameHint;

  /// No description provided for @registerHeight.
  ///
  /// In ko, this message translates to:
  /// **'키 (cm)'**
  String get registerHeight;

  /// No description provided for @registerIntroHint.
  ///
  /// In ko, this message translates to:
  /// **'나를 표현하는 멋진 소개글을 작성해보세요.\n(취미, 관심사, 성격 등)'**
  String get registerIntroHint;

  /// No description provided for @registerPhotosLongPress.
  ///
  /// In ko, this message translates to:
  /// **'대표 사진은 길게 눌러 설정하세요'**
  String get registerPhotosLongPress;

  /// No description provided for @registerPhotosAdd.
  ///
  /// In ko, this message translates to:
  /// **'사진 추가'**
  String get registerPhotosAdd;

  /// No description provided for @registerPhotosMain.
  ///
  /// In ko, this message translates to:
  /// **'대표'**
  String get registerPhotosMain;

  /// No description provided for @registerActivityArea.
  ///
  /// In ko, this message translates to:
  /// **'활동지역'**
  String get registerActivityArea;

  /// No description provided for @registerActivityAreaHint.
  ///
  /// In ko, this message translates to:
  /// **'지도를 눌러 위치를 선택하세요'**
  String get registerActivityAreaHint;

  /// No description provided for @registerPhotosMin.
  ///
  /// In ko, this message translates to:
  /// **'사진을 최소 1장 등록해주세요.'**
  String get registerPhotosMin;

  /// No description provided for @settingsBlockConfirm.
  ///
  /// In ko, this message translates to:
  /// **'차단하면 서로의 프로필을 볼 수 없으며,\n채팅 및 초대를 받을 수 없습니다.\n정말 차단하시겠습니까?'**
  String get settingsBlockConfirm;

  /// No description provided for @settingsReport.
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get settingsReport;

  /// No description provided for @settingsHelp.
  ///
  /// In ko, this message translates to:
  /// **'도움말'**
  String get settingsHelp;

  /// No description provided for @homeTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹팅'**
  String get homeTitle;

  /// No description provided for @homeNavHome.
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get homeNavHome;

  /// No description provided for @homeNavInvitations.
  ///
  /// In ko, this message translates to:
  /// **'초대'**
  String get homeNavInvitations;

  /// No description provided for @homeNavChat.
  ///
  /// In ko, this message translates to:
  /// **'1:1 채팅'**
  String get homeNavChat;

  /// No description provided for @homeNavMyPage.
  ///
  /// In ko, this message translates to:
  /// **'마이페이지'**
  String get homeNavMyPage;

  /// No description provided for @homeNavMore.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get homeNavMore;

  /// No description provided for @homeMenuReceivedInvites.
  ///
  /// In ko, this message translates to:
  /// **'받은 초대'**
  String get homeMenuReceivedInvites;

  /// No description provided for @homeMenuMyPage.
  ///
  /// In ko, this message translates to:
  /// **'마이페이지'**
  String get homeMenuMyPage;

  /// No description provided for @homeLeaveGroupTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹 나가기'**
  String get homeLeaveGroupTitle;

  /// No description provided for @homeLeaveGroupConfirm.
  ///
  /// In ko, this message translates to:
  /// **'정말로 그룹을 나가시겠습니까?'**
  String get homeLeaveGroupConfirm;

  /// No description provided for @homeLeaveGroupBtn.
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get homeLeaveGroupBtn;

  /// No description provided for @homeLeaveGroupSuccess.
  ///
  /// In ko, this message translates to:
  /// **'그룹에서 나왔습니다.'**
  String get homeLeaveGroupSuccess;

  /// No description provided for @homeLogoutTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get homeLogoutTitle;

  /// No description provided for @homeLogoutConfirm.
  ///
  /// In ko, this message translates to:
  /// **'정말로 로그아웃 하시겠습니까?'**
  String get homeLogoutConfirm;

  /// No description provided for @homeMatchSuccess.
  ///
  /// In ko, this message translates to:
  /// **'매칭 성공! 🎉'**
  String get homeMatchSuccess;

  /// No description provided for @homeMatchSuccessDesc.
  ///
  /// In ko, this message translates to:
  /// **'매칭되었습니다!\n채팅방에서 인사해보세요 👋'**
  String get homeMatchSuccessDesc;

  /// No description provided for @homeLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get homeLater;

  /// No description provided for @homeGoToChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅방으로 이동'**
  String get homeGoToChat;

  /// No description provided for @homeFilterMale.
  ///
  /// In ko, this message translates to:
  /// **'남자'**
  String get homeFilterMale;

  /// No description provided for @homeFilterFemale.
  ///
  /// In ko, this message translates to:
  /// **'여자'**
  String get homeFilterFemale;

  /// No description provided for @homeFilterMixed.
  ///
  /// In ko, this message translates to:
  /// **'혼성'**
  String get homeFilterMixed;

  /// No description provided for @homeFilterAny.
  ///
  /// In ko, this message translates to:
  /// **'상관없음'**
  String get homeFilterAny;

  /// No description provided for @homeFilterDistanceValue.
  ///
  /// In ko, this message translates to:
  /// **'{km}km 이내'**
  String homeFilterDistanceValue(Object km);

  /// No description provided for @homeProfileCardHidden.
  ///
  /// In ko, this message translates to:
  /// **'프로필 완성하기 알림을 숨겼습니다. 마이페이지에서 언제든 프로필을 완성할 수 있습니다.'**
  String get homeProfileCardHidden;

  /// No description provided for @homeProfileSignup.
  ///
  /// In ko, this message translates to:
  /// **'회원가입하기'**
  String get homeProfileSignup;

  /// No description provided for @homeProfileBasicInfo.
  ///
  /// In ko, this message translates to:
  /// **'기본 정보 입력하기'**
  String get homeProfileBasicInfo;

  /// No description provided for @homeProfileComplete.
  ///
  /// In ko, this message translates to:
  /// **'프로필 완성하기'**
  String get homeProfileComplete;

  /// No description provided for @homeProfileSignupDesc.
  ///
  /// In ko, this message translates to:
  /// **'그룹팅 서비스를 이용하시려면\n먼저 회원가입을 완료해주세요!'**
  String get homeProfileSignupDesc;

  /// No description provided for @homeProfileBasicInfoDesc.
  ///
  /// In ko, this message translates to:
  /// **'전화번호, 생년월일, 성별 정보가 필요해요!'**
  String get homeProfileBasicInfoDesc;

  /// No description provided for @homeProfileCompleteDesc.
  ///
  /// In ko, this message translates to:
  /// **'닉네임, 키, 활동지역 등을 입력해주세요!'**
  String get homeProfileCompleteDesc;

  /// No description provided for @homeProfileBasicInfoLong.
  ///
  /// In ko, this message translates to:
  /// **'회원가입 중 누락된 필수 정보가 있어요.\n기본 정보를 입력하고 프로필을 완성해주세요!'**
  String get homeProfileBasicInfoLong;

  /// No description provided for @homeProfileCompleteLong.
  ///
  /// In ko, this message translates to:
  /// **'닉네임, 키, 소개글, 활동지역을 추가하면\n그룹 생성과 매칭 기능을 사용할 수 있어요!'**
  String get homeProfileCompleteLong;

  /// No description provided for @homeProfileNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 완성하기'**
  String get homeProfileNow;

  /// No description provided for @homeLoadingGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹 정보 로딩 중...'**
  String get homeLoadingGroup;

  /// No description provided for @homeLoadingWait.
  ///
  /// In ko, this message translates to:
  /// **'잠시만 기다려주세요.'**
  String get homeLoadingWait;

  /// No description provided for @homeErrorNetwork.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 연결 오류'**
  String get homeErrorNetwork;

  /// No description provided for @homeErrorLoad.
  ///
  /// In ko, this message translates to:
  /// **'데이터 로드 실패'**
  String get homeErrorLoad;

  /// No description provided for @homeErrorNetworkDesc.
  ///
  /// In ko, this message translates to:
  /// **'인터넷 연결을 확인하고 다시 시도해주세요.'**
  String get homeErrorNetworkDesc;

  /// No description provided for @homeErrorUnknown.
  ///
  /// In ko, this message translates to:
  /// **'알 수 없는 오류가 발생했습니다.'**
  String get homeErrorUnknown;

  /// No description provided for @homeErrorRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get homeErrorRetry;

  /// No description provided for @homeErrorCheckConnection.
  ///
  /// In ko, this message translates to:
  /// **'연결 확인'**
  String get homeErrorCheckConnection;

  /// No description provided for @homeErrorWifiCheck.
  ///
  /// In ko, this message translates to:
  /// **'Wi-Fi나 모바일 데이터 연결을 확인해주세요.'**
  String get homeErrorWifiCheck;

  /// No description provided for @homeNoGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹이 없습니다'**
  String get homeNoGroup;

  /// No description provided for @homeCreateGroup.
  ///
  /// In ko, this message translates to:
  /// **'새 그룹 만들기'**
  String get homeCreateGroup;

  /// No description provided for @homeProfileRequiredTitle.
  ///
  /// In ko, this message translates to:
  /// **'프로필 완성 필요'**
  String get homeProfileRequiredTitle;

  /// No description provided for @homeProfileRequiredDesc.
  ///
  /// In ko, this message translates to:
  /// **'프로필을 완성해야 서비스 이용이 가능합니다.'**
  String get homeProfileRequiredDesc;

  /// No description provided for @homeProfileRequiredBtn.
  ///
  /// In ko, this message translates to:
  /// **'프로필 완성하기'**
  String get homeProfileRequiredBtn;

  /// No description provided for @homeMatchedStatus.
  ///
  /// In ko, this message translates to:
  /// **'매칭 성공! 🎉'**
  String get homeMatchedStatus;

  /// No description provided for @homeMatchingStatus.
  ///
  /// In ko, this message translates to:
  /// **'매칭 진행중...'**
  String get homeMatchingStatus;

  /// No description provided for @homeWaitingStatus.
  ///
  /// In ko, this message translates to:
  /// **'매칭 대기중'**
  String get homeWaitingStatus;

  /// No description provided for @homeMatchedDesc.
  ///
  /// In ko, this message translates to:
  /// **'새로운 인연과 대화를 시작해보세요'**
  String get homeMatchedDesc;

  /// No description provided for @homeMatchingDesc.
  ///
  /// In ko, this message translates to:
  /// **'매칭 상대를 찾고 있어요...'**
  String get homeMatchingDesc;

  /// No description provided for @homeWaitingDesc.
  ///
  /// In ko, this message translates to:
  /// **'친구들과 대화 해보세요'**
  String get homeWaitingDesc;

  /// No description provided for @homeNewMessage.
  ///
  /// In ko, this message translates to:
  /// **'새로운 메시지 💬'**
  String get homeNewMessage;

  /// No description provided for @homeCurrentMembers.
  ///
  /// In ko, this message translates to:
  /// **'현재 그룹 멤버'**
  String get homeCurrentMembers;

  /// No description provided for @homeMemberCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}명'**
  String homeMemberCount(Object count);

  /// No description provided for @homeInvite.
  ///
  /// In ko, this message translates to:
  /// **'초대하기'**
  String get homeInvite;

  /// No description provided for @homeMatchFilter.
  ///
  /// In ko, this message translates to:
  /// **'매칭 필터'**
  String get homeMatchFilter;

  /// No description provided for @homeErrorCheckConnectionDesc.
  ///
  /// In ko, this message translates to:
  /// **'Wi-Fi나 모바일 데이터 연결을 확인해주세요.'**
  String get homeErrorCheckConnectionDesc;

  /// No description provided for @storeTitle.
  ///
  /// In ko, this message translates to:
  /// **'스토어'**
  String get storeTitle;

  /// No description provided for @storeRestorePurchases.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get storeRestorePurchases;

  /// No description provided for @storeUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'스토어를 이용할 수 없습니다'**
  String get storeUnavailable;

  /// No description provided for @storeUnavailableDesc.
  ///
  /// In ko, this message translates to:
  /// **'현재 스토어를 사용할 수 없습니다.\n나중에 다시 시도해주세요.'**
  String get storeUnavailableDesc;

  /// No description provided for @storeError.
  ///
  /// In ko, this message translates to:
  /// **'오류가 발생했습니다'**
  String get storeError;

  /// No description provided for @storePremiumTitle.
  ///
  /// In ko, this message translates to:
  /// **'그룹팅 프리미엄'**
  String get storePremiumTitle;

  /// No description provided for @storePremiumSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'더 많은 기능을 경험하세요'**
  String get storePremiumSubtitle;

  /// No description provided for @storeBenefit1.
  ///
  /// In ko, this message translates to:
  /// **'무제한 프로필 확인'**
  String get storeBenefit1;

  /// No description provided for @storeBenefit2.
  ///
  /// In ko, this message translates to:
  /// **'우선 매칭 기능'**
  String get storeBenefit2;

  /// No description provided for @storeBenefit3.
  ///
  /// In ko, this message translates to:
  /// **'특별 이모티콘 사용'**
  String get storeBenefit3;

  /// No description provided for @storePremiumSection.
  ///
  /// In ko, this message translates to:
  /// **'프리미엄 구독'**
  String get storePremiumSection;

  /// No description provided for @storeCoinsSection.
  ///
  /// In ko, this message translates to:
  /// **'코인 패키지'**
  String get storeCoinsSection;

  /// No description provided for @storeMonthlyPlan.
  ///
  /// In ko, this message translates to:
  /// **'월간 구독'**
  String get storeMonthlyPlan;

  /// No description provided for @storeYearlyPlan.
  ///
  /// In ko, this message translates to:
  /// **'연간 구독'**
  String get storeYearlyPlan;

  /// No description provided for @storePopular.
  ///
  /// In ko, this message translates to:
  /// **'인기'**
  String get storePopular;

  /// No description provided for @storePurchased.
  ///
  /// In ko, this message translates to:
  /// **'구독 중'**
  String get storePurchased;

  /// No description provided for @storeBuyButton.
  ///
  /// In ko, this message translates to:
  /// **'구매'**
  String get storeBuyButton;

  /// No description provided for @storeCoins.
  ///
  /// In ko, this message translates to:
  /// **'코인'**
  String get storeCoins;

  /// No description provided for @storeNoProducts.
  ///
  /// In ko, this message translates to:
  /// **'상품이 없습니다'**
  String get storeNoProducts;

  /// No description provided for @storeNoProductsDesc.
  ///
  /// In ko, this message translates to:
  /// **'현재 이용 가능한 상품이 없습니다.\n나중에 다시 확인해주세요.'**
  String get storeNoProductsDesc;

  /// No description provided for @storeRechargeTitle.
  ///
  /// In ko, this message translates to:
  /// **'Ting 충전하기'**
  String get storeRechargeTitle;

  /// No description provided for @storeRechargeDesc.
  ///
  /// In ko, this message translates to:
  /// **'매칭에 필요한 Ting을 충전하세요'**
  String get storeRechargeDesc;

  /// No description provided for @storeBonusPromo.
  ///
  /// In ko, this message translates to:
  /// **'많이 구매할수록 더 많은 보너스!'**
  String get storeBonusPromo;

  /// No description provided for @storeTingPackages.
  ///
  /// In ko, this message translates to:
  /// **'Ting 패키지'**
  String get storeTingPackages;

  /// No description provided for @storeBonus.
  ///
  /// In ko, this message translates to:
  /// **'+{amount} 보너스'**
  String storeBonus(Object amount);

  /// No description provided for @storeSecurePayment.
  ///
  /// In ko, this message translates to:
  /// **'안전한 결제'**
  String get storeSecurePayment;

  /// No description provided for @storeSecurePaymentDesc.
  ///
  /// In ko, this message translates to:
  /// **'Google Play / App Store를 통한 안전한 결제'**
  String get storeSecurePaymentDesc;

  /// No description provided for @storePurchaseStart.
  ///
  /// In ko, this message translates to:
  /// **'{amount} Ting 구매를 시작합니다...'**
  String storePurchaseStart(Object amount);

  /// No description provided for @storePurchase.
  ///
  /// In ko, this message translates to:
  /// **'구매하기'**
  String get storePurchase;

  /// No description provided for @storePurchaseSuccess.
  ///
  /// In ko, this message translates to:
  /// **'{amount} Ting이 충전되었습니다! 🎉'**
  String storePurchaseSuccess(Object amount);

  /// No description provided for @storePurchaseFailed.
  ///
  /// In ko, this message translates to:
  /// **'구매에 실패했습니다. 다시 시도해주세요.'**
  String get storePurchaseFailed;

  /// No description provided for @ratingDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님의 매력점수 평가하기'**
  String ratingDialogTitle(Object nickname);

  /// No description provided for @ratingDialogPrompt.
  ///
  /// In ko, this message translates to:
  /// **'별을 눌러서 평가해주세요:'**
  String get ratingDialogPrompt;

  /// No description provided for @ratingDialogSubmit.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get ratingDialogSubmit;

  /// No description provided for @ratingSaved.
  ///
  /// In ko, this message translates to:
  /// **'매력점수가 저장되었습니다!'**
  String get ratingSaved;

  /// No description provided for @ratingAlreadyRated.
  ///
  /// In ko, this message translates to:
  /// **'이미 이 사용자를 평가하셨습니다'**
  String get ratingAlreadyRated;

  /// No description provided for @opentingTitle.
  ///
  /// In ko, this message translates to:
  /// **'오픈팅'**
  String get opentingTitle;

  /// No description provided for @opentingTabList.
  ///
  /// In ko, this message translates to:
  /// **'오픈채팅'**
  String get opentingTabList;

  /// No description provided for @opentingTabStory.
  ///
  /// In ko, this message translates to:
  /// **'스토리'**
  String get opentingTabStory;

  /// No description provided for @opentingLeaveChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 나가기'**
  String get opentingLeaveChat;

  /// No description provided for @opentingNoMembers.
  ///
  /// In ko, this message translates to:
  /// **'멤버가 없습니다'**
  String get opentingNoMembers;

  /// No description provided for @opentingWelcome.
  ///
  /// In ko, this message translates to:
  /// **'채팅방에 오신 것을 환영합니다!'**
  String get opentingWelcome;

  /// No description provided for @opentingStartConversation.
  ///
  /// In ko, this message translates to:
  /// **'다른 참가자들과 대화를 시작해보세요'**
  String get opentingStartConversation;

  /// No description provided for @storyCreateTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 게시물'**
  String get storyCreateTitle;

  /// No description provided for @storyCreateContentHint.
  ///
  /// In ko, this message translates to:
  /// **'무슨 생각을 하고 계신가요?'**
  String get storyCreateContentHint;

  /// No description provided for @storyCreatePostButton.
  ///
  /// In ko, this message translates to:
  /// **'게시'**
  String get storyCreatePostButton;

  /// No description provided for @storyEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 스토리가 없습니다. 첫 번째로 스토리를 올려보세요!'**
  String get storyEmpty;

  /// No description provided for @storyDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 게시물을 정말 삭제하시겠습니까?'**
  String get storyDeleteConfirm;

  /// No description provided for @storyImageSelectError.
  ///
  /// In ko, this message translates to:
  /// **'이미지 선택에 실패했습니다'**
  String get storyImageSelectError;

  /// No description provided for @opentingCreateRoomTitle.
  ///
  /// In ko, this message translates to:
  /// **'오픈채팅 방 만들기'**
  String get opentingCreateRoomTitle;

  /// No description provided for @opentingRoomTitle.
  ///
  /// In ko, this message translates to:
  /// **'방 제목'**
  String get opentingRoomTitle;

  /// No description provided for @opentingRoomTitleHint.
  ///
  /// In ko, this message translates to:
  /// **'방 제목을 입력하세요'**
  String get opentingRoomTitleHint;

  /// No description provided for @opentingMaxParticipants.
  ///
  /// In ko, this message translates to:
  /// **'최대 인원'**
  String get opentingMaxParticipants;

  /// No description provided for @opentingParticipantsCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}명'**
  String opentingParticipantsCount(Object count);

  /// No description provided for @opentingEnterRoomTitle.
  ///
  /// In ko, this message translates to:
  /// **'방 제목을 입력해주세요'**
  String get opentingEnterRoomTitle;

  /// No description provided for @opentingCreateSuccess.
  ///
  /// In ko, this message translates to:
  /// **'오픈채팅 방이 생성되었습니다!'**
  String get opentingCreateSuccess;

  /// No description provided for @opentingCreateFailed.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 생성에 실패했습니다'**
  String get opentingCreateFailed;

  /// No description provided for @opentingRoomFull.
  ///
  /// In ko, this message translates to:
  /// **'채팅방이 가득 찼습니다'**
  String get opentingRoomFull;

  /// No description provided for @opentingJoinSuccess.
  ///
  /// In ko, this message translates to:
  /// **'채팅방에 참여했습니다!'**
  String get opentingJoinSuccess;

  /// No description provided for @opentingJoinFailed.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 참여에 실패했습니다'**
  String get opentingJoinFailed;

  /// No description provided for @opentingDistanceFilter.
  ///
  /// In ko, this message translates to:
  /// **'필터 설정'**
  String get opentingDistanceFilter;

  /// No description provided for @opentingMaxDistance.
  ///
  /// In ko, this message translates to:
  /// **'최대 거리'**
  String get opentingMaxDistance;

  /// No description provided for @opentingLoadError.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 로딩 중 오류'**
  String get opentingLoadError;

  /// No description provided for @opentingNoRoomsFound.
  ///
  /// In ko, this message translates to:
  /// **'채팅방을 찾을 수 없습니다'**
  String get opentingNoRoomsFound;

  /// No description provided for @opentingAdjustFilter.
  ///
  /// In ko, this message translates to:
  /// **'필터를 조정해보세요'**
  String get opentingAdjustFilter;

  /// No description provided for @opentingJoined.
  ///
  /// In ko, this message translates to:
  /// **'참여 완료'**
  String get opentingJoined;

  /// No description provided for @opentingJoinRoom.
  ///
  /// In ko, this message translates to:
  /// **'참여하기'**
  String get opentingJoinRoom;

  /// No description provided for @opentingCreateRoom.
  ///
  /// In ko, this message translates to:
  /// **'방 만들기'**
  String get opentingCreateRoom;

  /// No description provided for @opentingNoRooms.
  ///
  /// In ko, this message translates to:
  /// **'오픈채팅 방이 없습니다'**
  String get opentingNoRooms;

  /// No description provided for @opentingBeFirst.
  ///
  /// In ko, this message translates to:
  /// **'첫 번째로 오픈채팅 방을 만들어보세요!'**
  String get opentingBeFirst;

  /// No description provided for @opentingHideFullRooms.
  ///
  /// In ko, this message translates to:
  /// **'만석인 방 숨기기'**
  String get opentingHideFullRooms;

  /// No description provided for @opentingUnknown.
  ///
  /// In ko, this message translates to:
  /// **'알 수 없음'**
  String get opentingUnknown;

  /// No description provided for @errorUserNotFound.
  ///
  /// In ko, this message translates to:
  /// **'사용자를 찾을 수 없습니다.'**
  String get errorUserNotFound;

  /// No description provided for @errorLoadProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필을 불러오는데 실패했습니다.'**
  String get errorLoadProfile;

  /// No description provided for @userActionRemove.
  ///
  /// In ko, this message translates to:
  /// **'강퇴하기'**
  String get userActionRemove;

  /// No description provided for @userActionRemoveConfirm.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님을 강퇴 하시겠습니까?'**
  String userActionRemoveConfirm(Object nickname);

  /// No description provided for @userActionRemoveSuccess.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님을 강퇴했습니다.'**
  String userActionRemoveSuccess(Object nickname);

  /// No description provided for @userActionBan.
  ///
  /// In ko, this message translates to:
  /// **'강퇴'**
  String get userActionBan;

  /// No description provided for @commonErrorWithValue.
  ///
  /// In ko, this message translates to:
  /// **'오류가 발생했습니다: {error}'**
  String commonErrorWithValue(Object error);

  /// No description provided for @costFiveTing.
  ///
  /// In ko, this message translates to:
  /// **'5 Ting'**
  String get costFiveTing;

  /// No description provided for @opentingBannedMessage.
  ///
  /// In ko, this message translates to:
  /// **'강퇴 당하셨습니다.'**
  String get opentingBannedMessage;

  /// No description provided for @opentingSendMessageFailed.
  ///
  /// In ko, this message translates to:
  /// **'메시지 전송 실패'**
  String get opentingSendMessageFailed;

  /// No description provided for @opentingLeaveSuccess.
  ///
  /// In ko, this message translates to:
  /// **'채팅방에서 나갔습니다!'**
  String get opentingLeaveSuccess;

  /// No description provided for @opentingLeaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 나가기 실패'**
  String get opentingLeaveFailed;

  /// No description provided for @opentingCannotJoinBanned.
  ///
  /// In ko, this message translates to:
  /// **'참여할 수 없습니다.'**
  String get opentingCannotJoinBanned;

  /// No description provided for @privateChatTitle.
  ///
  /// In ko, this message translates to:
  /// **'1:1 채팅'**
  String get privateChatTitle;

  /// No description provided for @privateChatListError.
  ///
  /// In ko, this message translates to:
  /// **'오류가 발생했습니다'**
  String get privateChatListError;

  /// No description provided for @privateChatListEmpty.
  ///
  /// In ko, this message translates to:
  /// **'채팅이 없습니다'**
  String get privateChatListEmpty;

  /// No description provided for @privateChatListEmptyDesc.
  ///
  /// In ko, this message translates to:
  /// **'누군가를 채팅에 초대해서\n대화를 시작해보세요!'**
  String get privateChatListEmptyDesc;

  /// No description provided for @privateChatListYesterday.
  ///
  /// In ko, this message translates to:
  /// **'어제'**
  String get privateChatListYesterday;

  /// No description provided for @privateChatStarted.
  ///
  /// In ko, this message translates to:
  /// **'새로운 채팅이 시작되었습니다!'**
  String get privateChatStarted;

  /// No description provided for @systemUserLeft.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님이 나갔습니다.'**
  String systemUserLeft(Object nickname);

  /// No description provided for @privateChatLeaveChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅 나가기'**
  String get privateChatLeaveChat;

  /// No description provided for @privateChatLeaveConfirm.
  ///
  /// In ko, this message translates to:
  /// **'정말로 이 채팅방을 나가시겠습니까?'**
  String get privateChatLeaveConfirm;

  /// No description provided for @privateChatLeaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 나가기 실패'**
  String get privateChatLeaveFailed;
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

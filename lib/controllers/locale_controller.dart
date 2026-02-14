import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocaleController extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  
  Locale _locale = const Locale('ko'); // Default to Korean
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  /// Initialize the controller by loading saved locale preference
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_localeKey);
      
      if (savedLocale != null) {
        _locale = Locale(savedLocale);
      }
      
      // 이미 로그인된 상태라면 Firestore와 동기화 (기존 유저 마이그레이션용)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // 현재 설정된 로케일을 Firestore에 업데이트
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'languageCode': _locale.languageCode});
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('LocaleController 초기화 오류: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set the app locale and persist the preference
  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    
    _locale = newLocale;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, newLocale.languageCode);

      // Sync with Firestore if logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'languageCode': newLocale.languageCode});
      }
    } catch (e) {
      debugPrint('Locale 저장 오류: $e');
    }
  }

  /// Toggle between Korean and English
  Future<void> toggleLocale() async {
    final newLocale = _locale.languageCode == 'ko' 
        ? const Locale('en') 
        : const Locale('ko');
    await setLocale(newLocale);
  }

  /// Get display name for current locale
  String get currentLanguageName {
    return _locale.languageCode == 'ko' ? '한국어' : 'English';
  }

  /// Get display name for a specific locale
  String getLanguageName(Locale locale) {
    return locale.languageCode == 'ko' ? '한국어' : 'English';
  }
}

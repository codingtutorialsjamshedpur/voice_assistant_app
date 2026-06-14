import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageService extends GetxService {
  static StorageService get to => Get.find();

  late GetStorage _box;

  Future<StorageService> init() async {
    _box = GetStorage();
    return this;
  }

  // Keys
  static const String isFirstTime = 'is_first_time';
  static const String isLoggedIn = 'is_logged_in';
  static const String userProfile = 'user_profile';
  static const String chatHistory = 'chat_history';
  static const String alarms = 'alarms';
  static const String reminders = 'reminders';
  static const String wallpapers = 'wallpapers';
  static const String themeMode = 'theme_mode';
  static const String privacyAccepted = 'privacy_accepted';
  static const String hasVisitedVoiceChatKey = 'has_visited_voice_chat';

  // Getters
  bool get isFirstTimeUser => _box.read(isFirstTime) ?? true;
  bool get userIsLoggedIn => _box.read(isLoggedIn) ?? false;
  bool get hasAcceptedPrivacy => _box.read(privacyAccepted) ?? false;
  bool get hasProfile => _box.read(userProfile) != null;
  bool get hasVisitedVoiceChat => _box.read(hasVisitedVoiceChatKey) ?? false;

  // Setters
  Future<void> setFirstTime(bool value) => _box.write(isFirstTime, value);
  Future<void> setPrivacyAccepted(bool value) =>
      _box.write(privacyAccepted, value);
  Future<void> setLoggedIn(bool value) => _box.write(isLoggedIn, value);
  Future<void> setUserProfile(Map<String, dynamic> profile) =>
      _box.write(userProfile, profile);
  Future<void> setHasVisitedVoiceChat(bool value) =>
      _box.write(hasVisitedVoiceChatKey, value);

  // Testing method to reset voice chat visit flag
  Future<void> resetVoiceChatVisitFlag() =>
      _box.write(hasVisitedVoiceChatKey, false);

  dynamic read(String key) => _box.read(key);
  Future<void> write(String key, dynamic value) => _box.write(key, value);
  Future<void> remove(String key) => _box.remove(key);
}

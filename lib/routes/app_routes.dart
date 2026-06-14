import 'package:get/get.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/privacy_policy/privacy_policy_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import '../screens/authentication/authentication_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/voice_chat/voice_chat_screen.dart';
import '../screens/voice_chat/voice_chat_v2_screen.dart';
import '../screens/voice_chat/extended_voice_chat_screen.dart';
import '../screens/unified_voice_interface.dart';
import '../screens/game/game_screen.dart';
import '../screens/game/game_play_screen.dart';
import '../screens/game/voice_assistant_game_screen.dart';
import '../screens/voice_studio/voice_studio_screen.dart';
import '../screens/alarm/alarm_screen.dart';
import '../screens/alarm/alarm_edit_screen.dart';
import '../screens/alarm/alarm_ringing_screen.dart';
import '../screens/naam_jaap/naam_jaap_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/about/about_screen.dart';
import '../screens/about/pdf_viewer_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/wallpaper/wallpaper_screen.dart';
import '../screens/wallpaper/wallpaper_set_screen.dart';
import '../screens/reminder/reminder_screen.dart';
import '../screens/reminder/reminder_edit_screen.dart';
import '../screens/profile/privacy_settings_screen.dart';
import '../screens/wallpaper/wallpaper_trim_screen.dart';

import '../screens/language_coach/language_coach_screen.dart';

class AppRoutes {
  // Route names
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String authentication = '/authentication';
  static const String profile = '/profile';
  static const String voiceChat = '/voice-chat';
  static const String voiceChatV2 = '/voice-chat-v2';
  static const String extendedVoiceChat = '/extended-voice-chat';
  static const String unifiedVoice = '/unified-voice';
  static const String game = '/game';
  static const String gamePlay = '/game-play';
  static const String voiceStudio = '/voice-studio';
  static const String alarm = '/alarm';
  static const String alarmEdit = '/alarm-edit';
  static const String alarmRinging = '/alarm-ringing';
  static const String naamJaap = '/naam-jaap';
  static const String history = '/history';
  static const String about = '/about';
  static const String settings = '/settings';
  static const String wallpaper = '/wallpaper';
  static const String wallpaperSet = '/wallpaper-set';
  static const String reminder = '/reminder';
  static const String reminderEdit = '/reminder-edit';
  static const String pdfViewer = '/pdf-viewer';
  static const String privacy = '/privacy';

  static const String languageCoach = '/language-coach';
  static const String wallpaperTrim = '/wallpaper-trim';
  static const String voiceAssistantGame = '/voice-assistant-game';
  static const String privacyPolicy = '/privacy-policy';

  // Routes list
  static final routes = [
    GetPage(
      name: splash,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: privacyPolicy,
      page: () => const PrivacyPolicyScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: welcome,
      page: () => const WelcomeScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: authentication,
      page: () => const AuthenticationScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: profile,
      page: () => const ProfileScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: privacy,
      page: () => const PrivacySettingsScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: voiceChat,
      page: () => const VoiceChatScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: voiceChatV2,
      page: () => const VoiceChatV2Screen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: extendedVoiceChat,
      page: () => const ExtendedVoiceChatScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: unifiedVoice,
      page: () => const UnifiedVoiceInterface(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: game,
      page: () => const GameScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: gamePlay,
      page: () => const GamePlayScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: voiceStudio,
      page: () => const VoiceStudioScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: alarm,
      page: () => const AlarmScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: alarmEdit,
      page: () => const AlarmEditScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: alarmRinging,
      page: () => const AlarmRingingScreen(),
      transition: Transition.zoom,
    ),
    GetPage(
      name: naamJaap,
      page: () => const NaamJaapScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: history,
      page: () => const HistoryScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: about,
      page: () => const AboutScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: settings,
      page: () => const SettingsScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: wallpaper,
      page: () => const WallpaperScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: wallpaperSet,
      page: () => const WallpaperSetScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: wallpaperTrim,
      page: () => const WallpaperTrimScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: reminder,
      page: () => const ReminderScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: reminderEdit,
      page: () => const ReminderEditScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: pdfViewer,
      page: () => const PDFViewerScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: languageCoach,
      page: () => const LanguageCoachScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: voiceAssistantGame,
      page: () => const VoiceAssistantGameScreen(),
      transition: Transition.fadeIn,
    ),
  ];
}

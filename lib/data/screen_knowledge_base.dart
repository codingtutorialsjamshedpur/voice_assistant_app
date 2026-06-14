/// ════════════════════════════════════════════════════════════════
/// Screen Knowledge Base — Centralized AI awareness of all screens
/// ════════════════════════════════════════════════════════════════
///
/// This file documents every screen with its purpose, buttons,
/// gestures, voice commands, and navigation options so the AI can
/// answer any context-aware question about the app.
///
/// Maps to task.md Task 3.1: Build Screen Knowledge Database
/// ════════════════════════════════════════════════════════════════
library;

import '../models/screen_info.dart';

class ScreenKnowledgeBase {
  // ── Singleton ────────────────────────────────────────────────
  ScreenKnowledgeBase._();
  static final ScreenKnowledgeBase instance = ScreenKnowledgeBase._();

  /// Full map of all known screens keyed by route name
  static final Map<String, ScreenInfo> screens = {
    // ── Splash Screen ────────────────────────────────────────────
    '/splash': const ScreenInfo(
      name: '/splash',
      displayName: 'Splash Screen',
      description: 'App loading screen shown at startup',
      purpose:
          'Shows the app logo and initializes all services while the app loads.',
      features: ['App branding', 'Service initialization'],
      gestures: [],
      buttons: [],
      voiceCommands: [],
      hasAIInteraction: false,
      navigatesTo: ['/welcome'],
      tip:
          'This screen appears briefly on startup and transitions automatically.',
    ),

    // ── Welcome Screen ───────────────────────────────────────────
    '/welcome': const ScreenInfo(
      name: '/welcome',
      displayName: 'Welcome Screen',
      description: 'Introduction screen for new users',
      purpose:
          'Introduces the app to the user and guides them to log in or sign up.',
      features: [
        'App introduction',
        'Login button',
        'Sign up button',
        'Language selection',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap Login button',
          action: 'Navigate to authentication screen for login',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Sign Up button',
          action: 'Navigate to authentication screen for registration',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Login',
          description: 'Log into your existing account',
          onTap: 'Opens authentication screen in login mode',
        ),
        ButtonInfo(
          name: 'Sign Up',
          description: 'Create a new account',
          onTap: 'Opens authentication screen in sign-up mode',
        ),
      ],
      voiceCommands: ['Login', 'Sign Up', 'Register'],
      hasAIInteraction: false,
      navigatesTo: ['/authentication'],
    ),

    // ── Authentication Screen ────────────────────────────────────
    '/authentication': const ScreenInfo(
      name: '/authentication',
      displayName: 'Authentication Screen',
      description: 'Login and sign-up page',
      purpose:
          'Allows users to authenticate with their name/email or create a new account.',
      features: [
        'Login form',
        'Sign-up form',
        'Profile name entry',
        'Age group selection',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap input field',
          action: 'Opens keyboard to type name or email',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Submit / Continue button',
          action: 'Validates and submits authentication form',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Submit',
          description: 'Submit login or registration form',
          onTap: 'Validates form and moves to the main app',
        ),
      ],
      voiceCommands: ['Submit', 'Continue', 'Next'],
      hasAIInteraction: false,
      navigatesTo: ['/voice-chat'],
    ),

    // ── Voice Chat Screen ────────────────────────────────────────
    '/voice-chat': const ScreenInfo(
      name: '/voice-chat',
      displayName: 'Voice Chat',
      description: 'Main AI assistant interface for text and voice queries',
      purpose:
          'The primary screen where users can chat with the AI assistant using '
          'voice or text. Supports Hindi, English, and Hinglish.',
      features: [
        'Voice input via STT (Speech-to-Text)',
        'Text keyboard input',
        'AI responses via TTS (Text-to-Speech)',
        'Real-time query processing',
        'Conversation history',
        'Language switching (EN/HI/Hinglish)',
        'Model selection',
        'Weather & AQI info in top panel',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap microphone button',
          action: 'Start voice recording / STT listening',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap again while recording',
          action: 'Stop recording and send query to AI',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap text input box',
          action: 'Open expanded text input bottom sheet to type a message',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap language flag button',
          action: 'Open language picker to change STT/TTS language',
        ),
        GestureInfo(
          type: 'long_press',
          description: 'Long press microphone button',
          action: 'Cancel the current recording without sending',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Microphone',
          description: 'Start or stop voice input recording',
          onTap: 'Toggle voice recording on/off',
          onLongPress: 'Cancel recording',
        ),
        ButtonInfo(
          name: 'Send',
          description: 'Send the typed message to AI',
          onTap: 'Sends the text message and gets AI response',
        ),
        ButtonInfo(
          name: 'Language Flag',
          description: 'Change the language for voice recognition and speech',
          onTap: 'Opens language picker bottom sheet',
        ),
        ButtonInfo(
          name: 'Mode Switch',
          description: 'Switch between Chat mode and Voice Memo mode',
          onTap: 'Toggles between chat input and voice memo recording',
        ),
        ButtonInfo(
          name: 'Clear',
          description: 'Clear the text input field',
          onTap: 'Empties the current text input',
        ),
        ButtonInfo(
          name: 'Read',
          description: 'Read the typed text aloud without sending to AI',
          onTap: 'Speaks the typed text using TTS',
        ),
      ],
      voiceCommands: [
        'Stop',
        'Done',
        'Cancel',
        'Clear',
        'Repeat',
        'Pause',
        'Resume',
        'बंद करो',
        'रुको',
        'दोबारा बताओ',
      ],
      hasAIInteraction: true,
      navigatesTo: ['/game', '/naam-jaap', '/history', '/settings', '/profile'],
      tip:
          'You can speak in Hindi, English, or mix both (Hinglish). The AI understands all three!',
    ),

    // ── Game Hub Screen ──────────────────────────────────────────
    '/game': const ScreenInfo(
      name: '/game',
      displayName: 'Game Hub',
      description: 'Screen to select and launch voice-controlled games',
      purpose:
          'Lists all available games — Tic Tac Toe and Voice Assistant Game — '
          'so users can pick one to play.',
      features: [
        'Tic Tac Toe game card',
        'Voice Assistant Game card',
        'Game descriptions with voice narration',
        'Animated game selection UI',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap a game card',
          action: 'Launch the selected game',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Tic Tac Toe',
          description: 'Play the classic Tic Tac Toe game',
          onTap: 'Launches Tic Tac Toe game screen',
        ),
        ButtonInfo(
          name: 'Voice Assistant Game',
          description: 'Have a voice conversation with the AI Orb',
          onTap: 'Launches Voice Assistant game with animated Orb',
        ),
      ],
      voiceCommands: ['Play Tic Tac Toe', 'Voice Game', 'Go back', 'Back'],
      hasAIInteraction: true,
      navigatesTo: ['/game-play'],
      tip:
          'The Voice Assistant Game screen is a fun, conversation-only experience. No text is shown!',
    ),

    // ── Game Play Screen ─────────────────────────────────────────
    '/game-play': const ScreenInfo(
      name: '/game-play',
      displayName: 'Voice Assistant Game',
      description:
          'Voice-only conversational game with an animated glowing Orb',
      purpose:
          'A hands-free, voice-only AI conversation experience. The animated Orb '
          'listens to the user, sends queries to the AI, and responds via TTS. '
          'No text is displayed — everything is done through voice.',
      features: [
        'Animated glowing Orb that reacts to speech',
        'Continuous STT recording',
        'End-of-turn detection via keyword ("done" / "ho gaya")',
        'AI response via TTS',
        'Gesture-based controls (tap to pause, double-tap to exit)',
        'Sound cues for state transitions',
        'Persistent conversation memory',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Single tap on the Orb',
          action: 'Pause or resume microphone input',
        ),
        GestureInfo(
          type: 'double_tap',
          description: 'Double tap on the Orb',
          action: 'End the conversation and navigate back to Game Hub',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Orb',
          description: 'The animated central orb — the core of the game',
          onTap: 'Pause / resume microphone recording',
          onDoubleTap: 'Exit the conversation and go back to game list',
        ),
      ],
      voiceCommands: [
        'Done',
        'Ho gaya',
        'Hogaya',
        'Bye',
        'Alvida',
        'Stop',
        'Exit',
        'हो गया',
        'बाय',
        'अलविदा',
      ],
      hasAIInteraction: true,
      navigatesTo: ['/game'],
      tip:
          'Say "done" or "ho gaya" after speaking to let the AI process your message. '
          'Double-tap the Orb to exit.',
    ),

    // ── Naam Jaap Screen ─────────────────────────────────────────
    '/naam-jaap': const ScreenInfo(
      name: '/naam-jaap',
      displayName: 'Naam Jaap',
      description: 'Spiritual mantra repetition screen',
      purpose:
          'Helps users repeat a spiritual mantra (Naam Jaap) a set number of times. '
          'Tracks progress and provides voice-guided chanting.',
      features: [
        'Mantra repetition with count tracking',
        'Customizable repetition count via slider',
        'Progress indicator',
        'Voice guidance for chanting',
        'Pause and resume functionality',
        'Completion notification',
      ],
      gestures: [
        GestureInfo(
          type: 'drag',
          description: 'Drag the slider',
          action: 'Adjust the number of mantra repetitions',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Start button',
          action: 'Begin mantra repetition session',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Pause button',
          action: 'Pause the current Naam Jaap session',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Resume button',
          action: 'Resume the paused Naam Jaap session',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Start',
          description: 'Start the mantra repetition session',
          onTap: 'Begins Naam Jaap with the selected count',
        ),
        ButtonInfo(
          name: 'Pause',
          description: 'Pause the ongoing session',
          onTap: 'Pauses mantra repetition',
        ),
        ButtonInfo(
          name: 'Resume',
          description: 'Resume from where you left off',
          onTap: 'Continues mantra repetition',
        ),
        ButtonInfo(
          name: 'Stop',
          description: 'Stop and reset the session',
          onTap: 'Ends the session and resets the counter',
        ),
      ],
      voiceCommands: ['Start', 'Pause', 'Resume', 'Stop', 'शुरू करो', 'रुको'],
      hasAIInteraction: true,
      navigatesTo: ['/voice-chat', '/game'],
      tip:
          'You can set how many times you want to repeat the mantra using the slider.',
    ),

    // ── History Screen ───────────────────────────────────────────
    '/history': const ScreenInfo(
      name: '/history',
      displayName: 'History',
      description: 'Past conversations and AI activity log',
      purpose:
          'Shows a chronological list of all past AI conversations, voice queries, '
          'and activity logs so users can review what they discussed.',
      features: [
        'Conversation history list',
        'Activity log entries',
        'Conversation summaries',
        'Date/time stamps',
        'Search and filter (if available)',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap a history item',
          action: 'View detailed conversation or activity',
        ),
        GestureInfo(
          type: 'swipe',
          description: 'Swipe left on an item',
          action: 'Delete the selected history entry',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Clear All',
          description: 'Remove all history entries',
          onTap: 'Deletes all conversation history after confirmation',
        ),
      ],
      voiceCommands: ['Clear', 'Delete', 'Go back', 'Back'],
      hasAIInteraction: false,
      navigatesTo: ['/voice-chat'],
      tip: 'Your conversation history is stored locally on your device.',
    ),

    // ── Settings Screen ──────────────────────────────────────────
    '/settings': const ScreenInfo(
      name: '/settings',
      displayName: 'Settings',
      description: 'App configuration and preferences',
      purpose:
          'Allows users to configure app preferences such as language, TTS speed, '
          'voice type, notification settings, and privacy options.',
      features: [
        'Language and TTS configuration',
        'Voice speed and pitch',
        'Notification preferences',
        'Privacy settings',
        'Theme options',
        'App version info',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap a setting toggle',
          action: 'Enable or disable a setting',
        ),
        GestureInfo(
          type: 'drag',
          description: 'Drag a slider',
          action: 'Adjust TTS speed or pitch level',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Language',
          description: 'Choose app language',
          onTap: 'Opens language selection',
        ),
        ButtonInfo(
          name: 'Voice Speed',
          description: 'Adjust how fast the AI speaks',
          onTap: 'Shows speed slider',
        ),
        ButtonInfo(
          name: 'Privacy',
          description: 'Manage data and privacy settings',
          onTap: 'Opens privacy settings screen',
        ),
        ButtonInfo(
          name: 'Notifications',
          description: 'Manage reminder and alarm notifications',
          onTap: 'Opens notification settings',
        ),
      ],
      voiceCommands: ['Back', 'Go back', 'Save'],
      hasAIInteraction: false,
      navigatesTo: ['/privacy', '/notifications', '/voice-chat'],
    ),

    // ── Alarm Screen ─────────────────────────────────────────────
    '/alarm': const ScreenInfo(
      name: '/alarm',
      displayName: 'Alarms',
      description: 'List of all set alarms',
      purpose:
          'Lets users view, create, edit, and delete alarms that ring at specified times.',
      features: [
        'List of all alarms with time and label',
        'Enable/disable toggle per alarm',
        'Create new alarm',
        'Edit existing alarm',
        'Delete alarm',
        'Repeating alarm support',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap an alarm',
          action: 'Open alarm edit screen',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap toggle switch',
          action: 'Enable or disable the alarm',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap + button',
          action: 'Create a new alarm',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Add Alarm',
          description: 'Create a new alarm',
          onTap: 'Opens alarm creation screen',
        ),
        ButtonInfo(
          name: 'Enable Toggle',
          description: 'Turn a specific alarm on or off',
          onTap: 'Toggles alarm active state',
        ),
        ButtonInfo(
          name: 'Delete',
          description: 'Remove an alarm permanently',
          onTap: 'Deletes the selected alarm',
        ),
      ],
      voiceCommands: ['Add alarm', 'Delete alarm', 'Back'],
      hasAIInteraction: false,
      navigatesTo: ['/alarm-edit'],
    ),

    // ── Reminder Screen ──────────────────────────────────────────
    '/reminder': const ScreenInfo(
      name: '/reminder',
      displayName: 'Reminders',
      description: 'List of all reminders',
      purpose:
          'Allows users to create, edit, and manage reminders with specific dates/times.',
      features: [
        'List of all reminders',
        'Create new reminder',
        'Set reminder time and message',
        'Mark as done',
        'Delete reminder',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap a reminder',
          action: 'Edit the reminder',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap + button',
          action: 'Add a new reminder',
        ),
        GestureInfo(
          type: 'swipe',
          description: 'Swipe left',
          action: 'Delete the reminder',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Add Reminder',
          description: 'Create a new reminder',
          onTap: 'Opens reminder creation screen',
        ),
        ButtonInfo(
          name: 'Mark Done',
          description: 'Mark reminder as completed',
          onTap: 'Marks reminder complete and removes it from active list',
        ),
      ],
      voiceCommands: ['Add reminder', 'Delete', 'Mark done', 'Back'],
      hasAIInteraction: false,
      navigatesTo: ['/reminder-edit'],
    ),

    // ── Wallpaper Screen ─────────────────────────────────────────
    '/wallpaper': const ScreenInfo(
      name: '/wallpaper',
      displayName: 'Wallpapers',
      description: 'Browse and apply live or static wallpapers',
      purpose:
          'Lets users browse available wallpapers (static images and animated videos) '
          'and apply one as the app background.',
      features: [
        'Gallery of wallpaper options',
        'Live/animated video wallpapers',
        'Static image wallpapers',
        'Preview before applying',
        'Easy one-tap apply',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap a wallpaper',
          action: 'Preview and apply the selected wallpaper',
        ),
        GestureInfo(
          type: 'swipe',
          description: 'Swipe to scroll',
          action: 'Browse more wallpapers in the gallery',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Apply',
          description: 'Set the wallpaper as current background',
          onTap: 'Applies the selected wallpaper to the whole app',
        ),
        ButtonInfo(
          name: 'Preview',
          description: 'Preview the wallpaper before applying',
          onTap: 'Shows a full-screen preview',
        ),
      ],
      voiceCommands: ['Apply', 'Preview', 'Back', 'Go back'],
      hasAIInteraction: false,
      navigatesTo: ['/wallpaper-set', '/voice-chat'],
    ),

    // ── About Screen ─────────────────────────────────────────────
    '/about': const ScreenInfo(
      name: '/about',
      displayName: 'About',
      description: 'App information and developer contact',
      purpose:
          'Shows information about the app, its version, the developer (Sourav Kumar), '
          'and contact details.',
      features: [
        'App name and version',
        'Developer information (Sourav Kumar)',
        'App description',
        'Contact / social links',
        'Open source credits (if any)',
        'Privacy policy link',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap contact link',
          action: 'Open contact method (email / social)',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Contact Developer',
          description: 'Reach out to the developer Sourav Kumar',
          onTap: 'Opens email or contact page for Sourav Kumar',
        ),
        ButtonInfo(
          name: 'Privacy Policy',
          description: 'View the app privacy policy',
          onTap: 'Opens privacy policy document',
        ),
      ],
      voiceCommands: ['Back', 'Contact developer', 'Who made this'],
      hasAIInteraction: false,
      navigatesTo: ['/voice-chat'],
      tip:
          'This app was developed by Sourav Kumar. Use the Contact button to get in touch.',
    ),

    // ── Profile Screen ───────────────────────────────────────────
    '/profile': const ScreenInfo(
      name: '/profile',
      displayName: 'Profile',
      description: 'User profile and personalization settings',
      purpose:
          'Allows users to set or update their name, title, age group, and profile picture. '
          'This data is used by the AI to personalize responses.',
      features: [
        'Edit profile name and title',
        'Age group selection (Child / Teen / Adult)',
        'Profile picture upload',
        'AI personalization based on profile',
        'Save and update profile',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap profile picture',
          action: 'Open image picker to change profile picture',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap name/title field',
          action: 'Edit and type new name or title',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Save',
          description: 'Save profile changes',
          onTap: 'Saves updated profile information',
        ),
        ButtonInfo(
          name: 'Edit Picture',
          description: 'Change profile photo',
          onTap: 'Opens image picker',
        ),
      ],
      voiceCommands: ['Save', 'Back', 'Cancel'],
      hasAIInteraction: false,
      navigatesTo: ['/voice-chat'],
      tip:
          'Setting your age group helps the AI adapt its language and tone for you!',
    ),

    // ── Voice Studio Screen ──────────────────────────────────────
    '/voice-studio': const ScreenInfo(
      name: '/voice-studio',
      displayName: 'Voice Studio',
      description: 'Record, play, and share custom voice memos',
      purpose:
          'A studio-style screen for recording voice memos, listening to recordings, '
          'and sharing them.',
      features: [
        'High-quality voice recording',
        'Playback with waveform visualization',
        'Library of past recordings',
        'Share recordings',
        'Delete recordings',
        'Recording timer',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap Record button',
          action: 'Start a new voice recording',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Stop button',
          action: 'Stop the current recording',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Play button',
          action: 'Play back a selected recording',
        ),
        GestureInfo(
          type: 'long_press',
          description: 'Long press a recording',
          action: 'Show options: share, delete, or rename',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Record',
          description: 'Start recording a voice memo',
          onTap: 'Begins audio recording',
        ),
        ButtonInfo(
          name: 'Stop',
          description: 'Stop the current recording',
          onTap: 'Ends recording and saves the file',
        ),
        ButtonInfo(
          name: 'Play',
          description: 'Play back a recording',
          onTap: 'Plays the selected audio file',
        ),
        ButtonInfo(
          name: 'Share',
          description: 'Share a recording with other apps',
          onTap: 'Opens share sheet to send the audio file',
        ),
        ButtonInfo(
          name: 'Delete',
          description: 'Delete a recording permanently',
          onTap: 'Removes the selected recording',
        ),
      ],
      voiceCommands: ['Record', 'Stop', 'Play', 'Share', 'Delete', 'Back'],
      hasAIInteraction: false,
      navigatesTo: ['/voice-chat'],
    ),

    // ── Language Coach Screen ────────────────────────────────────
    '/language-coach': const ScreenInfo(
      name: '/language-coach',
      displayName: 'Language Coach',
      description: 'Practice pronunciation in multiple languages',
      purpose:
          'Helps users learn and practice pronunciation of words and phrases '
          'in various languages with real-time TTS feedback.',
      features: [
        'Multi-language word library',
        'TTS pronunciation playback',
        'Recording and comparison',
        'Progress tracking',
        'Flashcard-style practice',
      ],
      gestures: [
        GestureInfo(
          type: 'tap',
          description: 'Tap a word or phrase',
          action: 'Hear the correct pronunciation via TTS',
        ),
        GestureInfo(
          type: 'tap',
          description: 'Tap Record button',
          action: 'Record your pronunciation for comparison',
        ),
      ],
      buttons: [
        ButtonInfo(
          name: 'Listen',
          description: 'Hear the correct pronunciation',
          onTap: 'Plays TTS audio for the selected word',
        ),
        ButtonInfo(
          name: 'Record',
          description: 'Record your own pronunciation',
          onTap: 'Starts recording your voice for the word',
        ),
        ButtonInfo(
          name: 'Next',
          description: 'Move to the next word or phrase',
          onTap: 'Shows next practice word',
        ),
      ],
      voiceCommands: ['Listen', 'Next', 'Back', 'Repeat'],
      hasAIInteraction: true,
      navigatesTo: ['/voice-chat'],
    ),
  };

  // ── Public API ───────────────────────────────────────────────

  /// Get screen info by route name (e.g. '/voice-chat')
  static ScreenInfo? getScreenInfo(String route) => screens[route];

  /// Get all route names
  static List<String> getAllRoutes() => screens.keys.toList();

  /// Get the human-readable name for a route
  static String getDisplayName(String route) =>
      screens[route]?.displayName ?? route;

  /// Get a short AI-ready context summary for a route
  static String getContextSummary(String route) =>
      screens[route]?.toContextString() ?? 'Unknown screen: $route';

  /// Get all screens that have AI interaction enabled
  static List<ScreenInfo> getAIScreens() =>
      screens.values.where((s) => s.hasAIInteraction).toList();

  /// Build a compact multi-screen overview for the AI system prompt
  /// describing every screen in a brief format
  static String buildFullAppSummary() {
    final sb = StringBuffer();
    sb.writeln('APP SCREENS OVERVIEW:');
    sb.writeln('═' * 50);
    for (final entry in screens.entries) {
      final info = entry.value;
      sb.writeln('• ${info.displayName}: ${info.description}');
    }
    sb.writeln('═' * 50);
    return sb.toString();
  }

  /// Build the system prompt context section for a specific current screen
  static String buildSystemPromptSection(String currentRoute) {
    final info = screens[currentRoute];
    if (info == null) return 'User is on an unknown screen ($currentRoute).';

    final sb = StringBuffer();
    sb.writeln('CURRENT SCREEN: ${info.displayName}');
    sb.writeln('SCREEN PURPOSE: ${info.purpose}');

    if (info.features.isNotEmpty) {
      sb.writeln('FEATURES AVAILABLE: ${info.features.join(", ")}');
    }

    if (info.gestures.isNotEmpty) {
      sb.writeln('HOW TO INTERACT:');
      for (final g in info.gestures) {
        sb.writeln('  - ${g.description} → ${g.action}');
      }
    }

    if (info.buttons.isNotEmpty) {
      sb.writeln('BUTTONS ON SCREEN:');
      for (final b in info.buttons) {
        sb.writeln('  - ${b.name}: ${b.description}');
      }
    }

    if (info.voiceCommands.isNotEmpty) {
      sb.writeln('VOICE COMMANDS: ${info.voiceCommands.join(", ")}');
    }

    if (info.navigatesTo.isNotEmpty) {
      sb.writeln(
          'CAN NAVIGATE TO: ${info.navigatesTo.map((r) => getDisplayName(r)).join(", ")}');
    }

    if (info.tip != null) {
      sb.writeln('TIP: ${info.tip}');
    }

    return sb.toString().trim();
  }
}

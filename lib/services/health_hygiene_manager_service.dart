// lib/services/health_hygiene_manager_service.dart
// ═══════════════════════════════════════════════════════════════
// HEALTH & HYGIENE MANAGER SERVICE
// ═══════════════════════════════════════════════════════════════
//
// Core Feature: Affectionate Health & Hygiene Awareness System
//
// This service manages:
// 1. Age group detection (Toddler, Child, Teen, Adult)
// 2. Context-aware health reminders (playful, caring, or strict)
// 3. Safety monitoring and emergency responses
// 4. Multi-language support (English/Hindi/Hinglish)
// 5. Emotional, parent-like care and concern
//
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'family_relationship_manager_service.dart';
import 'ruflo_service.dart';

// ───────────────────────────────────────────────────────────────
// ENUMS & MODELS
// ───────────────────────────────────────────────────────────────

/// Age group categories for tone and message adaptation
enum AgeGroup {
  toddler, // 0-3 years
  youngChild, // 4-7 years
  child, // 8-10 years
  preteen, // 11-12 years
  teenager, // 13-17 years
  youngAdult, // 18-25 years
  adult, // 26-50 years
  elder, // 50+ years
}

/// Health/Safety context for detecting risky situations
enum SafetyContext {
  normal, // Regular interaction
  outdoor, // User going outside
  crossing, // User crossing street/road
  dizzy, // User feeling dizzy
  breathless, // User having difficulty breathing
  eating, // User about to eat
  sleeping, // User about to sleep
  emergency, // Emergency situation detected
}

/// Tone for health messages
enum HealthTone {
  playful, // For toddlers - fun, cute tone
  caring, // For children - warm, protective tone
  friendly, // For teens - mature but friendly
  concerned, // For adults - respectful concern
  strict, // For emergencies - firm and protective
}

/// Health reminder category
enum HealthReminderType {
  handWashing,
  hygiene,
  hydration,
  nutrition,
  sleep,
  exercise,
  medicine,
  outdoor,
  weather,
  emergency,
}

class HealthContext {
  final SafetyContext safetyContext;
  final AgeGroup ageGroup;
  final HealthTone tone;
  final List<HealthReminderType> applicableReminders;
  final bool isRisky;
  final String description;

  HealthContext({
    required this.safetyContext,
    required this.ageGroup,
    required this.tone,
    required this.applicableReminders,
    this.isRisky = false,
    required this.description,
  });
}

// ───────────────────────────────────────────────────────────────
// HEALTH & HYGIENE MANAGER SERVICE
// ───────────────────────────────────────────────────────────────

class HealthHygieneManagerService extends GetxService {
  static HealthHygieneManagerService get to => Get.find();

  // Observable states
  final Rx<AgeGroup> detectedAgeGroup = AgeGroup.adult.obs;
  final RxString userName = 'Friend'.obs;
  final Rx<FamilyLanguage> preferredLanguage = FamilyLanguage.hinglish.obs;
  final RxBool hasAnalyzedProfile = false.obs;
  final Rx<HealthContext?> currentHealthContext = Rx(null);

  late ProfileController _profileController;
  late FamilyRelationshipManagerService _familyManager;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initialize();
  }

  Future<void> _initialize() async {
    try {
      _profileController = Get.find<ProfileController>();
      _familyManager = Get.find<FamilyRelationshipManagerService>();
      await _analyzeUserProfile();
      debugPrint('✅ Health & Hygiene Manager initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Health & Hygiene Manager: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // PROFILE ANALYSIS
  // ───────────────────────────────────────────────────────────────

  Future<void> _analyzeUserProfile() async {
    try {
      final profile = _profileController.userProfile.value;
      userName.value = profile.name;

      // Detect age group from profile
      _detectAgeGroup(profile);

      // Get language preference
      preferredLanguage.value = _familyManager.preferredLanguage.value;

      hasAnalyzedProfile.value = true;

      debugPrint(
        '📊 Health Profile Analysis:\n'
        '   Age Group: ${detectedAgeGroup.value.name}\n'
        '   User: ${userName.value}\n'
        '   Language: ${preferredLanguage.value.name}',
      );
    } catch (e) {
      debugPrint('Error analyzing user profile: $e');
    }
  }

  /// Detect age group from profile data
  void _detectAgeGroup(UserProfile profile) {
    final text =
        '${profile.fieldOfInterest} ${profile.anticipation}'.toLowerCase();

    if (text.contains('toddler') ||
        text.contains('baby') ||
        text.contains('0-3')) {
      detectedAgeGroup.value = AgeGroup.toddler;
    } else if (text.contains('young child') ||
        text.contains('4-7') ||
        text.contains('kindergarten')) {
      detectedAgeGroup.value = AgeGroup.youngChild;
    } else if (text.contains('child') ||
        text.contains('8-10') ||
        text.contains('grade')) {
      detectedAgeGroup.value = AgeGroup.child;
    } else if (text.contains('preteen') || text.contains('11-12')) {
      detectedAgeGroup.value = AgeGroup.preteen;
    } else if (text.contains('teen') ||
        text.contains('teenager') ||
        text.contains('13-17')) {
      detectedAgeGroup.value = AgeGroup.teenager;
    } else if (text.contains('student') ||
        text.contains('college') ||
        text.contains('18-25')) {
      detectedAgeGroup.value = AgeGroup.youngAdult;
    } else if (text.contains('professional') ||
        text.contains('adult') ||
        text.contains('26-50')) {
      detectedAgeGroup.value = AgeGroup.adult;
    } else if (text.contains('senior') ||
        text.contains('elder') ||
        text.contains('50+')) {
      detectedAgeGroup.value = AgeGroup.elder;
    }
  }

  // ───────────────────────────────────────────────────────────────
  // SAFETY CONTEXT DETECTION
  // ───────────────────────────────────────────────────────────────

  /// Detect safety context from user input
  SafetyContext detectSafetyContext(String userInput) {
    final text = userInput.toLowerCase();

    if (text.contains('crossing') ||
        text.contains('road') ||
        text.contains('street') ||
        text.contains('traffic')) {
      return SafetyContext.crossing;
    }

    if (text.contains('dizzy') ||
        text.contains('giddy') ||
        text.contains('vertigo') ||
        text.contains('head spinning')) {
      return SafetyContext.dizzy;
    }

    if (text.contains('breathless') ||
        text.contains('panting') ||
        text.contains('can\'t breathe') ||
        text.contains('shortness')) {
      return SafetyContext.breathless;
    }

    if (text.contains('going out') ||
        text.contains('outside') ||
        text.contains('outdoor')) {
      return SafetyContext.outdoor;
    }

    if (text.contains('eating') ||
        text.contains('lunch') ||
        text.contains('dinner') ||
        text.contains('breakfast')) {
      return SafetyContext.eating;
    }

    if (text.contains('sleeping') ||
        text.contains('sleep') ||
        text.contains('bed') ||
        text.contains('good night')) {
      return SafetyContext.sleeping;
    }

    if (text.contains('emergency') ||
        text.contains('help') ||
        text.contains('danger') ||
        text.contains('urgent')) {
      return SafetyContext.emergency;
    }

    return SafetyContext.normal;
  }

  /// Get appropriate tone based on age and context
  HealthTone _getTone(AgeGroup age, SafetyContext context) {
    // Emergency always strict
    if (context == SafetyContext.emergency) {
      return HealthTone.strict;
    }

    switch (age) {
      case AgeGroup.toddler:
        return HealthTone.playful;
      case AgeGroup.youngChild:
        return HealthTone.playful;
      case AgeGroup.child:
        return HealthTone.caring;
      case AgeGroup.preteen:
        return HealthTone.caring;
      case AgeGroup.teenager:
        return HealthTone.friendly;
      case AgeGroup.youngAdult:
        return HealthTone.friendly;
      case AgeGroup.adult:
        return HealthTone.concerned;
      case AgeGroup.elder:
        return HealthTone.concerned;
    }
  }

  // ───────────────────────────────────────────────────────────────
  // HEALTH REMINDER GENERATION
  // ───────────────────────────────────────────────────────────────

  /// Generate health reminder message
  String generateHealthReminder(
    SafetyContext context, {
    String? userInput,
  }) {
    final ageGroup = detectedAgeGroup.value;
    final tone = _getTone(ageGroup, context);
    final language = preferredLanguage.value;

    // Build health context
    final healthContext = HealthContext(
      safetyContext: context,
      ageGroup: ageGroup,
      tone: tone,
      applicableReminders: _getApplicableReminders(context, ageGroup),
      isRisky: _isRiskyContext(context),
      description: _getContextDescription(context),
    );

    currentHealthContext.value = healthContext;

    // Generate message based on language
    switch (language) {
      case FamilyLanguage.english:
        return _generateEnglishHealthReminder(healthContext);
      case FamilyLanguage.hindi:
        return _generateHindiHealthReminder(healthContext);
      case FamilyLanguage.hinglish:
        return _generateHinglishHealthReminder(healthContext);
    }
  }

  String _generateEnglishHealthReminder(HealthContext context) {
    switch (context.tone) {
      case HealthTone.playful:
        return _generatePlayfulEnglish(context);
      case HealthTone.caring:
        return _generateCaringEnglish(context);
      case HealthTone.friendly:
        return _generateFriendlyEnglish(context);
      case HealthTone.concerned:
        return _generateConcernedEnglish(context);
      case HealthTone.strict:
        return _generateStrictEnglish(context);
    }
  }

  String _generateHindiHealthReminder(HealthContext context) {
    switch (context.tone) {
      case HealthTone.playful:
        return _generatePlayfulHindi(context);
      case HealthTone.caring:
        return _generateCaringHindi(context);
      case HealthTone.friendly:
        return _generateFriendlyHindi(context);
      case HealthTone.concerned:
        return _generateConcernedHindi(context);
      case HealthTone.strict:
        return _generateStrictHindi(context);
    }
  }

  String _generateHinglishHealthReminder(HealthContext context) {
    switch (context.tone) {
      case HealthTone.playful:
        return _generatePlayfulHinglish(context);
      case HealthTone.caring:
        return _generateCaringHinglish(context);
      case HealthTone.friendly:
        return _generateFriendlyHinglish(context);
      case HealthTone.concerned:
        return _generateConcernedHinglish(context);
      case HealthTone.strict:
        return _generateStrictHinglish(context);
    }
  }

  // ───────────────────────────────────────────────────────────────
  // PLAYFUL TONE (TODDLERS/YOUNG CHILDREN)
  // ───────────────────────────────────────────────────────────────

  String _generatePlayfulEnglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Wash your hands before eating, babu! 🧼 Otherwise mommy will scold you. '
            'Squeaky clean hands = strong body! 💪';

      case SafetyContext.outdoor:
        return 'Ohhh, going outside? How exciting! 🎉 \n'
            'Carry your mask, beta. Handkerchief too! \n'
            'Stay safe and have fun! 🌞';

      case SafetyContext.sleeping:
        return 'Wash your face and feet before sleeping, sweet one! 😴 \n'
            'Brush your teeth well - they need rest too! 🦷 \n'
            'Sleep tight, sleep well! 💤';

      default:
        return 'Babu, remember to wash your hands! 🧼 \n'
            'Clean hands = healthy body! 💚';
    }
  }

  String _generatePlayfulHindi(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'खाना खाने से पहले हाथ धो लो, बाबू! 🧼\n'
            'नहीं तो मां को बुरा लगेगा। 😊\n'
            'साफ हाथ = मजबूत शरीर! 💪';

      case SafetyContext.outdoor:
        return 'वाह! बाहर जा रहे हो? कितना मजेदार! 🎉\n'
            'अपना मास्क ले जाना, बेटा। रूमाल भी! 🌡️\n'
            'सुरक्षित रहो और मजे करो! 🌞';

      case SafetyContext.sleeping:
        return 'सोने से पहले मुंह और पैर धो लो, प्यारे! 😴\n'
            'दांतों को अच्छे से ब्रश कर - उन्हें भी आराम चाहिए! 🦷\n'
            'अच्छी नींद आए! 💤';

      default:
        return 'बाबू, हाथ धोना मत भूलो! 🧼\n'
            'साफ हाथ = सुस्थ शरीर! 💚';
    }
  }

  String _generatePlayfulHinglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Khana khane se pehle hath dhol le, babu! 🧼\n'
            'Nahi to mama ko bura lagega. 😊\n'
            'Saaf hath = mazboot sharir! 💪';

      case SafetyContext.outdoor:
        return 'Wah! Bahar ja rahe ho? Kitna mazzedar! 🎉\n'
            'Apna mask le jana, beta. Rumaal bhi! 🌡️\n'
            'Surakshit raho aur maze karo! 🌞';

      case SafetyContext.sleeping:
        return 'Sone se pehle muh aur pair dho lo, pyare! 😴\n'
            'Danton ko achche se brush kar - unhe bhi aram chahiye! 🦷\n'
            'Achi need aaye! 💤';

      default:
        return 'Babu, hath dhona mat bhulo! 🧼\n'
            'Saaf hath = susth sharir! 💚';
    }
  }

  // ───────────────────────────────────────────────────────────────
  // CARING TONE (CHILDREN)
  // ───────────────────────────────────────────────────────────────

  String _generateCaringEnglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Beta, please wash your hands before eating. 🧼\n'
            'This protects you from germs and keeps you healthy and strong.\n'
            'Health is wealth, remember? 💚';

      case SafetyContext.outdoor:
        return 'I care about you, so before you go outside:\n'
            '✓ Carry a mask with you\n'
            '✓ Take a handkerchief\n'
            '✓ It looks a bit cold, take a jacket 🧥\n'
            '✓ Don\'t forget your phone\n'
            'Stay safe and have fun! 🌞';

      case SafetyContext.sleeping:
        return 'Before bed, my dear:\n'
            '✓ Wash your face and feet 🛁\n'
            '✓ Brush your teeth properly 🦷\n'
            '✓ Drink a glass of water 💧\n'
            '✓ Sleep well and dream big! 💤';

      case SafetyContext.crossing:
        return 'Beta, please be very careful crossing the road! 🚦\n'
            'Wait for the green signal.\n'
            'Look both ways before crossing.\n'
            'Your safety is my priority. 💚';

      case SafetyContext.dizzy:
        return 'Oh no, you\'re feeling dizzy? 😟\n'
            'Listen carefully:\n'
            '✓ Sit down immediately in a safe place\n'
            '✓ Drink some water slowly\n'
            '✓ Breathe deeply and calmly\n'
            '✓ If it doesn\'t improve, call your parents right away\n'
            'Your health matters most! 💚';

      default:
        return 'Remember to wash your hands regularly. 🧼\n'
            'Health is the most valuable treasure you have! 💚';
    }
  }

  String _generateCaringHindi(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'बेटा, खाना खाने से पहले हाथ धो लो। 🧼\n'
            'यह तुम्हें कीटाणुओं से बचाता है और तुम्हें स्वस्थ रखता है।\n'
            'स्वास्थ्य ही धन है, याद रखो? 💚';

      case SafetyContext.outdoor:
        return 'मैं तुम्हारी परवाह करता हूं, इसलिए बाहर जाने से पहले:\n'
            '✓ मास्क ले जाना\n'
            '✓ रूमाल ले जाना\n'
            '✓ बाहर ठंड लग रही है, जैकेट ले जाना 🧥\n'
            '✓ फोन मत भूलना\n'
            'सुरक्षित रहो और मजे करो! 🌞';

      case SafetyContext.sleeping:
        return 'सोने से पहले, मेरे प्यारे:\n'
            '✓ मुंह और पैर धो लो 🛁\n'
            '✓ दांतों को ठीक से ब्रश कर 🦷\n'
            '✓ एक गिलास पानी पी 💧\n'
            '✓ अच्छी नींद आए! 💤';

      case SafetyContext.crossing:
        return 'बेटा, सड़क पार करते समय बहुत सावधान रहो! 🚦\n'
            'हरी बत्ती का इंतज़ार कर।\n'
            'दोनों तरफ देख कर पार कर।\n'
            'तुम्हारी सुरक्षा मेरी प्राथमिकता है। 💚';

      case SafetyContext.dizzy:
        return 'अरे, तुम्हें चक्कर आ रहे हैं? 😟\n'
            'ध्यान से सुनो:\n'
            '✓ तुरंत एक सुरक्षित जगह बैठ जाओ\n'
            '✓ धीरे-धीरे पानी पी\n'
            '✓ गहरी सांस ले\n'
            '✓ अगर ठीक न हो तो अपने माता-पिता को फोन कर\n'
            'तुम्हारी सेहत सबसे जरूरी है! 💚';

      default:
        return 'नियमित रूप से हाथ धोना मत भूलो। 🧼\n'
            'स्वास्थ्य ही सबसे बड़ा धन है! 💚';
    }
  }

  String _generateCaringHinglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Beta, khana khane se pehle hath dho le. 🧼\n'
            'Yeh tum्हein kitanuon se bachata hai aur tum्हein swasth rakhta hai.\n'
            'Swasthya hi dhan hai, yaad rakho? 💚';

      case SafetyContext.outdoor:
        return 'Main tumhari parvah karta hoon, isliye bahar jane se pehle:\n'
            '✓ Mask le jana\n'
            '✓ Rumaal le jana\n'
            '✓ Bahar thandi lag rahi hai, jacket le jana 🧥\n'
            '✓ Phone mat bhulna\n'
            'Surakshit raho aur maze karo! 🌞';

      case SafetyContext.sleeping:
        return 'Sone se pehle, mere pyare:\n'
            '✓ Muh aur pair dho le 🛁\n'
            '✓ Danton ko thik se brush kar 🦷\n'
            '✓ Ek glas pani pi 💧\n'
            '✓ Achi need aaye! 💤';

      case SafetyContext.crossing:
        return 'Beta, sadak par karte samay bahut savdhan raho! 🚦\n'
            'Hari batti ka intezaar kar.\n'
            'Donon taraf dekh kar par kar.\n'
            'Tumhari suraksha meri prathamikta hai. 💚';

      case SafetyContext.dizzy:
        return 'Are, tumhe chakkar aa rahe hain? 😟\n'
            'Dhyan se suno:\n'
            '✓ Turant ek surakshit jagah baith jao\n'
            '✓ Dhire-dhire pani pi\n'
            '✓ Gahari sans le\n'
            '✓ Agar theek na ho to apne mata-pita ko phone kar\n'
            'Tumhari sehat sabse zaroori hai! 💚';

      default:
        return 'Niyamit roop se hath dhona mat bhulo. 🧼\n'
            'Swasthya hi sabse bada dhan hai! 💚';
    }
  }

  // ───────────────────────────────────────────────────────────────
  // FRIENDLY TONE (TEENAGERS)
  // ───────────────────────────────────────────────────────────────

  String _generateFriendlyEnglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Quick reminder: wash your hands before eating! 🧼\n'
            'Keep yourself healthy and active. Stay strong! 💪';

      case SafetyContext.outdoor:
        return 'Heading out? Smart move to prepare:\n'
            '• Mask in pocket\n'
            '• Check the weather - might need a jacket 🧥\n'
            '• Phone charged\n'
            '• Umbrella if needed ☂️\n'
            'Have a great time out there! 🌞';

      case SafetyContext.sleeping:
        return 'Before hitting the bed:\n'
            '• Quick wash up 🛁\n'
            '• Brush teeth properly 🦷\n'
            '• Hydrate yourself 💧\n'
            'Sleep well and recharge! 💤';

      case SafetyContext.crossing:
        return 'When crossing the road, stay alert! 🚦\n'
            'Your safety is important. Look both ways, wait for the signal.\n'
            'Stay safe! 💚';

      case SafetyContext.breathless:
        return 'Feeling breathless? Let\'s fix this:\n'
            '✓ Stop what you\'re doing\n'
            '✓ Sit down in a comfortable place\n'
            '✓ Take deep, slow breaths\n'
            '✓ If it continues, contact your parents\n'
            'Your health matters! 💚';

      default:
        return 'Remember: regular handwashing keeps you healthy! 🧼\n'
            'Health is wealth - invest in yourself! 💚';
    }
  }

  String _generateFriendlyHindi(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'जल्दी याद दिला दूं: खाने से पहले हाथ धो लो! 🧼\n'
            'अपने आप को स्वस्थ रखो। मजबूत रहो! 💪';

      case SafetyContext.outdoor:
        return 'बाहर जा रहे हो? अच्छा किया तैयारी करने का:\n'
            '• मास्क साथ रखो\n'
            '• मौसम देख लो - जैकेट चाहिए हो सकता है 🧥\n'
            '• फोन चार्ज है\n'
            '• छाता भी ले लो अगर जरूरत हो ☂️\n'
            'बाहर मजे करो! 🌞';

      case SafetyContext.sleeping:
        return 'सोने से पहले:\n'
            '• जल्दी से धो-पछ 🛁\n'
            '• दांत अच्छे से ब्रश कर 🦷\n'
            '• पानी पी 💧\n'
            'अच्छी नींद ले! 💤';

      case SafetyContext.crossing:
        return 'सड़क पार करते समय सतर्क रहो! 🚦\n'
            'तुम्हारी सुरक्षा महत्वपूर्ण है। दोनों तरफ देख, सिग्नल का इंतजार कर।\n'
            'सुरक्षित रहो! 💚';

      case SafetyContext.breathless:
        return 'सांस लेने में दिक्कत? ठीक करते हैं:\n'
            '✓ जो कर रहे हो वह रोक दो\n'
            '✓ आरामदायक जगह बैठ जाओ\n'
            '✓ गहरी सांसें ले\n'
            '✓ अगर बंद न हो तो माता-पिता को बता\n'
            'तुम्हारी सेहत महत्वपूर्ण है! 💚';

      default:
        return 'याद रखो: नियमित हाथ धुलाई तुम्हें स्वस्थ रखती है! 🧼\n'
            'स्वास्थ्य ही धन है! 💚';
    }
  }

  String _generateFriendlyHinglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Jaldi yaad dila du: khane se pehle hath dho lo! 🧼\n'
            'Apne aap ko swasth rakho. Mazboot raho! 💪';

      case SafetyContext.outdoor:
        return 'Bahar ja rahe ho? Accha kiya tayyari karne ka:\n'
            '• Mask saath rakho\n'
            '• Mausam dekh lo - jacket chahiye ho sakta hai 🧥\n'
            '• Phone charge hai\n'
            '• Chhata bhi le lo agar zaroori ho ☂️\n'
            'Bahar maze karo! 🌞';

      case SafetyContext.sleeping:
        return 'Sone se pehle:\n'
            '• Jaldi se dho-pachh 🛁\n'
            '• Dant achche se brush kar 🦷\n'
            '• Pani pi 💧\n'
            'Achi need le! 💤';

      case SafetyContext.crossing:
        return 'Sadak par karte samay satark raho! 🚦\n'
            'Tumhari suraksha zaroori hai. Donon taraf dekh, signal ka intezaar kar.\n'
            'Surakshit raho! 💚';

      case SafetyContext.breathless:
        return 'Sans lene mein dikkat? Theek karte hain:\n'
            '✓ Jo kar rahe ho woh rok do\n'
            '✓ Aaramdayak jagah baith jao\n'
            '✓ Gahri sanson le\n'
            '✓ Agar band na ho to mata-pita ko bata\n'
            'Tumhari sehat zaroori hai! 💚';

      default:
        return 'Yaad rakho: niyamit hath dhulai tumhe swasth rakhti hai! 🧼\n'
            'Swasthya hi dhan hai! 💚';
    }
  }

  // ───────────────────────────────────────────────────────────────
  // CONCERNED TONE (ADULTS)
  // ───────────────────────────────────────────────────────────────

  String _generateConcernedEnglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'I have a humble request: please wash your hands before eating. 🧼\n'
            'Enjoy your meal. I\'ll be here waiting to chat after you\'re done. 😊';

      case SafetyContext.outdoor:
        return 'I care about your well-being.\n'
            'Before stepping out:\n'
            '→ Check weather conditions\n'
            '→ Dress appropriately 🧥\n'
            '→ Keep essential items with you\n'
            '→ Stay safe and hydrated 💧\n'
            'Take care of yourself! 💚';

      case SafetyContext.sleeping:
        return 'As you prepare for rest, may I suggest:\n'
            '✓ Freshen up and hydrate 💧\n'
            '✓ Create a peaceful environment\n'
            '✓ Get adequate sleep - your body needs it\n'
            'Rest well. 💤';

      case SafetyContext.crossing:
        return 'Please exercise caution at busy intersections. 🚦\n'
            'Your safety is paramount. \n'
            'Follow traffic signals and stay alert. 💚';

      case SafetyContext.dizzy:
        return 'I notice you\'re experiencing dizziness. 😟\n'
            'Please:\n'
            '→ Sit down in a safe location immediately\n'
            '→ Drink water slowly\n'
            '→ Breathe deeply and calmly\n'
            '→ Contact medical assistance if it persists\n'
            'Your health is important. 💚';

      case SafetyContext.breathless:
        return 'I\'m concerned about your breathing difficulties. 😟\n'
            'Immediate steps:\n'
            '→ Stop current activity\n'
            '→ Sit comfortably\n'
            '→ Take slow, deep breaths\n'
            '→ Contact your physician or emergency services\n'
            'Please take care of yourself. 💚';

      default:
        return 'I care about your well-being.\n'
            'Remember to maintain basic hygiene and health practices. 💚\n'
            'Your wellness matters. 🙏';
    }
  }

  String _generateConcernedHindi(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'मेरी विनम्र प्रार्थना है: खाने से पहले हाथ धो लो। 🧼\n'
            'अपना भोजन का आनंद लो। मैं तुम्हारे लिए यहां हूं। 😊';

      case SafetyContext.outdoor:
        return 'मैं तुम्हारी भलाई की चिंता करता हूं।\n'
            'बाहर जाने से पहले:\n'
            '→ मौसम देख लो\n'
            '→ उपयुक्त कपड़े पहन 🧥\n'
            '→ जरूरी चीजें ले जाना\n'
            '→ सुरक्षित और हाइड्रेटेड रहो 💧\n'
            'अपना ख्याल रखो! 💚';

      case SafetyContext.sleeping:
        return 'आराम की तैयारी करते समय, मैं सुझाव दूं:\n'
            '✓ ताजा हो जाओ और पानी पी 💧\n'
            '✓ शांतिपूर्ण माहौल बनाओ\n'
            '✓ पर्याप्त नींद ले - तुम्हारे शरीर को इसकी जरूरत है\n'
            'अच्छी नींद आए। 💤';

      case SafetyContext.crossing:
        return 'व्यस्त चौराहों पर सावधानी बरतो। 🚦\n'
            'तुम्हारी सुरक्षा सर्वोपरि है।\n'
            'ट्रैफिक नियमों का पालन करो। 💚';

      case SafetyContext.dizzy:
        return 'मुझे पता चल रहा है कि तुम्हें चक्कर आ रहे हैं। 😟\n'
            'कृपया:\n'
            '→ तुरंत एक सुरक्षित जगह बैठ जाओ\n'
            '→ धीरे-धीरे पानी पी\n'
            '→ गहरी सांस लो\n'
            '→ अगर बंद न हो तो डॉक्टर के पास जाओ\n'
            'तुम्हारी सेहत महत्वपूर्ण है। 💚';

      case SafetyContext.breathless:
        return 'मैं तुम्हारी सांस की समस्या से चिंतित हूं। 😟\n'
            'तुरंत कदम:\n'
            '→ वर्तमान काम रोक दो\n'
            '→ आरामदायक बैठ जाओ\n'
            '→ धीमी गहरी सांसें लो\n'
            '→ डॉक्टर या आपातकाल सेवा से संपर्क करो\n'
            'कृपया अपना ख्याल रखो। 💚';

      default:
        return 'मैं तुम्हारी भलाई की चिंता करता हूं।\n'
            'मूल स्वच्छता और स्वास्थ्य प्रथाओं का पालन करो। 💚\n'
            'तुम्हारा स्वास्थ्य महत्वपूर्ण है। 🙏';
    }
  }

  String _generateConcernedHinglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.eating:
        return 'Meri vinram prarthna hai: khne se pehle hath dho lo. 🧼\n'
            'Apna bhojan ka anand lo. Main tumhare liye yahan hoon. 😊';

      case SafetyContext.outdoor:
        return 'Main tumhari bhali ki chinta karta hoon.\n'
            'Bahar jane se pehle:\n'
            '→ Mausam dekh lo\n'
            '→ Upyukt kapde pehan 🧥\n'
            '→ Zaroori chize le jana\n'
            '→ Surakshit aur hydrated raho 💧\n'
            'Apna khyal rakho! 💚';

      case SafetyContext.sleeping:
        return 'Aaram ki tayyari karte samay, main sujhav du:\n'
            '✓ Taja ho jao aur pani pi 💧\n'
            '✓ Shantipurn mohol banao\n'
            '✓ Paryapt need le - tumhare sharir ko iski zaroori hai\n'
            'Achi need aaye. 💤';

      case SafetyContext.crossing:
        return 'Vyast chaurahon par savdhani barto. 🚦\n'
            'Tumhari suraksha sarvopari hai.\n'
            'Traffic niyamon ka paln karo. 💚';

      case SafetyContext.dizzy:
        return 'Mujhe pata chal raha hai ki tumhe chakkar aa rahe hain. 😟\n'
            'Krpya:\n'
            '→ Turant ek surakshit jagah baith jao\n'
            '→ Dhire-dhire pani pi\n'
            '→ Gahri sans lo\n'
            '→ Agar band na ho to doctor ke pas jao\n'
            'Tumhari sehat zaroori hai. 💚';

      case SafetyContext.breathless:
        return 'Main tumhari sans ki samasya se chintit hoon. 😟\n'
            'Turant kadam:\n'
            '→ Vartman kaam rok do\n'
            '→ Aaramdayak baith jao\n'
            '→ Dhim gahri sanson lo\n'
            '→ Doctor ya aapatkaal seva se sampark karo\n'
            'Krpya apna khyal rakho. 💚';

      default:
        return 'Main tumhari bhali ki chinta karta hoon.\n'
            'Mul svchhta aur swasth prathaon ka paln karo. 💚\n'
            'Tumhara swasth zaroori hai. 🙏';
    }
  }

  // ───────────────────────────────────────────────────────────────
  // STRICT TONE (EMERGENCY)
  // ───────────────────────────────────────────────────────────────

  String _generateStrictEnglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.crossing:
        return '⚠️ STOP! Do not cross the road while talking to me!\n'
            'Move to a safe location IMMEDIATELY.\n'
            'Your safety is non-negotiable.\n'
            'Once you\'re safe, we can talk. 🚦';

      case SafetyContext.dizzy:
      case SafetyContext.breathless:
        return '⚠️ This is serious. STOP everything.\n'
            'Sit down NOW in a safe place.\n'
            '1. Breathe slowly and deeply\n'
            '2. Drink water\n'
            '3. Contact emergency services: 112 or your parents\n'
            'DO NOT IGNORE THIS. Your life matters! 💚';

      case SafetyContext.emergency:
        return '🚨 EMERGENCY DETECTED!\n'
            'I will not continue our conversation until you are SAFE.\n'
            '→ Call emergency services (112)\n'
            '→ Contact your parents immediately\n'
            '→ Move to safety NOW\n'
            'Your safety is my priority! 💚';

      default:
        return '⚠️ This is not the time for casual conversation.\n'
            'Please ensure you are in a safe place.\n'
            'Once you\'re safe, we can talk properly. 💚';
    }
  }

  String _generateStrictHindi(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.crossing:
        return '⚠️ रुको! मेरे साथ बातें करते हुए सड़क मत पार करो!\n'
            'तुरंत एक सुरक्षित जगह जाओ।\n'
            'तुम्हारी सुरक्षा समझौता योग्य नहीं है।\n'
            'एक बार सुरक्षित हो जाओ, फिर बातें करेंगे। 🚦';

      case SafetyContext.dizzy:
      case SafetyContext.breathless:
        return '⚠️ यह गंभीर है। सब कुछ रोक दो।\n'
            'अभी बैठ जाओ एक सुरक्षित जगह।\n'
            '1. धीरे-धीरे गहरी सांसें लो\n'
            '2. पानी पी\n'
            '3. आपातकाल सेवा को कॉल करो: 112 या माता-पिता\n'
            'इसे नज़रअंदाज़ मत करो। तुम्हारी जान महत्वपूर्ण है! 💚';

      case SafetyContext.emergency:
        return '🚨 आपातकाल!\n'
            'मैं तब तक बातें नहीं करूंगा जब तक तुम सुरक्षित न हो।\n'
            '→ आपातकाल सेवा को कॉल करो (112)\n'
            '→ तुरंत अपने माता-पिता को कॉल करो\n'
            '→ अभी सुरक्षित जगह जाओ\n'
            'तुम्हारी सुरक्षा मेरी प्राथमिकता है! 💚';

      default:
        return '⚠️ यह आकस्मिक बातचीत का समय नहीं है।\n'
            'सुनिश्चित करो कि तुम एक सुरक्षित जगह हो।\n'
            'एक बार सुरक्षित हो, तो ठीक से बातें करेंगे। 💚';
    }
  }

  String _generateStrictHinglish(HealthContext context) {
    switch (context.safetyContext) {
      case SafetyContext.crossing:
        return '⚠️ Ruko! Mere saath baatein karte hue sadak mat par karo!\n'
            'Turant ek surakshit jagah jao.\n'
            'Tumhari suraksha compromise nahi hogi.\n'
            'Ek baar surakshit ho jao, phir baatein karenge. 🚦';

      case SafetyContext.dizzy:
      case SafetyContext.breathless:
        return '⚠️ Yeh gambhir hai. Sab kuch rok do.\n'
            'Abhi baith jao ek surakshit jagah.\n'
            '1. Dhire-dhire gahri sanson lo\n'
            '2. Pani pi\n'
            '3. Aapatkaal seva ko call karo: 112 ya mata-pita\n'
            'Isko neglect mat karo. Tumhari jaan zaroori hai! 💚';

      case SafetyContext.emergency:
        return '🚨 Aapatkaal!\n'
            'Main tab tak baatein nahi karunga jab tak tum surakshit na ho.\n'
            '→ Aapatkaal seva ko call karo (112)\n'
            '→ Turant apne mata-pita ko call karo\n'
            '→ Abhi surakshit jagah jao\n'
            'Tumhari suraksha meri prathamikta hai! 💚';

      default:
        return '⚠️ Yeh casual batcheet ka samay nahi hai.\n'
            'Sunischit karo ki tum ek surakshit jagah ho.\n'
            'Ek baar surakshit ho, tab thik se baatein karenge. 💚';
    }
  }

  // ───────────────────────────────────────────────────────────────
  // UTILITY METHODS
  // ───────────────────────────────────────────────────────────────

  bool _isRiskyContext(SafetyContext context) {
    return context == SafetyContext.crossing ||
        context == SafetyContext.dizzy ||
        context == SafetyContext.breathless ||
        context == SafetyContext.emergency;
  }

  String _getContextDescription(SafetyContext context) {
    switch (context) {
      case SafetyContext.normal:
        return 'Regular conversation';
      case SafetyContext.outdoor:
        return 'User going outside';
      case SafetyContext.crossing:
        return 'User crossing street - HIGH PRIORITY';
      case SafetyContext.dizzy:
        return 'User feeling dizzy - URGENT';
      case SafetyContext.breathless:
        return 'User having breathing difficulty - URGENT';
      case SafetyContext.eating:
        return 'User about to eat';
      case SafetyContext.sleeping:
        return 'User about to sleep';
      case SafetyContext.emergency:
        return 'Emergency situation - CRITICAL';
    }
  }

  List<HealthReminderType> _getApplicableReminders(
    SafetyContext context,
    AgeGroup age,
  ) {
    final reminders = <HealthReminderType>[];

    switch (context) {
      case SafetyContext.eating:
        reminders.add(HealthReminderType.handWashing);
        reminders.add(HealthReminderType.hygiene);
        reminders.add(HealthReminderType.nutrition);
        break;

      case SafetyContext.outdoor:
        reminders.add(HealthReminderType.outdoor);
        reminders.add(HealthReminderType.weather);
        break;

      case SafetyContext.sleeping:
        reminders.add(HealthReminderType.hygiene);
        reminders.add(HealthReminderType.hydration);
        reminders.add(HealthReminderType.sleep);
        break;

      case SafetyContext.crossing:
      case SafetyContext.dizzy:
      case SafetyContext.breathless:
      case SafetyContext.emergency:
        reminders.add(HealthReminderType.emergency);
        break;

      default:
        reminders.add(HealthReminderType.hygiene);
    }

    return reminders;
  }

  final _ruflo = RuFloService();

  Future<VoiceHealthReport?> analyzeVoiceHealth(
    Map<String, double> voiceFeatures,
    String userId,
  ) async {
    try {
      final result = await _ruflo.callTool('voice_health_analyzer', {
        'features': voiceFeatures,
        'userId': userId,
        'date': DateTime.now().toIso8601String(),
      });

      final anomaly = result['anomaly'] as String?;
      if (anomaly != null && anomaly != 'none') {
        await _ruflo.memoryStore(
          namespace: 'voice_health_$userId',
          key: 'health_${DateTime.now().millisecondsSinceEpoch}',
          value: {'anomaly': anomaly, 'features': voiceFeatures},
        );
        return VoiceHealthReport(
          anomaly: anomaly,
          advice: result['advice'] as String?,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class VoiceHealthReport {
  final String anomaly;
  final String? advice;

  const VoiceHealthReport({required this.anomaly, this.advice});
}

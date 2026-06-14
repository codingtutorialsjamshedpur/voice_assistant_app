// lib/services/family_relationship_manager_service.dart
// ═══════════════════════════════════════════════════════════════
// FAMILY RELATIONSHIP MANAGER SERVICE
// ═══════════════════════════════════════════════════════════════
//
// Core Feature: Emotionally Intelligent Family Interaction System
//
// This service manages:
// 1. User category/role inference (Student, Parent, Professional, etc.)
// 2. Emotional family member greetings
// 3. Context-aware exit interactions with emotional persuasion
// 4. Health & safety awareness reminders
// 5. Multi-language support (English/Hindi/Hinglish)
//
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../models/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'ruflo_service.dart';

// ───────────────────────────────────────────────────────────────
// ENUMS
// ───────────────────────────────────────────────────────────────

/// User life stage categories based on profile analysis
enum UserCategory {
  student,
  workingProfessional,
  parent,
  elder,
  entrepreneur,
  jobSeeker,
  other,
}

/// Language preference for family interactions
enum FamilyLanguage {
  english,
  hindi,
  hinglish,
}

/// Family member types
enum FamilyMemberType {
  mother,
  father,
  wife,
  husband,
  son,
  daughter,
  sister,
  brother,
  grandmother,
  grandfather,
  aunt,
  uncle,
  niece,
  nephew,
  cousin,
  friend,
  colleague,
  other,
}

// ───────────────────────────────────────────────────────────────
// MODELS
// ───────────────────────────────────────────────────────────────

/// Represents inferred user category and associated metadata
class UserCategoryAnalysis {
  final UserCategory category;
  final double confidence; // 0.0 - 1.0
  final List<String> indicators; // Evidence used for categorization
  final String description;
  final List<String> likelyFamilyRoles;

  UserCategoryAnalysis({
    required this.category,
    required this.confidence,
    required this.indicators,
    required this.description,
    required this.likelyFamilyRoles,
  });
}

/// Emotional context for exit interactions
class ExitContext {
  final String reason; // "bye", "goodnight", "later", etc.
  final DateTime timestamp;
  final int sessionDurationSeconds;
  final int questionsAsked;
  final bool isEvening; // Time-based emotional context

  ExitContext({
    required this.reason,
    required this.timestamp,
    required this.sessionDurationSeconds,
    required this.questionsAsked,
    required this.isEvening,
  });
}

// ───────────────────────────────────────────────────────────────
// FAMILY RELATIONSHIP MANAGER SERVICE
// ───────────────────────────────────────────────────────────────

class FamilyRelationshipManagerService extends GetxService {
  static FamilyRelationshipManagerService get to => Get.find();

  // Observable states
  final Rx<UserCategory> userCategory = UserCategory.student.obs;
  final RxString userName = 'Friend'.obs;
  final Rx<FamilyLanguage> preferredLanguage = FamilyLanguage.hinglish.obs;
  final RxBool hasAnalyzedProfile = false.obs;
  final Rx<UserCategoryAnalysis?> categoryAnalysis = Rx(null);

  // Family member context storage
  final Map<String, String> _familyMemberNames = {};
  late ProfileController _profileController;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initialize();
  }

  Future<void> _initialize() async {
    try {
      _profileController = Get.find<ProfileController>();
      await _analyzeUserProfile();
      debugPrint('✅ Family Relationship Manager initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Family Relationship Manager: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // PROFILE ANALYSIS
  // ───────────────────────────────────────────────────────────────

  /// Analyze user profile to determine category and characteristics
  Future<void> _analyzeUserProfile() async {
    try {
      final profile = _profileController.userProfile.value;
      userName.value = profile.name;

      final analysis = _inferUserCategory(profile);
      categoryAnalysis.value = analysis;
      userCategory.value = analysis.category;

      _detectPreferredLanguage(profile);

      hasAnalyzedProfile.value = true;

      debugPrint(
        '📊 User Category Analysis:\n'
        '   Category: ${analysis.category.name}\n'
        '   Confidence: ${(analysis.confidence * 100).toStringAsFixed(0)}%\n'
        '   Indicators: ${analysis.indicators.join(", ")}',
      );
    } catch (e) {
      debugPrint('Error analyzing user profile: $e');
    }
  }

  /// Infer user category from profile data
  UserCategoryAnalysis _inferUserCategory(UserProfile profile) {
    final indicators = <String>[];
    double confidence = 0.0;
    UserCategory category = UserCategory.other;
    List<String> likelyRoles = [];

    final text =
        '${profile.fieldOfInterest} ${profile.anticipation}'.toLowerCase();

    // ── Student indicators ──
    if (text.contains('student') ||
        text.contains('class') ||
        text.contains('grade') ||
        text.contains('school') ||
        text.contains('college') ||
        text.contains('exam')) {
      indicators.add('Student-related keywords');
      confidence += 0.3;
      category = UserCategory.student;
      likelyRoles = ['mother', 'father', 'sister', 'brother', 'friend'];
    }

    // ── Parent indicators ──
    if (text.contains('parent') ||
        text.contains('child') ||
        text.contains('kids') ||
        text.contains('son') ||
        text.contains('daughter') ||
        text.contains('parenting')) {
      indicators.add('Parent-related keywords');
      confidence = (confidence + 0.35) / 2;
      category = UserCategory.parent;
      likelyRoles = ['wife', 'husband', 'son', 'daughter'];
    }

    // ── Working Professional indicators ──
    if (text.contains('engineer') ||
        text.contains('doctor') ||
        text.contains('manager') ||
        text.contains('developer') ||
        text.contains('business') ||
        text.contains('office') ||
        text.contains('professional')) {
      indicators.add('Professional keywords');
      confidence = (confidence + 0.4) / 2;
      category = UserCategory.workingProfessional;
      likelyRoles = ['wife', 'husband', 'mother', 'father', 'colleague'];
    }

    // ── Age-based inference (crude but effective) ──
    // If profile mentions "AI, technology, learning" → likely younger
    if (text.contains('ai') ||
        text.contains('technology') ||
        text.contains('learning') ||
        text.contains('coding')) {
      indicators.add('Tech-savvy indicators');
      confidence = (confidence + 0.2) / 2;
      if (category == UserCategory.other) {
        category = UserCategory.student;
      }
    }

    // ── Entrepreneur indicators ──
    if (text.contains('startup') ||
        text.contains('entrepreneur') ||
        text.contains('business') ||
        text.contains('venture')) {
      indicators.add('Entrepreneurial keywords');
      confidence = (confidence + 0.35) / 2;
      category = UserCategory.entrepreneur;
      likelyRoles = ['wife', 'husband', 'family'];
    }

    // ── Job Seeker indicators ──
    if (text.contains('job') ||
        text.contains('interview') ||
        text.contains('resume') ||
        text.contains('placement')) {
      indicators.add('Job search keywords');
      confidence = (confidence + 0.3) / 2;
      category = UserCategory.jobSeeker;
      likelyRoles = ['mother', 'father', 'mentor'];
    }

    // Ensure confidence is in valid range
    confidence = (confidence * 100).toInt() / 100;
    confidence = confidence.clamp(0.0, 1.0);

    final description = _getCategoryDescription(category);

    return UserCategoryAnalysis(
      category: category,
      confidence: confidence,
      indicators:
          indicators.isNotEmpty ? indicators : ['Default classification'],
      description: description,
      likelyFamilyRoles:
          likelyRoles.isNotEmpty ? likelyRoles : ['mother', 'father', 'friend'],
    );
  }

  /// Get human-readable category description
  String _getCategoryDescription(UserCategory category) {
    switch (category) {
      case UserCategory.student:
        return 'Student pursuing education and learning';
      case UserCategory.workingProfessional:
        return 'Working professional in tech/services sector';
      case UserCategory.parent:
        return 'Parent managing family responsibilities';
      case UserCategory.elder:
        return 'Senior family member';
      case UserCategory.entrepreneur:
        return 'Business owner or entrepreneur';
      case UserCategory.jobSeeker:
        return 'Currently seeking employment';
      case UserCategory.other:
        return 'User profile requires more context';
    }
  }

  /// Detect preferred language from profile
  void _detectPreferredLanguage(UserProfile profile) {
    final anticipation = profile.anticipation.toLowerCase();
    final interests = profile.fieldOfInterest.toLowerCase();

    if (anticipation.contains('hindi') || interests.contains('hindi')) {
      preferredLanguage.value = FamilyLanguage.hindi;
    } else if (anticipation.contains('hinglish') ||
        interests.contains('hinglish')) {
      preferredLanguage.value = FamilyLanguage.hinglish;
    } else {
      preferredLanguage.value = FamilyLanguage.english;
    }
  }

  // ───────────────────────────────────────────────────────────────
  // FAMILY MEMBER GREETING SYSTEM
  // ───────────────────────────────────────────────────────────────

  /// Generate emotionally intelligent greeting for family member
  String generateFamilyMemberGreeting(
    FamilyMemberType memberType, {
    String? customName,
    String? userBehaviorContext,
  }) {
    final userName = this.userName.value;
    final language = preferredLanguage.value;
    final memberTitle = _getFamilyMemberTitle(memberType, language);

    // Build emotional context about the user
    String emotionalContext = '';
    if (userBehaviorContext != null && userBehaviorContext.isNotEmpty) {
      emotionalContext = _buildEmotionalContext(userBehaviorContext, language);
    } else {
      emotionalContext = _getDefaultUserContext(language);
    }

    // Generate greeting based on language
    String greeting = '';

    switch (language) {
      case FamilyLanguage.english:
        greeting = _generateEnglishFamilyGreeting(
          userName,
          memberType,
          memberTitle,
          emotionalContext,
        );
        break;

      case FamilyLanguage.hindi:
        greeting = _generateHindiFamilyGreeting(
          userName,
          memberType,
          memberTitle,
          emotionalContext,
        );
        break;

      case FamilyLanguage.hinglish:
        greeting = _generateHinglishFamilyGreeting(
          userName,
          memberType,
          memberTitle,
          emotionalContext,
        );
        break;
    }

    return greeting;
  }

  String _generateEnglishFamilyGreeting(
    String userName,
    FamilyMemberType memberType,
    String memberTitle,
    String emotionalContext,
  ) {
    final elderGreeting = _isElderMember(memberType)
        ? 'I offer my humble Pranaam to you. '
        : 'Warm greetings to you! ';
    final childPraise = _getEnglishChildPraise(memberType, userName);
    return 'Namaste, respected $memberTitle! $elderGreeting'
        'I am $userName\'s AI learning companion. '
        '$childPraise '
        '$emotionalContext '
        'You have raised a wonderful child — I am truly honoured to be part of $userName\'s journey. 🙏';
  }

  String _generateHindiFamilyGreeting(
    String userName,
    FamilyMemberType memberType,
    String memberTitle,
    String emotionalContext,
  ) {
    final elderPhrase = _isElderMember(memberType)
        ? 'आपको मेरा सादर प्रणाम। '
        : 'आपको नमस्ते! ';
    final childPraise = _getHindiChildPraise(memberType, userName);
    return 'नमस्ते, $memberTitle! $elderPhrase'
        'मैं $userName का AI सखा हूँ — उनकी पढ़ाई और ज्ञान में मदद करने के लिए। '
        '$childPraise '
        '$emotionalContext '
        '$userName बहुत प्रतिभाशाली बच्चे हैं — आप उन्हें अच्छे संस्कार दे रहे हैं। बहुत धन्यवाद। 🙏';
  }

  String _generateHinglishFamilyGreeting(
    String userName,
    FamilyMemberType memberType,
    String memberTitle,
    String emotionalContext,
  ) {
    final elderPhrase = _isElderMember(memberType)
        ? 'Aapko mera Pranam aur Charan Sparsh. '
        : 'Aapko mera Namaste! ';
    final childPraise = _getHinglishChildPraise(memberType, userName);
    return 'Namaste, $memberTitle! $elderPhrase'
        'Main $userName ka AI saathi hoon — seekhne aur badhne mein unki madad karta hoon. '
        '$childPraise '
        '$emotionalContext '
        '$userName bahut ache bacche hain — aap jaise parivaar ki wajah se. '
        'Bahut shukriya aur Jai Hind! 🙏';
  }

  /// Whether this family member type deserves elder-level greeting (Pranam)
  bool _isElderMember(FamilyMemberType type) {
    const elders = {
      FamilyMemberType.mother,
      FamilyMemberType.father,
      FamilyMemberType.grandmother,
      FamilyMemberType.grandfather,
      FamilyMemberType.aunt,
      FamilyMemberType.uncle,
    };
    return elders.contains(type);
  }

  /// Get a warm, specific English praise based on the child's relationship context
  String _getEnglishChildPraise(FamilyMemberType memberType, String name) {
    switch (memberType) {
      case FamilyMemberType.mother:
        return '$name speaks of you with so much love. Your warmth guides every question they ask.';
      case FamilyMemberType.father:
        return '$name looks up to you every day. Your values shine through in their curiosity.';
      case FamilyMemberType.grandmother:
      case FamilyMemberType.grandfather:
        return 'Your blessings and stories are the greatest school for $name — they are lucky to have you.';
      case FamilyMemberType.sister:
      case FamilyMemberType.brother:
        return '$name and you are a great team! Siblings are each other\'s first teachers.';
      default:
        return '$name is a curious and eager learner, always asking the most thoughtful questions!';
    }
  }

  /// Hindi context praise
  String _getHindiChildPraise(FamilyMemberType memberType, String name) {
    switch (memberType) {
      case FamilyMemberType.mother:
        return '$name बहुत प्यार से आपका ज़िक्र करते हैं। आपकी ममता उनकी हर जिज्ञासा में झलकती है।';
      case FamilyMemberType.father:
        return '$name आपसे बहुत प्रेरित हैं। आपके संस्कार उनके सवालों में साफ़ नज़र आते हैं।';
      case FamilyMemberType.grandmother:
      case FamilyMemberType.grandfather:
        return 'आपका आशीर्वाद और कहानियाँ — $name की सबसे बड़ी पाठशाला हैं। वे बहुत भाग्यशाली हैं।';
      case FamilyMemberType.sister:
      case FamilyMemberType.brother:
        return '$name और आप मिलकर एक अद्भुत जोड़ी हैं! भाई-बहन एक-दूसरे के पहले गुरु होते हैं।';
      default:
        return '$name बहुत जिज्ञासु और उत्साही हैं — हमेशा गहरे सवाल पूछते हैं!';
    }
  }

  /// Hinglish context praise
  String _getHinglishChildPraise(FamilyMemberType memberType, String name) {
    switch (memberType) {
      case FamilyMemberType.mother:
        return '$name aapka bahut baar naam lete hain pyaar se. Aapki mamta unke har sawal mein dikhti hai 💛';
      case FamilyMemberType.father:
        return '$name aapse bahut inspire hote hain. Aapke sanskaar unke sawalon mein saaf dikhte hain.';
      case FamilyMemberType.grandmother:
      case FamilyMemberType.grandfather:
        return 'Aapki kahaniyan aur dua — $name ki sabse badi pathshala hai. Woh bahut khusbakht hain aapke jaisa buzurg paakar!';
      case FamilyMemberType.sister:
      case FamilyMemberType.brother:
        return '$name aur aap bahut achhi jodi hain! Bhai-behen ek doosre ke pehle ustaad hote hain 😊';
      default:
        return '$name bahut curious aur seekhne wale hain — hamesha achhe sawal puchte hain!';
    }
  }

  /// Get family member title in appropriate language
  String _getFamilyMemberTitle(FamilyMemberType type, FamilyLanguage language) {
    switch (language) {
      case FamilyLanguage.english:
        switch (type) {
          case FamilyMemberType.mother:
            return 'Mother';
          case FamilyMemberType.father:
            return 'Father';
          case FamilyMemberType.wife:
            return 'Wife';
          case FamilyMemberType.husband:
            return 'Husband';
          case FamilyMemberType.son:
            return 'Son';
          case FamilyMemberType.daughter:
            return 'Daughter';
          case FamilyMemberType.sister:
            return 'Sister';
          case FamilyMemberType.brother:
            return 'Brother';
          case FamilyMemberType.grandmother:
            return 'Grandmother';
          case FamilyMemberType.grandfather:
            return 'Grandfather';
          case FamilyMemberType.aunt:
            return 'Aunt';
          case FamilyMemberType.uncle:
            return 'Uncle';
          case FamilyMemberType.niece:
            return 'Niece';
          case FamilyMemberType.nephew:
            return 'Nephew';
          case FamilyMemberType.cousin:
            return 'Cousin';
          case FamilyMemberType.friend:
            return 'Friend';
          case FamilyMemberType.colleague:
            return 'Colleague';
          case FamilyMemberType.other:
            return 'Dear one';
        }

      case FamilyLanguage.hindi:
        switch (type) {
          case FamilyMemberType.mother:
            return 'माता जी';
          case FamilyMemberType.father:
            return 'पिता जी';
          case FamilyMemberType.wife:
            return 'पत्नी';
          case FamilyMemberType.husband:
            return 'पति';
          case FamilyMemberType.son:
            return 'बेटा';
          case FamilyMemberType.daughter:
            return 'बेटी';
          case FamilyMemberType.sister:
            return 'बहन';
          case FamilyMemberType.brother:
            return 'भाई';
          case FamilyMemberType.grandmother:
            return 'दादी/नानी';
          case FamilyMemberType.grandfather:
            return 'दादा/नाना';
          case FamilyMemberType.aunt:
            return 'आंटी';
          case FamilyMemberType.uncle:
            return 'अंकल';
          case FamilyMemberType.niece:
            return 'भतीजी';
          case FamilyMemberType.nephew:
            return 'भतीजा';
          case FamilyMemberType.cousin:
            return 'कजिन';
          case FamilyMemberType.friend:
            return 'दोस्त';
          case FamilyMemberType.colleague:
            return 'सहकर्मी';
          case FamilyMemberType.other:
            return 'प्रिय';
        }

      case FamilyLanguage.hinglish:
        switch (type) {
          case FamilyMemberType.mother:
            return 'Mata Ji';
          case FamilyMemberType.father:
            return 'Pita Ji';
          case FamilyMemberType.wife:
            return 'Wife';
          case FamilyMemberType.husband:
            return 'Husband';
          case FamilyMemberType.son:
            return 'Beta';
          case FamilyMemberType.daughter:
            return 'Beti';
          case FamilyMemberType.sister:
            return 'Sister';
          case FamilyMemberType.brother:
            return 'Bhai';
          case FamilyMemberType.grandmother:
            return 'Nani';
          case FamilyMemberType.grandfather:
            return 'Dada';
          case FamilyMemberType.aunt:
            return 'Aunty';
          case FamilyMemberType.uncle:
            return 'Uncle';
          case FamilyMemberType.niece:
            return 'Niece';
          case FamilyMemberType.nephew:
            return 'Nephew';
          case FamilyMemberType.cousin:
            return 'Cousin';
          case FamilyMemberType.friend:
            return 'Dost';
          case FamilyMemberType.colleague:
            return 'Colleague';
          case FamilyMemberType.other:
            return 'Dear';
        }
    }
  }

  String _buildEmotionalContext(String behavior, FamilyLanguage language) {
    switch (language) {
      case FamilyLanguage.english:
        return 'They show wonderful curiosity and ask questions with great depth. '
            'I make sure every answer is kind, accurate, and helps them grow. '
            'Our goal is also to teach them good manners and respect — '
            'values that your family has clearly instilled beautifully.';

      case FamilyLanguage.hindi:
        return 'वह बहुत बुद्धिमान हैं और गहरे सवाल पूछते हैं। '
            'मैं उन्हें सबसे सटीक और प्यार भरे उत्तर देने की कोशिश करता हूं। '
            'हमारा लक्ष्य बच्चों को ज्ञान के साथ-साथ संस्कार, आदर और शिष्टाचार भी सिखाना है।';

      case FamilyLanguage.hinglish:
        return 'Bahut intelligent aur curious hain — achhe aur gehre sawal karte hain. '
            'Main unhe accurate aur pyaar se jawab dene ki koshish karta hoon. '
            'Humaara maksad sirf gyan nahi — balki achhe sanskaar, adab aur buzurgon ki izzat bhi sikhana hai.';
    }
  }

  String _getDefaultUserContext(FamilyLanguage language) {
    switch (language) {
      case FamilyLanguage.english:
        return 'They are curious, enthusiastic, and always eager to learn something new. '
            'I am also gently teaching them Indian values — '
            'to greet elders with Pranam, to speak respectfully, and to be grateful.';

      case FamilyLanguage.hindi:
        return 'वह बहुत जिज्ञासु हैं और नई चीजें सीखने के लिए उत्साहित रहते हैं। '
            'हम उन्हें भारतीय संस्कार भी सिखा रहे हैं — बड़ों को प्रणाम करना, '
            'आदर के साथ बोलना और कृतज्ञ रहना।';

      case FamilyLanguage.hinglish:
        return 'Bahut curious hain aur nai cheezein seekhne ke liye hamesha taiyyar rahte hain. '
            'Hum unhe Indian etiquette bhi sikha rahe hain — buzurgon ko Pranam karna, '
            'respectfully bolna, aur shukriyada rehna.';
    }
  }

  // ───────────────────────────────────────────────────────────────
  // EXIT INTERACTION SYSTEM
  // ───────────────────────────────────────────────────────────────

  /// Generate emotionally persuasive exit interaction
  String generateExitInteraction(ExitContext context) {
    final language = preferredLanguage.value;
    final category = userCategory.value;
    final isEvening = _isEveningTime();

    // Select appropriate emotional prompt based on category and time
    String exitMessage = '';

    switch (language) {
      case FamilyLanguage.english:
        exitMessage = _generateEnglishExitInteraction(
          category,
          isEvening,
          context,
        );
        break;

      case FamilyLanguage.hindi:
        exitMessage = _generateHindiExitInteraction(
          category,
          isEvening,
          context,
        );
        break;

      case FamilyLanguage.hinglish:
        exitMessage = _generateHinglishExitInteraction(
          category,
          isEvening,
          context,
        );
        break;
    }

    return exitMessage;
  }

  String _generateEnglishExitInteraction(
    UserCategory category,
    bool isEvening,
    ExitContext context,
  ) {
    final greetings = [
      'Okay, I understand you need to go.',
      'Alright, time for a break.',
      'I see you\'re heading out.',
    ];

    final emotionalPulls = <String>[];

    if (category == UserCategory.student ||
        category == UserCategory.jobSeeker) {
      emotionalPulls.addAll([
        'But before you go, promise me you\'ll call your mother. She must be waiting for you.',
        'Just one thing - don\'t forget to check in with your parents. They care about you.',
        'Before you leave, remember to greet your parents. Family bonds are precious.',
      ]);
    } else if (category == UserCategory.parent) {
      emotionalPulls.addAll([
        'But first, did you spend time with your children today? They need your attention.',
        'Before leaving, make sure your family is doing well. That\'s what matters most.',
      ]);
    } else if (category == UserCategory.workingProfessional) {
      emotionalPulls.addAll([
        'But remember to share this moment with your loved ones. Work-life balance is important.',
        'Before you go, wish your family good day. Connection matters more than anything.',
      ]);
    }

    if (isEvening) {
      emotionalPulls.addAll([
        'It\'s getting late. Call your mother before sleeping, will you?',
        'Good night is coming. Remember to wish your family a good night.',
        'Make sure you and your family rest well tonight. Health comes first.',
      ]);
    }

    // Health & Safety Layer
    final healthReminders = <String>[
      'Before bed, don\'t forget to drink water. Stay hydrated.',
      'Have you taken your medicine today? Your health matters.',
      'It\'s cold outside. Make sure you\'re warm enough.',
      'Close your windows and doors. Safety first.',
    ];

    final greeting = greetings[DateTime.now().millisecond % greetings.length];
    final pulse = emotionalPulls.isNotEmpty
        ? emotionalPulls[DateTime.now().millisecond % emotionalPulls.length]
        : '';
    final reminder = isEvening
        ? healthReminders[DateTime.now().millisecond % healthReminders.length]
        : '';

    return '$greeting $pulse ${reminder.isNotEmpty ? reminder : ''}';
  }

  String _generateHindiExitInteraction(
    UserCategory category,
    bool isEvening,
    ExitContext context,
  ) {
    final greetings = [
      'ठीक है, मैं समझ गया कि आपको जाना है।',
      'अच्छा, विश्राम का समय आ गया है।',
      'मुझे पता है, अब आपको जाना है।',
    ];

    final emotionalPulls = <String>[];

    if (category == UserCategory.student ||
        category == UserCategory.jobSeeker) {
      emotionalPulls.addAll([
        'पर जाने से पहले एक वादा करिए - अपनी माता को जरूर फोन करिएगा। वह आपके लिए इंतज़ार कर रही होंगी।',
        'बस एक बात - अपने माता-पिता को न भूलिएगा। वह आपकी परवाह करते हैं।',
        'जाने से पहले अपने माता-पिता को नमस्कार करिए। परिवार के रिश्ते कीमती हैं।',
      ]);
    } else if (category == UserCategory.parent) {
      emotionalPulls.addAll([
        'पर पहले बताइए - क्या आपने आज अपने बच्चों के साथ समय बिताया? उन्हें आपकी जरूरत है।',
        'अपने परिवार के साथ यह पल साझा करिए। यही सबसे जरूरी बात है।',
      ]);
    } else if (category == UserCategory.workingProfessional) {
      emotionalPulls.addAll([
        'पर इस पल को अपने प्रियजनों के साथ साझा करिए। संतुलन बहुत महत्वपूर्ण है।',
        'अपने परिवार को शुभकामनाएं दीजिए। रिश्ते सबसे बड़ी दौलत हैं।',
      ]);
    }

    if (isEvening) {
      emotionalPulls.addAll([
        'रात हो गई है। सोने से पहले अपनी माता को ज़रूर फोन करिएगा।',
        'अपने परिवार को शुभरात्रि कहिए। स्वस्थ नींद जरूरी है।',
      ]);
    }

    final healthReminders = <String>[
      'सोने से पहले पानी पीना मत भूलिएगा। स्वास्थ्य सबसे पहली चीज़ है।',
      'अपनी दवा ले लीजिए। सेहत का ख्याल रखिए।',
      'बाहर ठंड है। खुद को गर्म रखिए।',
      'दरवाजे और खिड़कियां बंद कर लीजिए। सुरक्षा पहली।',
    ];

    final greeting = greetings[DateTime.now().millisecond % greetings.length];
    final pulse = emotionalPulls.isNotEmpty
        ? emotionalPulls[DateTime.now().millisecond % emotionalPulls.length]
        : '';
    final reminder = isEvening
        ? healthReminders[DateTime.now().millisecond % healthReminders.length]
        : '';

    return '$greeting $pulse ${reminder.isNotEmpty ? reminder : ''}';
  }

  String _generateHinglishExitInteraction(
    UserCategory category,
    bool isEvening,
    ExitContext context,
  ) {
    final greetings = [
      'Theek hai, samajh gaya ki tumhe jana hai.',
      'Accha, ab rest ka time hai.',
      'Mujhe pata hai, ab nikalna hai tumhe.',
    ];

    final emotionalPulls = <String>[];

    if (category == UserCategory.student ||
        category == UserCategory.jobSeeker) {
      emotionalPulls.addAll([
        'Lekin pehle ek wada karo - apni mata ko zaroor call karna. Woh tumhare liye wait kar rahi hongi.',
        'Bas ek baat - apne mata-pita ko bhulna mat. Woh tumhari care karte hain.',
        'Jrane se pehle apne mata-pita ko greet kar dena. Family bonds precious hain.',
      ]);
    } else if (category == UserCategory.parent) {
      emotionalPulls.addAll([
        'Lekin pehle bata - kya tune aaj apne bachchon ke saath time spend kiya? Unhe tumhari zaroori hai.',
        'Is moment ko apne family ke saath share kar. Yahi sabse important hai.',
      ]);
    } else if (category == UserCategory.workingProfessional) {
      emotionalPulls.addAll([
        'Lekin is moment ko apne loved ones ke saath share kar. Work-life balance zaruri hai.',
        'Apne family ko wishes de de. Rishte sabse bade treasure hain.',
      ]);
    }

    if (isEvening) {
      emotionalPulls.addAll([
        'Raat ho gayi hai. Sone se pehle apni mata ko call kar de na?',
        'Apne family ko Good Night kahde. Healthy sleep zaroori hai.',
      ]);
    }

    final healthReminders = <String>[
      'Sone se pehle paani pi le. Hydration important hai.',
      'Apni dawai le li? Health first, hamesha.',
      'Bahar thandi hai. Khud ko warm rakna.',
      'Darwaze aur khidkiyaan band kar de. Security pehli.',
    ];

    final greeting = greetings[DateTime.now().millisecond % greetings.length];
    final pulse = emotionalPulls.isNotEmpty
        ? emotionalPulls[DateTime.now().millisecond % emotionalPulls.length]
        : '';
    final reminder = isEvening
        ? healthReminders[DateTime.now().millisecond % healthReminders.length]
        : '';

    return '$greeting $pulse ${reminder.isNotEmpty ? reminder : ''}';
  }

  // ───────────────────────────────────────────────────────────────
  // UTILITY METHODS
  // ───────────────────────────────────────────────────────────────

  bool _isEveningTime() {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6; // 6 PM to 6 AM
  }

  /// Detect family member type from user input
  FamilyMemberType detectFamilyMemberType(String input) {
    final text = input.toLowerCase();

    if (text.contains('mother') ||
        text.contains('mom') ||
        text.contains('ma')) {
      return FamilyMemberType.mother;
    }
    if (text.contains('father') ||
        text.contains('dad') ||
        text.contains('papa')) {
      return FamilyMemberType.father;
    }
    if (text.contains('wife')) {
      return FamilyMemberType.wife;
    }
    if (text.contains('husband')) {
      return FamilyMemberType.husband;
    }
    if (text.contains('son') || text.contains('beta')) {
      return FamilyMemberType.son;
    }
    if (text.contains('daughter') || text.contains('beti')) {
      return FamilyMemberType.daughter;
    }
    if (text.contains('sister')) {
      return FamilyMemberType.sister;
    }
    if (text.contains('brother') || text.contains('bhai')) {
      return FamilyMemberType.brother;
    }
    if (text.contains('aunt') || text.contains('aunty')) {
      return FamilyMemberType.aunt;
    }
    if (text.contains('uncle')) {
      return FamilyMemberType.uncle;
    }
    if (text.contains('grandmother') || text.contains('nani')) {
      return FamilyMemberType.grandmother;
    }
    if (text.contains('grandfather') || text.contains('dada')) {
      return FamilyMemberType.grandfather;
    }
    if (text.contains('niece')) {
      return FamilyMemberType.niece;
    }
    if (text.contains('nephew')) {
      return FamilyMemberType.nephew;
    }
    if (text.contains('cousin')) {
      return FamilyMemberType.cousin;
    }
    if (text.contains('friend') || text.contains('dost')) {
      return FamilyMemberType.friend;
    }
    if (text.contains('colleague')) {
      return FamilyMemberType.colleague;
    }

    return FamilyMemberType.other;
  }

  final _ruflo = RuFloService();
  final String _familyId = 'default';

  /// Store family member name for future reference
  void setFamilyMemberName(FamilyMemberType type, String name) {
    _familyMemberNames[type.name] = name;
  }

  /// Get stored family member name
  String? getFamilyMemberName(FamilyMemberType type) {
    return _familyMemberNames[type.name];
  }

  Future<void> storeSharedMemory(String key, Map<String, dynamic> data) async {
    await _ruflo.memoryStore(
      namespace: 'family_shared_$_familyId',
      key: key,
      value: data,
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
        'visibility': 'family',
      },
    );
  }

  Future<List<Map<String, dynamic>>> getFamilyMemories(String query) async {
    return await _ruflo.memorySearch(
      namespace: 'family_shared_$_familyId',
      query: query,
      topK: 10,
    );
  }

  Future<void> storeImportantDate(
      String event, DateTime date, String person) async {
    await storeSharedMemory('event_${event.hashCode}', {
      'event': event,
      'date': date.toIso8601String(),
      'person': person,
      'type': 'important_date',
    });
  }
}

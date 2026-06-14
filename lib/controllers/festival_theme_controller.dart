// lib/controllers/festival_theme_controller.dart
// Phase 2 - Sprint 5 - Task 5.1, 5.2, 5.3, 5.4: FestivalThemeController

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Immutable model for a festival theme
class FestivalTheme {
  final String festivalName;
  final Color primaryColor;
  final Color secondaryColor;
  final String greetingMessage;
  final List<String> suggestedActivities;
  final List<String> greetingVariants; // multiple greeting options

  const FestivalTheme({
    required this.festivalName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.greetingMessage,
    required this.suggestedActivities,
    this.greetingVariants = const [],
  });
}

/// Controller that detects the current festival and exposes theme data.
/// Polls for festival changes every hour.
class FestivalThemeController extends GetxController {
  static FestivalThemeController get to => Get.find();

  final Rx<FestivalTheme?> activeFestivalTheme = Rx<FestivalTheme?>(null);
  final RxString activeFestivalName = ''.obs;

  Timer? _hourlyCheckTimer;

  // ── Festival definitions ─────────────────────────────────────────────────
  static final Map<String, FestivalTheme> _themes = {
    'Diwali': const FestivalTheme(
      festivalName: 'Diwali',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFFFF6347),
      greetingMessage:
          'Aaj Diwali hai! Diya jalao, Lakshmi Mantra suno, aur apne parivaar ke saath khushi share karo!',
      greetingVariants: [
        'Diwali ki hardik shubhkamnayein! Ghar mein roshni aur khushi ho!',
        'Happy Diwali! Lakshmi Mata ki kripa aap par bani rahe!',
        'Deepotsav ki shubhkamana! Har diya khushi ki roshni le aaye!',
      ],
      suggestedActivities: [
        'Lakshmi Puja',
        'Naam Jaap Session',
        'Family Gathering',
        'Diwali Stories',
      ],
    ),
    'Holi': const FestivalTheme(
      festivalName: 'Holi',
      primaryColor: Color(0xFFFF69B4),
      secondaryColor: Color(0xFF87CEEB),
      greetingMessage:
          'Holi Mubarak! Rang khelo, mithai share karo, aur sab se pyaar karo!',
      greetingVariants: [
        'Holi Mubarak! Aaj rang birangi duniya mein khushi bikhrao!',
        'Happy Holi! Sab gale lago aur Holi ka mazaa lo!',
        'Rang barse! Holi ki bahut bahut badhai ho!',
      ],
      suggestedActivities: [
        'Holi Colors Play',
        'Celebrate with Family',
        'Thandai Recipe',
        'Joy and Laughter',
      ],
    ),
    'Navratri': const FestivalTheme(
      festivalName: 'Navratri',
      primaryColor: Color(0xFFFF1493),
      secondaryColor: Color(0xFF9370DB),
      greetingMessage:
          'Navratri ki shubhkamnayein! Durga Maa ki pooja karo aur Garba mein bhag lo!',
      greetingVariants: [
        'Jai Mata Di! Navratri ki hardik shubhkamnayein!',
        'Navratri Mubarak ho! Maa Durga ki kripa aap par rahe!',
        'Garba kheloge aaj? Navratri ki badhai ho!',
      ],
      suggestedActivities: [
        'Durga Puja',
        'Garba Night',
        'Naam Jaap',
        'Devi Mantras',
      ],
    ),
    'Dussehra': const FestivalTheme(
      festivalName: 'Dussehra',
      primaryColor: Color(0xFFFF8C00),
      secondaryColor: Color(0xFFDC143C),
      greetingMessage:
          'Vijay Dashami ki shubhkamnayein! Aaj burai par achhai ki jeet ka mahotsav hai!',
      greetingVariants: [
        'Happy Dussehra! Burai har ke achhai jite!',
        'Vijay Dashami Mubarak! Raavan dahan dekha kya?',
        'Dussehra ki badhai! Sach aur dharma ki vijay ho!',
      ],
      suggestedActivities: [
        'Raavan Dahan',
        'Ram Katha',
        'Family celebration',
        'Victory prayers',
      ],
    ),
    'Janmashtami': const FestivalTheme(
      festivalName: 'Janmashtami',
      primaryColor: Color(0xFF4B0082),
      secondaryColor: Color(0xFFFFD700),
      greetingMessage:
          'Jai Shri Krishna! Janmashtami ki hardik shubhkamnayein! Kanha ke bhajans sunenge?',
      greetingVariants: [
        'Happy Janmashtami! Shri Krishna ki jai!',
        'Jai Kanhaiya Lal Ki! Janmashtami Mubarak!',
        'Kanha aaye! Janmashtami ki badhai ho!',
      ],
      suggestedActivities: [
        'Krishna Bhajans',
        'Jai Shri Krishna Naam Jaap',
        'Dahi Handi',
        'Fast & Prayers',
      ],
    ),
    'Ganesh Chaturthi': const FestivalTheme(
      festivalName: 'Ganesh Chaturthi',
      primaryColor: Color(0xFFFF6600),
      secondaryColor: Color(0xFFFFD700),
      greetingMessage:
          'Ganpati Bappa Morya! Aaj Ganesha ji ka swaagat karein, woh sabka kalyan karte hain!',
      greetingVariants: [
        'Ganpati Bappa Morya! Chaturthi ki hardik badhai!',
        'Jai Ganesh! Vighnaharta ki kripa aap par bani rahe!',
        'Happy Ganesh Chaturthi! Bappa aaye hain sukh laane!',
      ],
      suggestedActivities: [
        'Ganesh Puja',
        'Ganesh Naam Jaap',
        'Modak Prasad',
        'Aarti',
      ],
    ),
    'Raksha Bandhan': const FestivalTheme(
      festivalName: 'Raksha Bandhan',
      primaryColor: Color(0xFFFF69B4),
      secondaryColor: Color(0xFF4169E1),
      greetingMessage:
          'Raksha Bandhan Mubarak! Bhai behen ka pyaar aur rakshasutra ka bandhan khubsurat hai!',
      greetingVariants: [
        'Happy Raksha Bandhan! Bhai ko rakhi bandho!',
        'Raksha Bandhan ki hardik badhai! Ye bandhan toh hai ati pavitra.',
        'Bhai behen ke pyaar ka tyohar mubarak ho!',
      ],
      suggestedActivities: [
        'Tie Rakhi',
        'Family time',
        'Sibling gifts',
        'Sweet sharing',
      ],
    ),
    'Christmas': const FestivalTheme(
      festivalName: 'Christmas',
      primaryColor: Color(0xFF228B22),
      secondaryColor: Color(0xFFDC143C),
      greetingMessage:
          'Merry Christmas! Jesus ka janam aaj duniya mein khushi aur shanti laya!',
      greetingVariants: [
        'Merry Christmas! Santa ka intezaar hai kya?',
        'Happy Christmas! Aaj ki raat bahut khaas hai!',
        'Wishing you a Merry Christmas filled with love and joy!',
      ],
      suggestedActivities: [
        'Christmas celebration',
        'Carol singing',
        'Gift exchange',
        'Family gathering',
      ],
    ),
    'Eid ul-Fitr': const FestivalTheme(
      festivalName: 'Eid ul-Fitr',
      primaryColor: Color(0xFF006400),
      secondaryColor: Color(0xFFFFD700),
      greetingMessage:
          'Eid Mubarak! Id ul Fitr ki bahut bahut badhai! Sewaiyaan share karo!',
      greetingVariants: [
        'Eid Mubarak! Id ki bahut bahut badhai!',
        'Happy Eid! Allah aapki dua qabool kare!',
        'Eid Mubarak! Aaj sewaiyaan khayi kya?',
      ],
      suggestedActivities: [
        'Eid Namaz',
        'Sewaiyaan sharing',
        'Family feast',
        'Gift giving',
      ],
    ),
    'Guru Nanak Jayanti': const FestivalTheme(
      festivalName: 'Guru Nanak Jayanti',
      primaryColor: Color(0xFFFF8C00),
      secondaryColor: Color(0xFFFFFFFF),
      greetingMessage:
          'Waheguru Ji ki Fateh! Guru Nanak Dev Ji ke Gurpurab ki lakh lakh badhai!',
      greetingVariants: [
        'Gurpurab di lakh lakh badhai! Waheguru Ji ka Khalsa!',
        'Happy Gurpurab! Guru Nanak Dev Ji ki path mein rahen!',
        'Guru Nanak Jayanti Mubarak! Ik Onkar!',
      ],
      suggestedActivities: [
        'Waheguru Naam Jaap',
        'Ardas',
        'Langar',
        'Gurbani',
      ],
    ),
    'Republic Day': const FestivalTheme(
      festivalName: 'Republic Day',
      primaryColor: Color(0xFFFF9933),
      secondaryColor: Color(0xFF138808),
      greetingMessage:
          'Happy Republic Day! 26 January – Bharat ka Sanvidhan lagu hua aaj ke din. Jai Hind!',
      greetingVariants: [
        'Happy Republic Day! Jai Hind! Jai Bharat!',
        '26 January ki hardik shubhkamnayein! Vande Mataram!',
        'Republic Day Mubarak! Hamara Bharat Mahaan!',
      ],
      suggestedActivities: [
        'Parade watching',
        'Flag hoisting',
        'National Anthem',
        'Patriotic songs',
      ],
    ),
    'Independence Day': const FestivalTheme(
      festivalName: 'Independence Day',
      primaryColor: Color(0xFFFF9933),
      secondaryColor: Color(0xFF138808),
      greetingMessage:
          'Happy Independence Day! 15 August – Azaadi ka tyohar. Jai Hind! Vande Mataram!',
      greetingVariants: [
        'Jai Hind! Happy Independence Day!',
        '15 August ki hardik badhai! Vande Mataram!',
        'Azaadi Mubarak! Bharat Mata Ki Jai!',
      ],
      suggestedActivities: [
        'Flag hoisting',
        'National Anthem',
        'Patriotic celebration',
        'Swatantrata Diwas',
      ],
    ),
    'Makar Sankranti': const FestivalTheme(
      festivalName: 'Makar Sankranti',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFFFF8C00),
      greetingMessage:
          'Makar Sankranti ki shubhkamnayein! Til gur khao aur meetha bol ke jiyo!',
      greetingVariants: [
        'Happy Makar Sankranti! Til gur khao, mitthi baatein karo!',
        'Uttarayan Mubarak! Patang udao, khushi manao!',
        'Makar Sankranti ki lakh lakh badhai! Khichdi aur til ki barfi ka mazaa lo!',
      ],
      suggestedActivities: [
        'Patang festival',
        'Til khichdi',
        'Sunrise prayers',
        'Daan-punya',
      ],
    ),
    'Pongal': const FestivalTheme(
      festivalName: 'Pongal',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFF228B22),
      greetingMessage:
          'Happy Pongal! Harvest festival ki hardik badhai! Pongalo Pongal!',
      greetingVariants: [
        'Pongal Vazhtukal! Happy Pongal!',
        'Happy Pongal! Naya saal, naya aaghaz!',
        'Pongalo Pongal! Khushiyon ka tyohar aaya!',
      ],
      suggestedActivities: [
        'Pongal rice preparation',
        'Kolam drawing',
        'Sun God prayers',
        'Family feast',
      ],
    ),
    'Hanukkah': const FestivalTheme(
      festivalName: 'Onam',
      primaryColor: Color(0xFF228B22),
      secondaryColor: Color(0xFFFFD700),
      greetingMessage:
          'Happy Onam! Kerala ka yeh mahaan tyohar aapko khushi de!',
      greetingVariants: [
        'Onam Ashamsakal! Happy Onam!',
        'Happy Onam! Pookkalam aur Sadya ka mazaa lo!',
        'Onam ki hardik shubhkamnayein! Vamana Tripadham!',
      ],
      suggestedActivities: [
        'Pookkalam making',
        'Onam Sadya',
        'Vallam Kali boat race',
        'Family celebration',
      ],
    ),
  };

  // ── Festival date calendar (fixed dates) ──────────────────────────────────
  // Format: 'MM-DD' → festivalName
  static const Map<String, String> _fixedDateFestivals = {
    '01-26': 'Republic Day',
    '08-15': 'Independence Day',
    '12-25': 'Christmas',
  };

  // Approximate dates for major festivals (updated yearly)
  // Format: 'MM-DD' → festivalName
  static const Map<String, String> _approximateFestivals = {
    '01-14': 'Makar Sankranti',
    '03-25': 'Holi',
    '08-19': 'Raksha Bandhan', // approx
    '08-26': 'Janmashtami', // approx
    '10-02': 'Navratri',
    '10-12': 'Dussehra', // approx
    '10-20': 'Diwali', // approx
    '09-07': 'Ganesh Chaturthi', // approx
    '11-14': 'Guru Nanak Jayanti', // approx
  };

  // ── Controller lifecycle ──────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _checkFestival();
    // Re-check every hour
    _hourlyCheckTimer =
        Timer.periodic(const Duration(hours: 1), (_) => _checkFestival());
    debugPrint('✅ FestivalThemeController initialized');
  }

  @override
  void onClose() {
    _hourlyCheckTimer?.cancel();
    super.onClose();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// True when today is a recognized festival day
  bool get isFestivalDay => activeFestivalTheme.value != null;

  /// Returns today's festival greeting or empty string
  String getTodayGreeting() {
    final theme = activeFestivalTheme.value;
    if (theme == null) return '';
    if (theme.greetingVariants.isNotEmpty) {
      final idx = DateTime.now().second % theme.greetingVariants.length;
      return theme.greetingVariants[idx];
    }
    return theme.greetingMessage;
  }

  /// Returns festival activities list
  List<String> getSuggestedActivities() {
    return activeFestivalTheme.value?.suggestedActivities ?? [];
  }

  /// Get theme object for a specific festival name
  FestivalTheme? getThemeForFestival(String name) => _themes[name];

  // ── Private helpers ───────────────────────────────────────────────────────

  void _checkFestival() {
    final today = DateTime.now();
    final key = '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final festivalName = _fixedDateFestivals[key] ?? _approximateFestivals[key];

    if (festivalName != null && _themes.containsKey(festivalName)) {
      activeFestivalTheme.value = _themes[festivalName];
      activeFestivalName.value = festivalName;
      debugPrint('🎉 Festival detected: $festivalName');
    } else {
      activeFestivalTheme.value = null;
      activeFestivalName.value = '';
    }
  }
}

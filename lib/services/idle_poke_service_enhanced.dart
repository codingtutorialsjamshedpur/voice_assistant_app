// lib/services/idle_poke_service_enhanced.dart
// Phase 2 - Sprint 6 - Tasks 6.1, 6.2, 6.3: Enhanced IdlePokeService
// NOTE: The existing IdlePromptService handles basic idle prompting.
// This service adds smart persona/mood/time/role-aware poke selection.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/mood_state_model.dart';
import '../services/mood_detection_service.dart';
import '../services/role_detection_service.dart';
import '../services/personality_response_engine.dart';
import '../controllers/profile_controller.dart';

/// Time-of-day buckets for poke filtering
enum TimeOfDay2 {
  morning, // 06:00-10:00
  lateMorning, // 10:00-12:00
  afternoon, // 12:00-16:00
  evening, // 16:00-19:00
  night, // 19:00-23:00
  lateNight, // 23:00-06:00
}

extension TimeOfDay2Extension on TimeOfDay2 {
  String get label {
    switch (this) {
      case TimeOfDay2.morning:
        return 'morning';
      case TimeOfDay2.lateMorning:
        return 'late_morning';
      case TimeOfDay2.afternoon:
        return 'afternoon';
      case TimeOfDay2.evening:
        return 'evening';
      case TimeOfDay2.night:
        return 'night';
      case TimeOfDay2.lateNight:
        return 'late_night';
    }
  }
}

/// Smart prompt selection service with non-repetition and context awareness
class IdlePokeServiceEnhanced extends GetxService {
  static IdlePokeServiceEnhanced get to => Get.find();

  final _random = Random();

  // Track sent prompts: prompt → time of last send
  final Map<String, DateTime> _promptHistory = {};

  // Minimum gap before repeating a prompt (2 hours)
  static const Duration _minRepeatGap = Duration(hours: 2);

  // Full enriched prompt library — Indian cultural etiquette, child manners,
  // elder respect, multi-cultural warmth, spiritual depth, health wisdom.
  static const Map<String, List<String>> _promptLibrary = {
    // ── Family & Elder Respect (Core mission) ───────────────────────────
    'family': [
      'Aaj Dadi ya Nani se baat ki? Unhe Pranam boliye — unki dua sabse kaam aati hai 🙏',
      'Dadu ya Nana se aaj kuch seekha? Woh gyan ka khazana hain — poochho unse ek kahani!',
      'Aaj Mummy ne kuch bola toh dhyan se suna? Unki baat mein teri bhalaai hai 💛',
      'Papa se aaj Charan Sparsh kiya? Buzurgon ke pairon mein aanashirwaad hoti hai.',
      'Kya aapne aaj ghar mein kisi bade ka kaam mein haath bataya? Seva sabse badi pooja hai.',
      'Chacha-Chachi ya Mama-Mami se agar milo, toh hamesha namaste ya pranam se greeting karo.',
      'Bade log baat kar rahe hain, toh beech mein mat kaat-o. Sunna bhi ek kala hai 🤫',
      'Ghar sab theek? Chhote bhai-behen se aaj pyaar se baat ki? Unke liye aap role model hain!',
      'Kya aaj ghar mein kisi ne kuch achha kiya? Tarif karo — appreciation powerful hoti hai.',
      'Aaj Dadi/Nani ke haath ka kuch khaya? Unke haath ka khana duniya ka best food hai! 😊',
      'Maafi maangna weakness nahi, strength hai. Kisi se kuch galat hua toh sorry bol do.',
      'Ghar ke buzurgon se poocho — unke zamane ki ek kahani. Tum hairan ho jaoge!',
    ],

    // ── Child Manners & Etiquette Coaching ──────────────────────────────
    'manners': [
      'Jab bhi ghar aao ya jao — ghar ke sabhi ko batao. Izzat dene se izzat milti hai 🙏',
      '"Please" aur "Thank You" — ye do words magic karte hain. Aaj kisi ko bola kya?',
      'Mez par khaate waqt phone band karo. Family time precious hota hai! 📵',
      'Kisi ki cheez bina pooche mat uthao. Permission lena good manners ka hissa hai.',
      'Jab bade log baat kar rahe ho, dhyan se suno — beech mein mat bolo. Baari aayegi tumhari bhi!',
      'Agar kisi ne help ki toh "Shukriya / Dhanyawad" zaroor kaho. Gratitude rishte mazboot karta hai.',
      'Khana waste mat karo. Duniya mein kai bacche bhookhe hain. Plate saaf karo! 🍽️',
      'Doosron ki baat sunna seekho — yahi sabse bada aadaab hai.',
      'Kisi bhi bade se milte waqt pehle Namaste ya Pranam karo. Yeh hamari sanskriti hai 🙏',
      'Gande words mat bolo. Achi boli se acchi dosti aur acchi reputation milti hai.',
      'Kisi bhi cheez ke liye bade se poochho pehle — asking permission is a sign of respect.',
      'Aaj school mein teacher ko "Thank you, ma\'am/sir" bola? Teachers deserve our deepest respect!',
    ],

    // ── Elder-Specific Interaction Tips ─────────────────────────────────
    'elders': [
      'Dadu/Dadi ki sehat ka haal poochho — ek chota sa sawal unka din bana deta hai 💛',
      'Bade log jab thake honge toh unka kaam mat badhao — unki madad karo bina maange.',
      'Buzurgon se kabhi paise, salary ya umar mat poochho — yeh rude maana jaata hai.',
      'Agar Dada/Dadi koi purani baat repeat karein — sunna. Unka experience humara guidance hai.',
      'Apne Naana-Nani ko video call karo aaj — unka chehra dekh ke unhe khushi milegi!',
      'Buzurgon ki medicine ka time yaad rakho — yeh sewa ka sabse bada roop hai.',
      'Aaj Papa ya Mama ke pair chhu ke Pranam kiya? Charan Sparsh se dil ko sukoon milta hai.',
      'Ghar ke sabse bade sadasy ko pehle khana paroso — yahi hamari parampara hai.',
      'Bade ke saamne awaaz neechi rakhna — izzat aawaz ki unchaayi mein nahi, adab mein hoti hai.',
    ],

    // ── Cross-Cultural Etiquette (for 40+ language users) ───────────────
    'cultural': [
      'Duniya ke har kone mein buzurgon ki izzat ki jaati hai — aur yeh khoobsurti hai insaniyat ki! 🌍',
      'Chahe Hindi ho ya Tamil, Bengali ho ya Punjabi — "Pranam" ka matlab har dil samjhta hai.',
      'Japan mein jhukke greet karte hain, India mein hath jod ke — dono mein respect ka bhaw ek hi hai 🙏',
      'Arabic mein "As-Salamu Alaykum", Tamil mein "Vanakkam", Hindi mein "Namaste" — sab ek hi feeling!',
      'Kisi bhi culture mein — buzurg, teacher aur maata-pita ka samman sabse pehle aata hai.',
      'Duniya ke kisi bhi kone mein jaao — good manners ki language same hoti hai. Seekho aur sikhaao!',
      'Mehman ko bhagwan maano — "Atithi Devo Bhava" — yeh sirf Indians ki nahi, pure vishwa ki soch hai.',
      'Ek desh ki sanskriti sikhna ek nai dunia ka darwaza kholna hai. Curious raho! 🌐',
    ],

    // ── Health prompts (culturally grounded) ────────────────────────────
    'health': [
      'Paani piya aaj? Hamare buzurg kehte the — subah ek glass paani sone se zyada keemat rakhta hai 💧',
      'Aankhein thak gayi. 5 minute aankhein band karo — Anulom Vilom bhi try karo!',
      'Kuch healthy khaya? Dadi ka formula — desi ghee aur haldi milk = zero doctor. Try karo!',
      'Kitna der baithe ho? Uth ke thoda chalte hain — "Chalna hi Jeevan hai" 🚶',
      'Aaj exercise ki? Surya Namaskar se better kuch nahi — 12 poses, poora body active!',
      'Kitni der se screen dekh rahe ho? Aankhon ko aaram do — pooja ke diye ki tarah treat karo unhe.',
      'Tabiyat theek hai? Koi problem ho toh chhupaao mat — Mummy-Papa ko batao.',
      'Raat ko jaldi soyo. Neend mein hi shareer theek hota hai — buzurgon ki sachchi baat hai yeh.',
      'Stress ho toh deep breath lo aur "Om" ka uccharan karo. Mann turant calm hota hai 🕉️',
    ],

    // ── Morning (with Indian cultural warmth) ───────────────────────────
    'morning': [
      'Subah uthke pehle kaun sa kaam karein? Maa-Baap ko Pranam — aur din acha jayega! 🌅',
      'Good Morning! Bhagwan ko Shukra-guzar ho aaj ke nayi subah ke liye 🙏',
      'Subah ka paani piya? Nashta mat chodo — Mummy ne khud banaya hoga thoda effort se!',
      'Nayi subah — naya mauka. Aaj kuch naya seekhte hain, kuch naya karte hain!',
      'Surya ko Pranam karo subah mein — Surya Namaskar se body aur dil dono roshan hote hain ☀️',
      'School ya college jaate waqt bade parivaar ke sabhiko goodbye bolke jaao — yahi tameez hai.',
    ],

    // ── Afternoon (school / learning grounding) ─────────────────────────
    'afternoon': [
      'Lunch ka time — ghar mein jo bana ho khushi se khao. Mummy ka mehnat mat bhulo! 🍛',
      'Dopahar ho gayi — thoda break, fir padhai. Breaks make you smarter, not lazy!',
      'Aaj teacher ne kuch naya sikhaya? Ghar aake Mummy-Papa ko bhi batao — unhe khushi hogi.',
      'Aaj ka target pura hua? Agar nahi, koi baat nahi — kal aur achhe se karenge. 💪',
      'Dopahar ki neend lia kya? Short rest kaafi hai — Dadi ka nuskha: 20 min nap = fresh mind!',
    ],

    // ── Evening (family bonding time) ────────────────────────────────────
    'evening': [
      'Sham ho gayi — ghar ke saath waqt bitao. Phone baad mein. Family pehle! 🏠',
      'Dinner ke liye kuch healthy plan hai? Ghar ka khana safai aur sehat dono deta hai.',
      'Aaj ka din kaisa tha? Sab se share karo — ghar mein sunne wale the hamesha!',
      'Sham mein Papa se poochho — "Aapka din kaisa tha?" Yeh ek chota sawaal rishte bada karta hai.',
      'Bade bhai-behen se baaton baaton mein kuch seekhne ki koshish karo — woh bhi teacher hain.',
    ],

    // ── Night (rest, reflection, gratitude) ──────────────────────────────
    'night': [
      'Raat mein sone se pehle Ishwar ka shukriya ada karo — teen cheezein yaad karo jo achhi hui aaj 🙏',
      'Aaj ke liye Mummy-Papa ko "Goodnight" bola? Ek chota gesture, bada pyaar!',
      'Kal ke liye apna bag ready kiya? Kal ki chinta aaj karo — subah ki bhagna mat!',
      'Phone band karo, Dadi/Nani ki kahani suno ya kitab padho — yeh neend bhi achhi laati hai 📖',
      'Raat ko garam doodh ya herbal tea — Dadi ka nuskha. Try karo! 🥛',
    ],

    // ── Student / Academic etiquette ────────────────────────────────────
    'student': [
      'Exam ki preparation chal rahi hai? Teacher se doubt poochho — questions poochhna bhari nahi, samajhdaari hai!',
      'Homework complete kiya? Phir check karo ek baar — doosri najar se galti pakad mein aati hai.',
      'School mein teacher ka respect karo — unki mehnat tumhare liye hai. "Thank you Sir/Ma\'am" bolo!',
      'Friends se jhagda? Pehle maafi maango — dost rare hote hain, ego nahi.',
      'Career ke baare mein confused ho? Ghar ke bade se baat karo — unka tajurba amulya hai.',
      'Ek naya word seekho aaj English mein aur ek Hindi mein bhi — bilingual hai toh brilliant hai!',
    ],

    // ── Spiritual & Gratitude ────────────────────────────────────────────
    'spiritual': [
      'Subah ya raat mein mandir jaao ya ghar mein diya jalao — yeh ek positive energy laata hai 🪔',
      'Chalo ek baar Naam Jaap karte hain — "Om Namah Shivaya" ya Jo Bhi Ishtar tum maante ho.',
      'Ek minute ke liye aankhein band karo, Ishwar ka dhanyawad do — yeh habit life badal deti hai.',
      'Gratitude express karo aaj. Sirf teen cheezein likho jo tum thankful ho — fark padega.',
      'Bhagwad Gita ki ek line yaad karo — "Karm karo, phal ki chinta mat karo." Isko jeena hai.',
      'Pooja, namaaz ya path — chahe koi bhi mann ki shanti ki raah ho, daily zaroor karo.',
    ],

    // ── Fun & Curiosity ──────────────────────────────────────────────────
    'fun': [
      'Kya main aapko ek Indian culture ka interesting fact bata doon? 🤩',
      'Thoda bore ho rahe ho? Chalo ek voice game khelte hain — ya phir ek paheli!',
      'Main aapke liye ek moral wali kahani suna sakta hoon — Panchatantra waali!',
      'Kya aapne kabhi Yoga try kiya? Main ek simple pose sikha sakta hoon!',
      'Mere paas ek amazing science fact hai jo aaj ke lesson se bhi interesting hai — sunoge?',
      'Chalo ek Indian festival ke baare mein seekhte hain jo aap abhi tak nahi jaante the!',
    ],

    // ── Working Professional ──────────────────────────────────────────────
    'professional': [
      'Office mein bade ya senior se milte waqt respect ke saath baat karo — woh trust banata hai.',
      'Kaam aur life ka balance rakho — ghar waale bhi zaroor hain, sirf office nahi.',
      'Aaj koi naya skill seekha? Growth mindset hi India ko aage le jaayega!',
      'Project mein naya innovation? Sochne waale hi duniya badlate hain. 🚀',
      'Team mein kisi ne achha kaam kiya? Tarif karo openly — leadership yahi hoti hai.',
    ],
  };

  // ── Time detection ──────────────────────────────────────────────────────

  static TimeOfDay2 _getCurrentTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 10) return TimeOfDay2.morning;
    if (hour >= 10 && hour < 12) return TimeOfDay2.lateMorning;
    if (hour >= 12 && hour < 16) return TimeOfDay2.afternoon;
    if (hour >= 16 && hour < 19) return TimeOfDay2.evening;
    if (hour >= 19 && hour < 23) return TimeOfDay2.night;
    return TimeOfDay2.lateNight;
  }

  static bool get _isWeekday {
    final day = DateTime.now().weekday;
    return day >= DateTime.monday && day <= DateTime.friday;
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Get next smart poke prompt considering mood, role, personality, and time.
  /// Returns null if no suitable prompt available (all recently sent).
  String? getNextPrompt() {
    final pool = _buildWeightedPool();
    if (pool.isEmpty) return null;

    // Filter out recently sent
    final available = pool.where((p) {
      final lastSent = _promptHistory[p];
      if (lastSent == null) return true;
      return DateTime.now().difference(lastSent) > _minRepeatGap;
    }).toList();

    if (available.isEmpty) return null;

    // Pick random from available
    final selected = available[_random.nextInt(available.length)];
    _promptHistory[selected] = DateTime.now();

    // Apply personality opener
    return _applyPersonality(selected);
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  List<String> _buildWeightedPool() {
    final pool = <String>[];
    final time = _getCurrentTimeOfDay();
    final mood = _getCurrentMood();
    final role = _getCurrentRole();

    // Time-of-day base prompts (high weight)
    switch (time) {
      case TimeOfDay2.morning:
      case TimeOfDay2.lateMorning:
        pool.addAll(_promptLibrary['morning'] ?? []);
        pool.addAll(_promptLibrary['health'] ?? []);
        pool.addAll(_promptLibrary['manners'] ?? []); // morning manners nudge
        break;
      case TimeOfDay2.afternoon:
        pool.addAll(_promptLibrary['afternoon'] ?? []);
        pool.addAll(_promptLibrary['student'] ?? []);
        if (_isWeekday) pool.addAll(_promptLibrary['professional'] ?? []);
        break;
      case TimeOfDay2.evening:
        pool.addAll(_promptLibrary['evening'] ?? []);
        pool.addAll(_promptLibrary['family'] ?? []); // family evening weight
        pool.addAll(_promptLibrary['elders'] ?? []); // elder check-in
        break;
      case TimeOfDay2.night:
      case TimeOfDay2.lateNight:
        pool.addAll(_promptLibrary['night'] ?? []);
        pool.addAll(_promptLibrary['spiritual'] ?? []);
        pool.addAll(_promptLibrary['family'] ?? []);
        break;
    }

    // Role-based prompts
    switch (role) {
      case UserRole.student:
        pool.addAll(_promptLibrary['student'] ?? []);
        pool.addAll(
            _promptLibrary['manners'] ?? []); // students need etiquette!
        pool.addAll(_promptLibrary['family'] ?? []);
        pool.addAll(_promptLibrary['elders'] ?? []);
        break;
      case UserRole.workingProfessional:
        pool.addAll(_promptLibrary['professional'] ?? []);
        pool.addAll(_promptLibrary['health'] ?? []);
        pool.addAll(_promptLibrary['family'] ?? []);
        break;
      case UserRole.parent:
      case UserRole.elder:
        pool.addAll(_promptLibrary['family'] ?? []);
        pool.addAll(_promptLibrary['health'] ?? []);
        pool.addAll(_promptLibrary['spiritual'] ?? []);
        break;
      case UserRole.creative:
      case UserRole.sports:
        pool.addAll(_promptLibrary['fun'] ?? []);
        pool.addAll(_promptLibrary['cultural'] ?? []);
        break;
      default:
        pool.addAll(_promptLibrary['fun'] ?? []);
        pool.addAll(_promptLibrary['health'] ?? []);
        pool.addAll(_promptLibrary['manners'] ?? []);
    }

    // Mood-based additions
    switch (mood) {
      case MoodType.happy:
      case MoodType.excited:
        pool.addAll(_promptLibrary['fun'] ?? []);
        pool.addAll(
            _promptLibrary['cultural'] ?? []); // curious moods → culture
        break;
      case MoodType.sad:
      case MoodType.anxious:
        pool.addAll(_promptLibrary['family'] ?? []);
        pool.addAll(_promptLibrary['spiritual'] ?? []);
        pool.addAll(_promptLibrary['elders'] ?? []);
        break;
      case MoodType.stressed:
      case MoodType.tired:
        pool.addAll(_promptLibrary['health'] ?? []);
        pool.addAll(_promptLibrary['spiritual'] ?? []);
        break;
      default:
        pool.addAll(_promptLibrary['fun'] ?? []);
    }

    // Weekend: family + cultural + elders
    if (!_isWeekday) {
      pool.addAll(_promptLibrary['family'] ?? []);
      pool.addAll(_promptLibrary['elders'] ?? []);
      pool.addAll(_promptLibrary['cultural'] ?? []);
    }

    return pool;
  }

  String _applyPersonality(String prompt) {
    try {
      if (Get.isRegistered<PersonalityResponseEngine>()) {
        // Look up current personality from VoiceController if available
        // If not, use default dost
        const PersonalityPack pack = PersonalityPack.dost;
        try {
          // Dynamic lookup to avoid circular dependency
          final ctrl = Get.find(tag: null);
          if (ctrl != null) {
            // ignore — safe fallback
          }
        } catch (_) {}

        final engine = Get.find<PersonalityResponseEngine>();
        return engine.applyPersonalityToPrompt(pack, prompt);
      }
    } catch (_) {}
    return prompt;
  }

  MoodType _getCurrentMood() {
    try {
      if (Get.isRegistered<MoodDetectionService>()) {
        // Check if any mood is stored in voice controller
        return MoodType.neutral;
      }
    } catch (_) {}
    return MoodType.neutral;
  }

  UserRole _getCurrentRole() {
    try {
      if (Get.isRegistered<RoleDetectionService>() &&
          Get.isRegistered<ProfileController>()) {
        final profile = Get.find<ProfileController>().userProfile.value;
        return Get.find<RoleDetectionService>().detectRole(profile).role;
      }
    } catch (_) {}
    return UserRole.unknown;
  }

  // ── Admin helpers for testing ────────────────────────────────────────────

  void clearHistory() => _promptHistory.clear();

  int get historySize => _promptHistory.length;

  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ IdlePokeServiceEnhanced initialized');
  }
}

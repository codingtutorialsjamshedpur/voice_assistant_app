// lib/services/role_detection_service.dart
// Phase 2 - Sprint 3 - Task 3.1 & 3.2: RoleDetectionService

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/profile_model.dart';

/// Enum representing the inferred user role
enum UserRole {
  student, // Age ~18-25, mentions studies/exams
  workingProfessional, // Mentions job/office/meetings
  parent, // Mentions kids/school/parenting
  elder, // Age 50+, retirement/health focus
  homemaker, // Mentions household/family care
  businessOwner, // Mentions business/startup/entrepreneurship
  creative, // Mentions art/music/writing/design
  sports, // Mentions fitness/sports/gym
  unknown, // Default when not enough data
}

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.workingProfessional:
        return 'Working Professional';
      case UserRole.parent:
        return 'Parent';
      case UserRole.elder:
        return 'Elder';
      case UserRole.homemaker:
        return 'Homemaker';
      case UserRole.businessOwner:
        return 'Business Owner';
      case UserRole.creative:
        return 'Creative';
      case UserRole.sports:
        return 'Sports/Fitness';
      case UserRole.unknown:
        return 'General';
    }
  }

  String get emoji {
    switch (this) {
      case UserRole.student:
        return '📚';
      case UserRole.workingProfessional:
        return '💼';
      case UserRole.parent:
        return '👨‍👩‍👧';
      case UserRole.elder:
        return '🧓';
      case UserRole.homemaker:
        return '🏠';
      case UserRole.businessOwner:
        return '🏢';
      case UserRole.creative:
        return '🎨';
      case UserRole.sports:
        return '🏋️';
      case UserRole.unknown:
        return '👤';
    }
  }
}

/// Analysis result from role detection
class RoleAnalysis {
  final UserRole role;
  final double confidence;
  final List<String> indicators;

  const RoleAnalysis({
    required this.role,
    required this.confidence,
    required this.indicators,
  });

  static RoleAnalysis get unknown => const RoleAnalysis(
        role: UserRole.unknown,
        confidence: 0.1,
        indicators: [],
      );
}

/// Service that infers the user's life-role from their profile data.
class RoleDetectionService extends GetxService {
  // ── Keyword maps ─────────────────────────────────────────────────────────

  static const Map<UserRole, List<String>> _roleKeywords = {
    UserRole.student: [
      'student',
      'study',
      'studying',
      'college',
      'university',
      'school',
      'exam',
      'degree',
      'bsc',
      'msc',
      'btech',
      'mtech',
      'ba',
      'ma',
      'padhai',
      'padh',
      'class',
      'lecture',
    ],
    UserRole.workingProfessional: [
      'engineer',
      'software',
      'developer',
      'it ',
      'manager',
      'officer',
      'doctor',
      'lawyer',
      'accountant',
      'banker',
      'analyst',
      'executive',
      'job',
      'office',
      'company',
      'corporate',
      'salary',
      'naukri',
    ],
    UserRole.parent: [
      'parent',
      'father',
      'mother',
      'papa',
      'mummy',
      'bacha',
      'bachcha',
      'kids',
      'son',
      'daughter',
      'beti',
      'beta',
      'child',
      'children',
      'parenting',
    ],
    UserRole.elder: [
      'retired',
      'retirement',
      'pension',
      'granddaughter',
      'grandson',
      'nana',
      'nani',
      'dada',
      'dadi',
      'senior',
      'arthritis',
      'diabetes',
      'old age',
    ],
    UserRole.homemaker: [
      'housewife',
      'home maker',
      'homemaker',
      'ghar',
      'household',
      'cooking',
      'bana rahi',
      'bana raha',
      'khana banana',
    ],
    UserRole.businessOwner: [
      'business',
      'startup',
      'entrepreneur',
      'founder',
      'ceo',
      'owner',
      'shop',
      'dukan',
      'vyapaar',
      'client',
      'vendor',
    ],
    UserRole.creative: [
      'artist',
      'musician',
      'writer',
      'designer',
      'photographer',
      'actor',
      'singer',
      'painter',
      'creative',
      'art',
      'music',
      'drawing',
    ],
    UserRole.sports: [
      'fitness',
      'gym',
      'athlete',
      'sport',
      'cricket',
      'football',
      'player',
      'runner',
      'coach',
      'workout',
      'exercise',
    ],
  };

  // ── Public API ────────────────────────────────────────────────────────────

  /// Detect the user's role from their [UserProfile].
  RoleAnalysis detectRole(UserProfile profile) {
    final scores = <UserRole, double>{};
    final indicators = <String>[];

    for (final role in UserRole.values) {
      if (role == UserRole.unknown) continue;
      scores[role] = 0.0;
    }

    // ── Score from fieldOfInterest (used as profession/interest) ──────────
    final profession = profile.fieldOfInterest.toLowerCase();
    _roleKeywords.forEach((role, keywords) {
      final hits = keywords.where((kw) => profession.contains(kw)).length;
      if (hits > 0) {
        scores[role] = (scores[role] ?? 0) + (hits * 0.4);
        indicators.add('fieldOfInterest: ${role.label}');
      }
    });

    // ── Score from anticipation ───────────────────────────────
    final extraText = profile.anticipation.toLowerCase();
    _roleKeywords.forEach((role, keywords) {
      final hits = keywords.where((kw) => extraText.contains(kw)).length;
      if (hits > 0) {
        scores[role] = (scores[role] ?? 0) + (hits * 0.2);
        indicators.add('interests: ${role.label}');
      }
    });

    // ── Determine dominant role ───────────────────────────────
    UserRole dominant = UserRole.unknown;
    double maxScore = 0.0;
    scores.forEach((role, score) {
      if (score > maxScore) {
        maxScore = score;
        dominant = role;
      }
    });

    if (maxScore < 0.2) {
      return RoleAnalysis.unknown;
    }

    return RoleAnalysis(
      role: dominant,
      confidence: maxScore.clamp(0.0, 1.0),
      indicators: indicators,
    );
  }

  /// Returns role-specific system prompt context for the AI.
  String getRoleSystemPromptContext(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'User is a student. They may be dealing with studies, exams, or career decisions. Provide academic/study support and family balance advice.';
      case UserRole.workingProfessional:
        return 'User is a working professional. They may face work stress and work-life balance issues. Focus on productivity, stress management, and health.';
      case UserRole.parent:
        return 'User is a parent. Family well-being is paramount. Suggest family activities, parenting tips, and child care topics.';
      case UserRole.elder:
        return 'User is an elder. Prioritize health, family connections, wisdom sharing, and spiritual well-being.';
      case UserRole.homemaker:
        return 'User is a homemaker managing household. Respect their role and suggest family care, home management, and self-care topics.';
      case UserRole.businessOwner:
        return 'User is a business owner or entrepreneur. Support business thinking, motivation, and entrepreneurial mindset.';
      case UserRole.creative:
        return 'User is a creative professional. Encourage creative expression, suggest inspiration, and validate their artistic journey.';
      case UserRole.sports:
        return 'User is interested in sports/fitness. Encourage healthy lifestyle, athletic goals, and fitness motivation.';
      case UserRole.unknown:
        return '';
    }
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ RoleDetectionService initialized');
  }
}

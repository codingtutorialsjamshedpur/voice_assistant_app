import 'dart:convert';
import '../services/response_level_strategy_service.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String mobileNumber;
  final String location;
  final String fieldOfInterest;
  final String anticipation;
  final String gender;
  final String profileImage;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Task 1.4: Response-Level fields ────────────────────────────────
  final ResponseLevel defaultResponseLevel;
  final bool autoDetectLevel;
  final List<String> preferredLevelKeywords;
  final String? preferredLearningStyle;
  final ChildProfile? childProfile;

  // ── Phase 2: Emotional AI fields ─────────────────────────────────────
  final String? detectedRole; // e.g. 'student', 'workingProfessional'
  final String preferredPersonality; // PersonalityPack name, default 'dost'
  final bool enableMoodDetection; // toggle mood detection
  final bool enableFestivalMode; // toggle festival UI changes

  // ── Age & Class Level ─────────────────────────────────────────────────
  final int age; // 0 = not set

  /// Maps user age to Indian school class level string for AI calibration.
  /// India: School starts at 3 (Nursery), Class 1 at age 6, Class 12 at 18.
  String get estimatedClassLevel {
    if (age <= 0) return '';
    if (age < 4) return 'Nursery / Pre-School';
    if (age == 4) return 'LKG (Lower Kindergarten)';
    if (age == 5) return 'UKG (Upper Kindergarten)';
    if (age >= 6 && age <= 18) return 'Class ${age - 5}';
    if (age > 18 && age <= 22) return 'Undergraduate / College';
    return 'Adult / Professional';
  }

  bool get isChild => age > 0 && age <= 14;
  bool get isTeenager => age >= 13 && age <= 18;
  bool get isAdult => age > 18;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.mobileNumber = '',
    this.location = '',
    this.fieldOfInterest = '',
    this.anticipation = '',
    this.gender = 'male',
    this.profileImage = '',
    this.isOnline = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.defaultResponseLevel = ResponseLevel.intermediate,
    this.autoDetectLevel = true,
    this.preferredLevelKeywords = const [],
    this.preferredLearningStyle,
    this.childProfile,
    // Phase 2
    this.detectedRole,
    this.preferredPersonality = 'dost',
    this.enableMoodDetection = true,
    this.enableFestivalMode = true,
    this.age = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Generic default profile for new users
  factory UserProfile.defaultProfile() {
    return UserProfile(
      id: '0',
      name: 'Guest User',
      email: 'user@example.com',
      mobileNumber: '',
      location: 'Enter Location',
      fieldOfInterest: 'Set your interests in profile settings',
      anticipation: 'Tell us how you would like to be taught',
      gender: 'male',
      profileImage: '',
      isOnline: true,
    );
  }

  // Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Parse ResponseLevel safely
    ResponseLevel parseLevel(String? s) {
      if (s == null) return ResponseLevel.intermediate;
      return ResponseLevel.values.firstWhere(
        (l) => l.name == s,
        orElse: () => ResponseLevel.intermediate,
      );
    }

    return UserProfile(
      id: json['id'] ?? '1',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      location: json['location'] ?? '',
      fieldOfInterest: json['fieldOfInterest'] ?? '',
      anticipation: json['anticipation'] ?? '',
      gender: json['gender'] ?? 'male',
      profileImage: json['profileImage'] ?? '',
      isOnline: json['isOnline'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      defaultResponseLevel: parseLevel(json['defaultResponseLevel'] as String?),
      autoDetectLevel: json['autoDetectLevel'] as bool? ?? true,
      preferredLevelKeywords: List<String>.from(
          (json['preferredLevelKeywords'] as List<dynamic>? ?? [])
              .cast<String>()),
      preferredLearningStyle: json['preferredLearningStyle'] as String?,
      childProfile: json['childProfile'] != null
          ? ChildProfile.fromJson(json['childProfile'] as Map<String, dynamic>)
          : null,
      // Phase 2
      detectedRole: json['detectedRole'] as String?,
      preferredPersonality: json['preferredPersonality'] as String? ?? 'dost',
      enableMoodDetection: json['enableMoodDetection'] as bool? ?? true,
      enableFestivalMode: json['enableFestivalMode'] as bool? ?? true,
      age: json['age'] as int? ?? 0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobileNumber': mobileNumber,
      'location': location,
      'fieldOfInterest': fieldOfInterest,
      'anticipation': anticipation,
      'gender': gender,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'defaultResponseLevel': defaultResponseLevel.name,
      'autoDetectLevel': autoDetectLevel,
      'preferredLevelKeywords': preferredLevelKeywords,
      'preferredLearningStyle': preferredLearningStyle,
      'childProfile': childProfile?.toJson(),
      // Phase 2
      'detectedRole': detectedRole,
      'preferredPersonality': preferredPersonality,
      'enableMoodDetection': enableMoodDetection,
      'enableFestivalMode': enableFestivalMode,
      'age': age,
    };
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? mobileNumber,
    String? location,
    String? fieldOfInterest,
    String? anticipation,
    String? gender,
    String? profileImage,
    bool? isOnline,
    DateTime? updatedAt,
    ResponseLevel? defaultResponseLevel,
    bool? autoDetectLevel,
    List<String>? preferredLevelKeywords,
    String? preferredLearningStyle,
    ChildProfile? childProfile,
    // Phase 2
    String? detectedRole,
    String? preferredPersonality,
    bool? enableMoodDetection,
    bool? enableFestivalMode,
    int? age,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      location: location ?? this.location,
      fieldOfInterest: fieldOfInterest ?? this.fieldOfInterest,
      anticipation: anticipation ?? this.anticipation,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      defaultResponseLevel: defaultResponseLevel ?? this.defaultResponseLevel,
      autoDetectLevel: autoDetectLevel ?? this.autoDetectLevel,
      preferredLevelKeywords:
          preferredLevelKeywords ?? this.preferredLevelKeywords,
      preferredLearningStyle:
          preferredLearningStyle ?? this.preferredLearningStyle,
      childProfile: childProfile ?? this.childProfile,
      // Phase 2
      detectedRole: detectedRole ?? this.detectedRole,
      preferredPersonality: preferredPersonality ?? this.preferredPersonality,
      enableMoodDetection: enableMoodDetection ?? this.enableMoodDetection,
      enableFestivalMode: enableFestivalMode ?? this.enableFestivalMode,
      age: age ?? this.age,
    );
  }

  // Get profile image path based on gender
  String getProfileImagePath() {
    if (profileImage.isNotEmpty) {
      return profileImage;
    }
    return gender.toLowerCase() == 'female'
        ? 'assets/images/female.jpg'
        : 'assets/images/male.jpg';
  }

  // Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  // Create from JSON string
  factory UserProfile.fromJsonString(String jsonString) {
    return UserProfile.fromJson(jsonDecode(jsonString));
  }
}

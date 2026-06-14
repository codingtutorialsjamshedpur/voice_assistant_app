library developer_info_service;

import 'package:get/get.dart';

class DeveloperInfo {
  final String name;
  final String city;
  final String country;
  final String role;

  DeveloperInfo({
    required this.name,
    required this.city,
    required this.country,
    required this.role,
  });
}

class DeveloperQueryResult {
  final bool isDeveloperQuery;
  final double confidence;
  final String? reason;

  DeveloperQueryResult({
    required this.isDeveloperQuery,
    this.confidence = 0.0,
    this.reason,
  });

  @override
  String toString() =>
      'DeveloperQueryResult(isQuery: $isDeveloperQuery, confidence: $confidence)';
}

class DeveloperInfoService extends GetxService {
  static final DeveloperInfo devInfo = DeveloperInfo(
    name: 'Sourav Kumar',
    city: 'Jamshedpur',
    country: 'India',
    role: 'Flutter Developer',
  );

  static final List<String> developerQueryKeywords = [
    'who made', 'who created', 'who built', 'who developed',
    'who is the developer', 'who is the creator', 'who is your creator',
    'who is your father', 'who is your dad', 'who is your daddy',
    'who gave you birth', 'who made you', 'who created you',
    'who developed this app', 'who made this app', 'who built this app',
    'who created this app', 'app creator', 'app maker', 'app developer',
    'app father', 'app owner', 'inventor', 'creator', 'author',
    'father of this app', 'father of this', 'maker of this app',
    'who owns', 'who built this', 'who created this',
    'contact developer', 'reach developer', 'speak to developer',
    'talk to developer', 'contact your creator', 'contact creator',
    'i want to create an app', 'build an app for me',
    'make a project for me', 'make an app for me',
    'your creator', 'your developer', 'your father', 'your dad',
    'your daddy', 'who gave birth',
  ];

  static final Map<String, List<String>> developerKeywordsByLanguage = {
    'en': developerQueryKeywords,
    'hi': [
      'डेवलपर', 'निर्माता', 'बनाने वाला', 'कौन बनाया',
      'कौन बनाने वाला', 'यह ऐप्प किसने बनाया', 'ऐप्प का पिता',
      'ऐप्प का मालिक', 'ऐप्प के निर्माता', 'आपको किसने बनाया',
      'आपका पिता', 'आपके पिता', 'आपके निर्माता', 'आपका निर्माता',
      'जन्म दिया', 'किसने जन्म दिया', 'ऐप्प बनाने वाला',
      'संपर्क', 'संपर्क करो', 'बात करो',
    ],
    'hi-en': [
      'developer', 'who made', 'banaya', 'banya', 'banayega',
      'banenewala', 'maalik', 'malik', 'pita', 'pita ji',
      'baap', 'daddy', 'dad', 'father', 'creator',
      'kisne banaya', 'kaun banaya', 'aapko kisne banaya',
      'aapke pita', 'aapke baap', 'sristi', 'janam',
      'contact', 'sampark', 'baat karo',
    ],
  };

  static const String creatorResponse =
      'SHOURAV KUMAR is a Flutter developer from Jamshedpur, India. He is fond of new projects and you can approach him.';

  static const String contactResponse =
      'You can contact him via WhatsApp or Email.';

  DeveloperQueryResult detectDeveloperQuery(
    String userInput, {
    String? preferredLanguage = 'en',
  }) {
    final lower = userInput.toLowerCase().trim();
    if (lower.isEmpty) {
      return DeveloperQueryResult(
        isDeveloperQuery: false,
        reason: 'Empty input',
      );
    }

    // Check English keywords
    for (final kw in developerQueryKeywords) {
      if (lower.contains(kw)) {
        return DeveloperQueryResult(
          isDeveloperQuery: true,
          confidence: 0.9,
          reason: 'Keyword match: $kw',
        );
      }
    }

    // Check language-specific keywords
    if (preferredLanguage != null) {
      for (final entry in developerKeywordsByLanguage.entries) {
        if (preferredLanguage.startsWith(entry.key) ||
            entry.key.startsWith(preferredLanguage)) {
          for (final kw in entry.value) {
            if (lower.contains(kw)) {
              return DeveloperQueryResult(
                isDeveloperQuery: true,
                confidence: 0.9,
                reason: 'Language keyword match: $kw',
              );
            }
          }
        }
      }
    }

    return DeveloperQueryResult(
      isDeveloperQuery: false,
      reason: 'No developer keywords detected',
    );
  }

  String getDeveloperResponse({String? language = 'en'}) {
    return creatorResponse;
  }

  String getContactResponse({String? language = 'en'}) {
    return contactResponse;
  }
}

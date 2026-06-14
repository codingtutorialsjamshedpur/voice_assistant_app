import 'dart:math';

class FestivalInfo {
  final String name;
  final String country;
  final List<String> greetingVariations;
  final List<String> questions;
  final Map<String, List<String>> timeSpecificQuestions;

  FestivalInfo({
    required this.name,
    required this.country,
    required this.greetingVariations,
    required this.questions,
    this.timeSpecificQuestions = const {},
  });
}

class FestivalService {
  static final Map<String, FestivalInfo> _fixedFestivals = {
    '01-01': FestivalInfo(
      name: 'New Year',
      country: 'Global',
      greetingVariations: [
        'Happy New Year!',
        'Wishing you a fantastic year ahead!',
        'Happy 2026!'
      ],
      questions: [
        'What are your resolutions for this year?',
        'Did you stay up late for the countdown?',
        'Any big plans to start the year with a bang?',
      ],
      timeSpecificQuestions: {
        'morning': [
          'How was the countdown last night?',
          'Started your first day with a coffee or a walk?'
        ],
        'evening': [
          'Are you heading out for a New Year\'s dinner?',
          'How has the first day of 2026 treated you?'
        ],
      },
    ),
    '01-26': FestivalInfo(
      name: 'Republic Day',
      country: 'India',
      greetingVariations: [
        'Happy Republic Day!',
        'Jai Hind!',
        'Wishing you a proud Republic Day!'
      ],
      questions: [
        'Did you watch the parade on TV?',
        'Are there any celebrations happening near you?',
        'What does being an Indian mean to you today?',
      ],
    ),
    '12-25': FestivalInfo(
      name: 'Christmas',
      country: 'Global',
      greetingVariations: [
        'Merry Christmas!',
        'Happy Christmas!',
        'Wishing you a jolly Christmas!'
      ],
      questions: [
        'What are your plans for the big day?',
        'Are you taking the kids out or staying cozy?',
        'How\'s the family gathering going?',
        'Did you get everything on your wishlist?',
      ],
      timeSpecificQuestions: {
        'morning': [
          'Did you find anything special under the tree this morning?',
          'Ready for the Christmas brunch?'
        ],
        'afternoon': [
          'Enjoying the Christmas lunch with family?',
          'Are the kids busy with their new toys?'
        ],
        'evening': [
          'Ready for the Christmas dinner?',
          'How was your festive day, any favorite moments?'
        ],
      },
    ),
  };

  /// Lunar and variable festivals for 2026
  static final Map<String, FestivalInfo> _variableFestivals2026 = {
    '03-03': FestivalInfo(
      name: 'Holi',
      country: 'India/Nepal',
      greetingVariations: [
        'Happy Holi!',
        'Wishing you a colorful and joyful Holi!'
      ],
      questions: [
        'Have you played with colors yet today?',
        'What special desserts are you preparing for Holi?',
        'Are you having a gathering with friends or family?',
      ],
      timeSpecificQuestions: {
        'morning': [
          'Have you started playing with colors yet?',
          'Ready for some Gujiya and Thandai?'
        ],
        'afternoon': [
          'How are you enjoying the colors of the afternoon?',
          'Have you washed off the colors or still playing?'
        ],
        'evening': [
          'How was your Holi? Did you have a lot of fun with colors?',
          'Are you relaxing after a long day of festivities?'
        ],
      },
    ),
    '05-28': FestivalInfo(
      name: 'Eid ul-Adha (Day 2)',
      country: 'Global',
      greetingVariations: [
        'Eid Mubarak!',
        'Hope you\'re enjoying the second day of Eid!'
      ],
      questions: [
        'Are you visiting relatives or friends today?',
        'What are the plans for the festivities?',
      ],
      timeSpecificQuestions: {
        'morning': [
          'Ready for another day of Eid celebrations?',
          'Any special breakfast plans for the second day?'
        ],
        'afternoon': [
          'How are you enjoying the second day of Eid festivities?',
          'Enjoying the traditional lunch?'
        ],
        'evening': [
          'How has your second day of Eid been?',
          'Are you heading out for any evening gatherings?'
        ],
      },
    ),
    '11-08': FestivalInfo(
      name: 'Diwali',
      country: 'India/Global',
      greetingVariations: [
        'Happy Diwali!',
        'Wishing you a bright and prosperous Diwali!'
      ],
      questions: [
        'Are you lighting lamps and diyas tonight?',
        'How beautiful are the decorations at your place?',
        'Have you shared sweets with your neighbors yet?',
        'Got any big plans for the evening fireworks?',
      ],
      timeSpecificQuestions: {
        'evening': [
          'Are you all set for the Lakshmi Puja?',
          'Ready to enjoy the festive treats and fireworks?'
        ],
      },
    ),
  };

  /// Gets festival info for the current date
  static FestivalInfo? getFestivalForDate(DateTime date) {
    final String key =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Check variable 2026 festivals first
    if (date.year == 2026 && _variableFestivals2026.containsKey(key)) {
      return _variableFestivals2026[key];
    }

    // Fallback to fixed festivals
    return _fixedFestivals[key];
  }

  /// Gets a relevant question based on the festival and part of day
  static String getQuestion(FestivalInfo festival, String partOfDay) {
    final List<String> pool = [];
    final random = Random();

    // Add time-specific questions if they exist for this part of day
    if (festival.timeSpecificQuestions.containsKey(partOfDay.toLowerCase())) {
      pool.addAll(festival.timeSpecificQuestions[partOfDay.toLowerCase()]!);
    }

    // Always add general questions
    pool.addAll(festival.questions);

    if (pool.isEmpty) return 'How are you celebrating today?';

    return pool[random.nextInt(pool.length)];
  }
}

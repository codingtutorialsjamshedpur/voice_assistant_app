// File: lib/services/realtime_apis_config.dart
// Purpose: Centralized configuration for all real-time APIs
// Date: April 3, 2026

class RealtimeAPIsConfig {
  // ============ WEATHER APIs ============
  static const String openMeteoBaseUrl = 'https://api.open-meteo.com/v1';
  static const String weatherApiBaseUrl = 'https://api.weatherapi.com/v1';
  static const String openWeatherBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String openWeatherApiKey = '0bc1a7e9da6742b8a3bc7ea8b53df6d7';

  // ============ GEOGRAPHY APIs ============
  static const String restCountriesUrl = 'https://restcountries.com/v3.1';

  // ============ KNOWLEDGE APIs ============
  static const String wikipediaUrl = 'https://en.wikipedia.org/api/rest_v1';
  static const String simpleWikipediaUrl =
      'https://simple.wikipedia.org/api/rest_v1';
  static const String wiktionaryUrl = 'https://en.wiktionary.org/w/api.php';
  static const String dictionaryApiUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';
  static const String nasaBaseUrl = 'https://api.nasa.gov';
  static const String nasaApiKey = 'DEMO_KEY'; // Free key from api.nasa.gov
  static const String duckDuckGoUrl = 'https://api.duckduckgo.com';

  // ============ FINANCE APIs ============
  static const String coinGeckoUrl = 'https://api.coingecko.com/api/v3';
  static const String exchangeRateUrl = 'https://api.frankfurter.app';
  static const String yahooFinanceUrl =
      'https://query1.finance.yahoo.com/v10/finance/quoteSummary';

  // ============ NEWS APIs (100% Free Open Proxy) ============
  static const String sauravNewsApiBaseUrl = 'https://saurav.tech/NewsAPI';

  // ============ SPIRITUAL APIs ============
  static const String bhagavadGitaUrl = 'https://bhagavadgitaapi.in';
  static const String quranUrl = 'https://api.alquran.cloud/v1';

  // ============ CONFIG ============
  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration cacheExpiry = Duration(minutes: 30);

  // Language codes for API calls - Comprehensive list from language_constants.dart
  static const Map<String, String> languageMap = {
    // Main Languages
    'en-us': 'en',
    'en-gb': 'en',
    'english': 'en',
    'hindi': 'hi',
    'hinglish': 'hi', // Hinglish uses Hindi locale for APIs

    // Native Indian Languages
    'bengali': 'bn',
    'bn': 'bn',
    'punjabi': 'pa',
    'pa': 'pa',
    'tamil': 'ta',
    'ta': 'ta',
    'telugu': 'te',
    'te': 'te',
    'kannada': 'kn',
    'kn': 'kn',
    'malayalam': 'ml',
    'ml': 'ml',
    'gujarati': 'gu',
    'gu': 'gu',
    'marathi': 'mr',
    'mr': 'mr',
    'urdu': 'ur',
    'odia': 'or',
    'or': 'or',
    'assamese': 'as',
    'as': 'as',
    'maithili': 'mai',
    'mai': 'mai',
    'nepali': 'ne',
    'ne': 'ne',
    'sinhala': 'si',
    'si': 'si',
    'sanskrit': 'sa',
    'sa': 'sa',
    'kashmiri': 'ks',
    'ks': 'ks',

    // International Languages
    'fr': 'fr',
    'french': 'fr',
    'es': 'es',
    'spanish': 'es',
    'de': 'de',
    'german': 'de',
    'it': 'it',
    'italian': 'it',
    'pt': 'pt',
    'portuguese': 'pt',
    'ru': 'ru',
    'russian': 'ru',
    'ja': 'ja',
    'japanese': 'ja',
    'zh': 'zh',
    'chinese': 'zh',
    'ko': 'ko',
    'korean': 'ko',
    'ar': 'ar',
    'arabic': 'ar',
    'th': 'th',
    'thai': 'th',
    'vi': 'vi',
    'vietnamese': 'vi',
    'id': 'id',
    'indonesian': 'id',
    'ms': 'ms',
    'malay': 'ms',
    'tr': 'tr',
    'turkish': 'tr',
    'pl': 'pl',
    'polish': 'pl',
    'nl': 'nl',
    'dutch': 'nl',
    'sv': 'sv',
    'swedish': 'sv',
    'da': 'da',
    'danish': 'da',
    'no': 'no',
    'norwegian': 'no',
    'fi': 'fi',
    'finnish': 'fi',
    'cs': 'cs',
    'czech': 'cs',
    'hu': 'hu',
    'hungarian': 'hu',
    'ro': 'ro',
    'romanian': 'ro',
    'el': 'el',
    'greek': 'el',
    'he': 'he',
    'hebrew': 'he',
  };

  // Cache settings by query type
  static const Map<String, Duration> cacheExpiryByType = {
    'weather': Duration(minutes: 15),
    'news': Duration(minutes: 30),
    'crypto': Duration(minutes: 5),
    'currency': Duration(hours: 1),
    'geography': Duration(hours: 24),
    'wikipedia': Duration(hours: 24),
    'recipe': Duration(hours: 24),
  };
}

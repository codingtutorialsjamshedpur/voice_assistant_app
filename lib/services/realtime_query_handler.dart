// File: lib/services/realtime_query_handler.dart
// Purpose: Handle all real-time API calls for various query types
// Date: April 3, 2026

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'realtime_apis_config.dart';

class RealtimeQueryHandler {
  static const String tag = 'RealtimeQueryHandler';

  // ============ WEATHER QUERIES ============
  /// Fetch weather data for a given location
  Future<String?> fetchWeather(String location) async {
    try {
      debugPrint('🌤️ [$tag] Fetching weather (OpenWeather) for: $location');

      final url = '${RealtimeAPIsConfig.openWeatherBaseUrl}/weather'
          '?q=${Uri.encodeComponent(location)}'
          '&appid=${RealtimeAPIsConfig.openWeatherApiKey}'
          '&units=metric';

      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final main = data['main'];
        final wind = data['wind'];
        final weather = data['weather'][0];
        final city = data['name'];
        final sys = data['sys'];

        final String result = '''📍 Location: $city, ${sys['country']}

🌡️ Current Conditions:
  • Status: ${weather['main']} (${weather['description']})
  • Temperature: ${main['temp']?.toStringAsFixed(1)}°C (Feels like: ${main['feels_like']?.toStringAsFixed(1)}°C)
  • Humidity: ${main['humidity']}%
  • Pressure: ${main['pressure']} hPa
  • Wind Speed: ${wind['speed']?.toStringAsFixed(1)} m/s
  • Visibility: ${(data['visibility'] / 1000).toStringAsFixed(1)} km

📊 Summary:
  It is currently ${weather['description']} in $city with a temperature of ${main['temp']}°C.''';

        debugPrint('✅ [$tag] OpenWeather data fetched successfully');
        return result;
      } else {
        debugPrint(
            '⚠️ [$tag] OpenWeather failed (${response.statusCode}), falling back to Open-Meteo');
        return await _fetchWeatherOpenMeteo(location);
      }
    } catch (e) {
      debugPrint('❌ [$tag] Weather fetch error: $e. Using fallback.');
      return await _fetchWeatherOpenMeteo(location);
    }
  }

  /// Fallback: Fetch weather from Open-Meteo
  Future<String?> _fetchWeatherOpenMeteo(String location) async {
    try {
      debugPrint(
          '🌤️ [$tag] Fetching fallback weather (Open-Meteo) for: $location');

      // First, get coordinates from location name
      final geoUrl =
          'https://geocoding-api.open-meteo.com/v1/search?name=$location&count=1&language=en&format=json';
      final geoResponse = await http
          .get(Uri.parse(geoUrl))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (geoResponse.statusCode != 200) return null;

      final geoData = jsonDecode(geoResponse.body);
      if (geoData['results'] == null || geoData['results'].isEmpty) return null;

      final lat = geoData['results'][0]['latitude'];
      final lon = geoData['results'][0]['longitude'];
      final locName = geoData['results'][0]['name'];
      final country = geoData['results'][0]['country'] ?? '';

      // Fetch weather
      final weatherUrl = '${RealtimeAPIsConfig.openMeteoBaseUrl}/forecast'
          '?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation'
          '&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_sum,precipitation_probability_max'
          '&timezone=auto&forecast_days=7';

      final weatherResponse = await http
          .get(Uri.parse(weatherUrl))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (weatherResponse.statusCode != 200) return null;

      final weatherData = jsonDecode(weatherResponse.body);
      final current = weatherData['current'];
      final daily = weatherData['daily'];

      final String result = '''📍 Location: $locName, $country

🌡️ Current Conditions:
  • Temperature: ${current['temperature_2m']?.toStringAsFixed(1) ?? 'N/A'}°C
  • Humidity: ${current['relative_humidity_2m']}%
  • Wind Speed: ${current['wind_speed_10m']?.toStringAsFixed(1) ?? 'N/A'} km/h
  • Precipitation: ${current['precipitation']?.toStringAsFixed(1) ?? '0'} mm

📊 Today's Forecast:
  • High: ${daily['temperature_2m_max'][0]?.toStringAsFixed(1) ?? 'N/A'}°C
  • Low: ${daily['temperature_2m_min'][0]?.toStringAsFixed(1) ?? 'N/A'}°C
  • Chance of Rain: ${daily['precipitation_probability_max'][0] ?? 0}%''';

      debugPrint('✅ [$tag] Fallback weather (Open-Meteo) fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Fallback fetch error: $e');
      return null;
    }
  }

  // ============ COUNTRY/GEOGRAPHY QUERIES ============
  /// Fetch detailed country information
  Future<String?> fetchCountryInfo(String countryName) async {
    try {
      debugPrint('🌍 [$tag] Fetching country info: $countryName');

      final url =
          '${RealtimeAPIsConfig.restCountriesUrl}/name/${Uri.encodeComponent(countryName)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('❌ [$tag] Country fetch failed: ${response.statusCode}');
        return null;
      }

      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) {
        debugPrint('❌ [$tag] Country not found: $countryName');
        return null;
      }

      final country = data[0];
      final String? capital =
          (country['capital'] is List && country['capital'].isNotEmpty)
              ? country['capital'][0]
              : 'N/A';
      final String currencies = country['currencies'] is Map &&
              (country['currencies'] as Map).isNotEmpty
          ? (country['currencies'] as Map)
              .values
              .map((c) => c is Map ? c['name'] ?? c['symbol'] : c.toString())
              .join(', ')
          : 'N/A';
      final String languages = country['languages'] is Map &&
              (country['languages'] as Map).isNotEmpty
          ? (country['languages'] as Map).values.join(', ')
          : 'N/A';

      final String result =
          '''🏛️ Country: ${country['name']['common'] ?? 'N/A'}

📍 Geography:
  • Capital: $capital
  • Region: ${country['region'] ?? 'N/A'}
  • Subregion: ${country['subregion'] ?? 'N/A'}
  • Area: ${country['area']?.toStringAsFixed(0) ?? 'N/A'} km²

👥 Demographics:
  • Population: ${(country['population'] ?? 0).toString().padLeft(1)}
  • Languages: $languages

💱 Economics:
  • Currencies: $currencies
  • Timezones: ${(country['timezones'] is List ? (country['timezones'] as List).join(', ') : 'N/A')}''';

      debugPrint('✅ [$tag] Country info fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Country fetch error: $e');
      return null;
    }
  }

  // ============ WIKIPEDIA QUERIES ============
  /// Fetch Wikipedia summary for a topic
  Future<String?> fetchWikipediaInfo(String topic) async {
    try {
      debugPrint('📚 [$tag] Fetching Wikipedia info: $topic');

      final url =
          '${RealtimeAPIsConfig.wikipediaUrl}/page/summary/${Uri.encodeComponent(topic)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('❌ [$tag] Wikipedia fetch failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['extract'] == null || data['extract'].toString().isEmpty) {
        debugPrint('❌ [$tag] No extract found for: $topic');
        return null;
      }

      // Limit extract to 500 characters for conciseness
      String extract = data['extract'].toString();
      if (extract.length > 500) {
        extract = '${extract.substring(0, 500)}...';
      }

      final String result = '''📖 ${data['title'] ?? topic}

$extract

🔗 More Info: ${data['content_urls']['desktop']['page'] ?? 'N/A'}''';

      debugPrint('✅ [$tag] Wikipedia info fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Wikipedia fetch error: $e');
      return null;
    }
  }

  /// Fetch Simple Wikipedia summary for a topic (Kid friendly)
  Future<String?> fetchSimpleWikipediaInfo(String topic) async {
    try {
      debugPrint('📚 [$tag] Fetching Simple Wikipedia info: $topic');

      final url =
          '${RealtimeAPIsConfig.simpleWikipediaUrl}/page/summary/${Uri.encodeComponent(topic)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        // Fallback to standard wikipedia if simple fails
        return await fetchWikipediaInfo(topic);
      }

      final data = jsonDecode(response.body);
      String extract = data['extract']?.toString() ?? '';

      if (extract.isEmpty) return await fetchWikipediaInfo(topic);

      if (extract.length > 500) {
        extract = '${extract.substring(0, 500)}...';
      }

      final String result =
          '''📖 Topic: ${data['title'] ?? topic} (Simple English)

$extract''';

      debugPrint('✅ [$tag] Simple Wikipedia info fetched');
      return result;
    } catch (e) {
      return await fetchWikipediaInfo(topic);
    }
  }

  // ============ DICTIONARY QUERIES ============
  /// Fetch dictionary definition for a word
  Future<String?> fetchDictionaryDefinition(String word) async {
    try {
      debugPrint('📖 [$tag] Fetching definition for: $word');

      final url =
          '${RealtimeAPIsConfig.dictionaryApiUrl}/${Uri.encodeComponent(word)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) return null;

      final entry = data[0];
      final wordName = entry['word'] ?? word;
      final phonetic = entry['phonetic'] ?? '';
      final List meanings = entry['meanings'] ?? [];

      String result =
          '📘 Definition: $wordName ${phonetic.isNotEmpty ? "[$phonetic]" : ""}\n\n';

      for (var meaning in meanings.take(2)) {
        final partOfSpeech = meaning['partOfSpeech'] ?? 'meaning';
        final List definitions = meaning['definitions'] ?? [];
        if (definitions.isNotEmpty) {
          result +=
              '• (${partOfSpeech.toUpperCase()}): ${definitions[0]['definition']}\n';
          if (definitions[0]['example'] != null) {
            result += '  Example: "${definitions[0]['example']}"\n';
          }
        }
      }

      debugPrint('✅ [$tag] Definition fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Dictionary fetch error: $e');
      return null;
    }
  }

  // ============ SPACE QUERIES ============
  /// Fetch NASA Astronomy Picture of the Day
  Future<String?> fetchNasaApod() async {
    try {
      debugPrint('🚀 [$tag] Fetching NASA APOD');

      const url =
          '${RealtimeAPIsConfig.nasaBaseUrl}/planetary/apod?api_key=${RealtimeAPIsConfig.nasaApiKey}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final title = data['title'] ?? 'Space Magic';
      final explanation = data['explanation']?.toString() ?? '';

      String cleanExp = explanation;
      if (cleanExp.length > 400) {
        cleanExp = '${cleanExp.substring(0, 400)}...';
      }

      final String result = '''🚀 NASA Astronomy Picture: $title

$cleanExp''';

      debugPrint('✅ [$tag] NASA APOD fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] NASA APOD error: $e');
      return null;
    }
  }

  // ============ QUICK ANSWERS ============
  /// Fetch quick answer from DuckDuckGo
  Future<String?> fetchDuckDuckGoAnswer(String query) async {
    try {
      debugPrint('🦆 [$tag] Fetching DDG quick answer: $query');

      final url =
          '${RealtimeAPIsConfig.duckDuckGoUrl}/?q=${Uri.encodeComponent(query)}&format=json&no_html=1';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final abstractText = data['AbstractText']?.toString() ?? '';

      if (abstractText.isEmpty) return null;

      final String result = '''🔍 Quick Fact:
$abstractText''';

      debugPrint('✅ [$tag] DDG answer fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] DDG error: $e');
      return null;
    }
  }

  // ============ CRYPTOCURRENCY QUERIES ============
  /// Fetch cryptocurrency price
  Future<String?> fetchCryptoPrice(String cryptoId) async {
    try {
      debugPrint('💰 [$tag] Fetching crypto price: $cryptoId');

      final url = '${RealtimeAPIsConfig.coinGeckoUrl}/simple/price'
          '?ids=${cryptoId.toLowerCase()}'
          '&vs_currencies=usd,inr,eur&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true';

      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('❌ [$tag] Crypto fetch failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final cryptoData = data[cryptoId.toLowerCase()];

      if (cryptoData == null) {
        debugPrint('❌ [$tag] Crypto not found: $cryptoId');
        return null;
      }

      final String result = '''💎 ${cryptoId.toUpperCase()}

💵 Current Price:
  • USD: \$${cryptoData['usd']?.toStringAsFixed(2) ?? 'N/A'}
  • EUR: €${cryptoData['eur']?.toStringAsFixed(2) ?? 'N/A'}
  • INR: ₹${cryptoData['inr']?.toStringAsFixed(2) ?? 'N/A'}

📊 Market Data:
  • Market Cap (USD): \$${cryptoData['usd_market_cap'] ?? 'N/A'}
  • 24h Volume: \$${cryptoData['usd_24h_vol'] ?? 'N/A'}
  • 24h Change: ${cryptoData['usd_24h_change']?.toStringAsFixed(2) ?? 'N/A'}%''';

      debugPrint('✅ [$tag] Crypto price fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Crypto fetch error: $e');
      return null;
    }
  }

  // ============ CURRENCY CONVERSION ============
  /// Fetch currency exchange rate
  Future<String?> fetchCurrencyRate(
      String fromCurrency, String toCurrency) async {
    try {
      debugPrint(
          '💱 [$tag] Fetching currency rate: $fromCurrency -> $toCurrency');

      final url = '${RealtimeAPIsConfig.exchangeRateUrl}/latest'
          '?from=${fromCurrency.toUpperCase()}&to=${toCurrency.toUpperCase()}';

      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('❌ [$tag] Currency fetch failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final rate = data['rates'][toCurrency.toUpperCase()];

      if (rate == null) {
        debugPrint('❌ [$tag] Rate not found for: $fromCurrency -> $toCurrency');
        return null;
      }

      final String result = '''💱 Currency Exchange

📊 Rate:
  • 1 ${fromCurrency.toUpperCase()} = $rate ${toCurrency.toUpperCase()}

🕐 Last Updated: ${data['date'] ?? 'N/A'}

💡 Tip: Rates update daily at 00:00 UTC''';

      debugPrint('✅ [$tag] Currency rate fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Currency fetch error: $e');
      return null;
    }
  }

  // ============ NEWS QUERIES ============
  /// Fetch latest news using SauravKanchan NewsAPI (Free)
  Future<String?> fetchNews(String query) async {
    try {
      debugPrint('📰 [$tag] Fetching news: $query');

      final lowerQuery = query.toLowerCase();

      // Detect category
      String category = 'general';
      if (lowerQuery.contains('tech') || lowerQuery.contains('technology')) {
        category = 'technology';
      } else if (lowerQuery.contains('business') ||
          lowerQuery.contains('finance') ||
          lowerQuery.contains('economy')) {
        category = 'business';
      } else if (lowerQuery.contains('sport')) {
        category = 'sports';
      } else if (lowerQuery.contains('health') ||
          lowerQuery.contains('medical')) {
        category = 'health';
      } else if (lowerQuery.contains('science')) {
        category = 'science';
      } else if (lowerQuery.contains('entertainment') ||
          lowerQuery.contains('movie') ||
          lowerQuery.contains('bollywood') ||
          lowerQuery.contains('hollywood')) {
        category = 'entertainment';
      }

      // Detect country
      String countryCode = 'in'; // Default to India
      if (lowerQuery.contains('usa') ||
          lowerQuery.contains('america') ||
          lowerQuery.contains('united states')) {
        countryCode = 'us';
      } else if (lowerQuery.contains('uk') ||
          lowerQuery.contains('britain') ||
          lowerQuery.contains('united kingdom') ||
          lowerQuery.contains('london')) {
        countryCode = 'gb';
      } else if (lowerQuery.contains('australia')) {
        countryCode = 'au';
      } else if (lowerQuery.contains('russia')) {
        countryCode = 'ru';
      } else if (lowerQuery.contains('france')) {
        countryCode = 'fr';
      }

      final url =
          '${RealtimeAPIsConfig.sauravNewsApiBaseUrl}/top-headlines/category/$category/$countryCode.json';

      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('❌ [$tag] News fetch failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['articles'] == null || (data['articles'] as List).isEmpty) {
        debugPrint('❌ [$tag] No articles found for: $category in $countryCode');
        return null;
      }

      final List articles = data['articles'];
      final topArticles =
          articles.take(4).toList(); // Top 4 articles for better context

      String result =
          '📰 Latest ${category.toUpperCase()} News ($countryCode):\n\n';
      for (var i = 0; i < topArticles.length; i++) {
        final article = topArticles[i];
        final String title = article['title'] ?? 'No Title';
        final String source = article['source']['name'] ?? 'Unknown Source';
        final String description = article['description'] ?? '';

        result += '${i + 1}. $title\n';
        result += '   📍 Source: $source\n';
        if (description.isNotEmpty) {
          final String shortDesc = description.length > 120
              ? '${description.substring(0, 120)}...'
              : description;
          result += '   📝 $shortDesc\n';
        }
        result += '\n';
      }

      debugPrint('✅ [$tag] News fetched successfully from SauravNewsAPI');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] News fetch error: $e');
      return null;
    }
  }

  // ============ MUSIC QUERIES ============
  /// Fetch music tracks based on mood using Jamendo API
  Future<String?> fetchMusic(String mood) async {
    try {
      debugPrint('🎵 [$tag] Fetching music for mood: $mood');

      // Use a common client ID for Jamendo (or user can get their own)
      const clientId = '56d30c95';
      final url =
          'https://api.jamendo.com/v3.0/tracks/?client_id=$clientId&format=json&limit=5&fuzzytags=${Uri.encodeComponent(mood)}&orderby=ratingweek_desc';

      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];

      if (results.isEmpty) {
        // Fallback to general relaxing music if specific mood fails
        return await fetchMusic('relaxing');
      }

      String result =
          '🎵 I found some $mood music to help you feel better:\n\n';

      for (var i = 0; i < results.length; i++) {
        final track = results[i];
        final title = track['name'] ?? 'Unknown Track';
        final artist = track['artist_name'] ?? 'Unknown Artist';
        final audioUrl = track['audio'] ?? '';

        result += '${i + 1}. "$title" by $artist\n';
        if (audioUrl.isNotEmpty) {
          result += '   🔗 Listen: $audioUrl\n';
          // Machine-readable tag for the service hand-off
          result += '   [PLAY_URL:$audioUrl|$title]\n';
        }
        result += '\n';
      }

      result +=
          '💡 You can copy these links to your browser to play them, or ask me to "Play track 1"!';

      debugPrint('✅ [$tag] Music fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Music fetch error: $e');
      return null;
    }
  }

  // ============ BHAGAVAD GITA QUERIES ============
  /// Fetch Bhagavad Gita verse
  Future<String?> fetchBhagavadGita(int chapterNumber) async {
    try {
      debugPrint('📿 [$tag] Fetching Bhagavad Gita - Chapter $chapterNumber');

      final url =
          '${RealtimeAPIsConfig.bhagavadGitaUrl}/chapter/$chapterNumber/verses/';
      final response = await http
          .get(Uri.parse(url))
          .timeout(RealtimeAPIsConfig.requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
            '❌ [$tag] Bhagavad Gita fetch failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as List;
      if (data.isEmpty) {
        debugPrint('❌ [$tag] No verses found for chapter: $chapterNumber');
        return null;
      }

      // Get first verse
      final verse = data[0];

      final String result = '''📿 Bhagavad Gita

अध्याय (Chapter): ${verse['chapter']}
श्लोक (Verse): ${verse['verse']}

${verse['text'] ?? 'N/A'}

📖 Meaning:
${verse['transliteration'] ?? 'N/A'}''';

      debugPrint('✅ [$tag] Bhagavad Gita verse fetched');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Bhagavad Gita fetch error: $e');
      return null;
    }
  }

  // ============ NEARBY PLACES / OVERPASS ============
  /// Fetch nearby places using Overpass API
  Future<String?> fetchNearbyPlaces(String query) async {
    try {
      debugPrint('📍 [$tag] Fetching nearby places for: $query');

      // Expand basic POI types
      String poiType = 'amenity="point_of_interest"'; // default loose search
      final lower = query.toLowerCase();

      if (lower.contains('temple') ||
          lower.contains('church') ||
          lower.contains('mosque') ||
          lower.contains('worship')) {
        poiType = 'amenity="place_of_worship"';
      } else if (lower.contains('restaurant') ||
          lower.contains('food') ||
          lower.contains('cafe')) {
        poiType = 'amenity~"restaurant|cafe|fast_food"';
      } else if (lower.contains('hospital') ||
          lower.contains('clinic') ||
          lower.contains('doctor')) {
        poiType = 'amenity~"hospital|clinic|doctors"';
      } else if (lower.contains('park')) {
        poiType = 'leisure="park"';
      } else if (lower.contains('hotel') || lower.contains('lodging')) {
        poiType = 'tourism="hotel"';
      } else if (lower.contains('atm') || lower.contains('bank')) {
        poiType = 'amenity~"atm|bank"';
      } else if (lower.contains('petrol') ||
          lower.contains('gas') ||
          lower.contains('fuel')) {
        poiType = 'amenity="fuel"';
      } else if (lower.contains('school') || lower.contains('college')) {
        poiType = 'amenity~"school|college|university"';
      }

      // Check permissions and get current position
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled)
        return 'I need GPS access to find nearby places. Please enable Location Services.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return 'GPS permission is denied. I cannot find nearby places.';
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      final lat = position.latitude;
      final lon = position.longitude;

      // Query OpenStreetMap Overpass (3000m radius)
      final overpassQuery =
          '[out:json];(node[$poiType](around:3000,$lat,$lon);way[$poiType](around:3000,$lat,$lon););out center 5;';
      final url =
          'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List;

      if (elements.isEmpty) {
        return 'I could not find any such places within a 3km radius from your current location.';
      }

      String result = '📍 Nearby Places found for your request:\\n\\n';
      int validCount = 0;

      for (var element in elements) {
        // ways return center lat/lon
        final elat = element['lat'] ?? element['center']?['lat'];
        final elon = element['lon'] ?? element['center']?['lon'];
        if (elat == null || elon == null) continue;

        final tags = element['tags'] ?? {};
        final name = tags['name'] ??
            tags['name:en'] ??
            tags['brand'] ??
            'Unknown location';
        if (name == 'Unknown location' || name.toString().trim().isEmpty)
          continue;

        final distMeters = Geolocator.distanceBetween(lat, lon, elat, elon);

        result += '• $name (';
        if (distMeters < 1000) {
          result += '${distMeters.toStringAsFixed(0)} meters away)\\n';
        } else {
          result +=
              '${(distMeters / 1000).toStringAsFixed(1)} kilometers away)\\n';
        }
        validCount++;
        if (validCount >= 5) break;
      }

      if (validCount == 0)
        return 'I found some nearby places but they don\'t have identifiable names on the map.';

      debugPrint('✅ [$tag] Nearby places fetched successfully');
      return result;
    } catch (e) {
      debugPrint('❌ [$tag] Nearby places error: $e');
      return 'I encountered a communication glitch while trying to map nearby places. Please try again later.';
    }
  }

  // ============ UTILITY METHODS ============
  /// Clean up response text
  String cleanResponse(String response) {
    return response.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Format response for display
  String formatResponse(String response) {
    return response.replaceAll('\n', '\n  ');
  }

  /// Check if API is available
  Future<bool> checkApiHealth() async {
    try {
      final response = await http
          .get(Uri.parse(RealtimeAPIsConfig.openMeteoBaseUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

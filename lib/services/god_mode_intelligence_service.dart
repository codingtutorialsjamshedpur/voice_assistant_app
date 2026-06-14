import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'festival_service.dart';
import 'ruflo_service.dart';

class EnvironmentData {
  final int aqi;
  final double pm25;
  final double pm10;
  final int humidity;

  EnvironmentData({
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.humidity,
  });
}

class WeatherData {
  final double temperature;
  final double feelsLike;
  final int rainChance;
  final double windSpeed;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.rainChance,
    required this.windSpeed,
  });
}

class SunData {
  final String sunrise;
  final String sunset;
  final String daylightRemaining;

  SunData({
    required this.sunrise,
    required this.sunset,
    required this.daylightRemaining,
  });
}

class MoonData {
  final String phase;
  final int illumination;
  final String recommendations;

  MoonData({
    required this.phase,
    required this.illumination,
    required this.recommendations,
  });
}

class HealthData {
  final double uvIndex;
  final String pollenInfo;
  final String outdoorSafety;

  HealthData({
    required this.uvIndex,
    required this.pollenInfo,
    required this.outdoorSafety,
  });
}

class EmergencyData {
  final String police;
  final String fire;
  final String ambulance;
  final String standardGeneral;

  EmergencyData({
    required this.police,
    required this.fire,
    required this.ambulance,
    required this.standardGeneral,
  });
}

class LocalData {
  final String city;
  final String state;
  final String countryCode;
  final String festival;
  final String languageSuggestions;

  LocalData({
    required this.city,
    required this.state,
    required this.countryCode,
    required this.festival,
    required this.languageSuggestions,
  });
}

class GodModeData {
  final EnvironmentData environment;
  final WeatherData weather;
  final SunData sun;
  final MoonData moon;
  final HealthData health;
  final LocalData local;
  final EmergencyData emergency;
  final String smartAlerts;

  GodModeData({
    required this.environment,
    required this.weather,
    required this.sun,
    required this.moon,
    required this.health,
    required this.local,
    required this.emergency,
    required this.smartAlerts,
  });

  Map<String, dynamic> toJson() => {
        'environment': {
          'aqi': environment.aqi,
          'pm25': environment.pm25,
          'pm10': environment.pm10,
          'humidity': environment.humidity,
        },
        'weather': {
          'temperature': weather.temperature,
          'feelsLike': weather.feelsLike,
          'rainChance': weather.rainChance,
          'windSpeed': weather.windSpeed,
        },
        'sun': {
          'sunrise': sun.sunrise,
          'sunset': sun.sunset,
        },
        'moon': {
          'phase': moon.phase,
          'illumination': moon.illumination,
        },
        'health': {
          'uvIndex': health.uvIndex,
          'pollenInfo': health.pollenInfo,
          'outdoorSafety': health.outdoorSafety,
        },
        'local': {
          'city': local.city,
          'state': local.state,
          'countryCode': local.countryCode,
          'festival': local.festival,
        },
        'emergency': {
          'police': emergency.police,
          'ambulance': emergency.ambulance,
          'fire': emergency.fire,
        },
        'smartAlerts': smartAlerts,
        'timestamp': DateTime.now().toIso8601String(),
      };
}

class GodModeIntelligenceService extends GetxService {
  final Rx<GodModeData?> data = Rx<GodModeData?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMsg = ''.obs;

  DateTime? _lastFetchTime;

  Future<GodModeIntelligenceService> init() async {
    return this;
  }

  Future<void> fetchAllIntelligence({
    required double lat,
    required double lon,
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && _lastFetchTime != null && data.value != null) {
        final diff = DateTime.now().difference(_lastFetchTime!);
        if (diff.inMinutes < 30) {
          debugPrint('God Mode: Using cached intelligence data.');
          return;
        }
      }

      isLoading.value = true;
      errorMsg.value = '';

      // Check cache first if preferred. Here we fetch direct for simplicity.

      // 1. Nominatim Reverse Geocode
      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final geoRes = await http.get(geoUrl, headers: {
        'User-Agent': 'CTJ_AI_Voice_Assistant/1.0',
      }).timeout(const Duration(seconds: 8));

      String state = '';
      String city = '';
      String countryCode = 'us';
      if (geoRes.statusCode == 200) {
        final geoJson = jsonDecode(geoRes.body);
        state = geoJson['address']?['state'] ?? '';
        countryCode =
            geoJson['address']?['country_code']?.toString().toLowerCase() ??
                'us';
        city = geoJson['address']?['city'] ??
            geoJson['address']?['town'] ??
            geoJson['address']?['village'] ??
            geoJson['address']?['county'] ??
            state;
      }

      // 2. Weather & Sun
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,wind_speed_10m&daily=sunrise,sunset,uv_index_max,precipitation_probability_max&timezone=auto',
      );
      final weatherRes =
          await http.get(weatherUrl).timeout(const Duration(seconds: 8));

      double currentTemp = 0.0;
      double feelsLike = 0.0;
      int humidity = 0;
      double windSpeed = 0.0;
      String sunrise = '--:--';
      String sunset = '--:--';
      int pop = 0; // chance of rain
      double uvMax = 0.0;

      if (weatherRes.statusCode == 200) {
        final wData = jsonDecode(weatherRes.body);
        final current = wData['current'] ?? {};
        final daily = wData['daily'] ?? {};

        currentTemp = (current['temperature_2m'] ?? 0).toDouble();
        feelsLike = (current['apparent_temperature'] ?? 0).toDouble();
        humidity = (current['relative_humidity_2m'] ?? 0).toInt();
        windSpeed = (current['wind_speed_10m'] ?? 0).toDouble();

        if (daily['sunrise'] != null && (daily['sunrise'] as List).isNotEmpty) {
          sunrise = _formatTime(daily['sunrise'][0]);
        }
        if (daily['sunset'] != null && (daily['sunset'] as List).isNotEmpty) {
          sunset = _formatTime(daily['sunset'][0]);
        }
        if (daily['precipitation_probability_max'] != null &&
            (daily['precipitation_probability_max'] as List).isNotEmpty) {
          pop = (daily['precipitation_probability_max'][0] ?? 0).toInt();
        }
        if (daily['uv_index_max'] != null &&
            (daily['uv_index_max'] as List).isNotEmpty) {
          uvMax = (daily['uv_index_max'][0] ?? 0).toDouble();
        }
      }

      // 3. Air Quality & Pollen
      final aqiUrl = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi,pm10,pm2_5,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen',
      );
      final aqiRes = await http.get(aqiUrl).timeout(const Duration(seconds: 8));

      int aqi = 0;
      double pm25 = 0.0;
      double pm10 = 0.0;
      double grassPollen = 0.0;

      if (aqiRes.statusCode == 200) {
        final aData = jsonDecode(aqiRes.body);
        final current = aData['current'] ?? {};
        aqi = (current['us_aqi'] ?? 0).toInt();
        pm25 = (current['pm2_5'] ?? 0).toDouble();
        pm10 = (current['pm10'] ?? 0).toDouble();
        grassPollen = (current['grass_pollen'] ?? 0).toDouble();
      }

      // 4. Moon Phase (Approximation or use API)
      final moonPhaseResult = _calculateSimpleMoonPhase();

      // 5. Smart Health & Smart Alerts logic
      String outdoorSafety = 'Safe to go outdoors';
      String smartAlertsPool = '';
      if (aqi > 150) {
        outdoorSafety = 'Unhealthy (Avoid outdoor exercise)';
        smartAlertsPool += 'AQI is unhealthy today. ';
      } else if (aqi > 100) {
        outdoorSafety = 'Moderate (Sensitive groups take care)';
      }

      if (uvMax >= 7) {
        smartAlertsPool += 'UV levels are very high. Use sunscreen. ';
      } else if (uvMax >= 4) {
        smartAlertsPool += 'Moderate UV levels. ';
      }

      if (pop > 60) {
        smartAlertsPool += 'High chance of rain today. ';
      }

      String pollenInfo = 'Low pollen';
      if (grassPollen > 10) {
        pollenInfo = 'High Grass Pollen';
        smartAlertsPool += 'High pollen levels detected. ';
      }

      // 6. Language Suggestions based on State
      String languages = _getLanguagesForState(state);

      // 7. Festivals
      final fest = FestivalService.getFestivalForDate(DateTime.now());
      String festivalName = fest?.name ?? 'No major festival';
      if (fest != null && smartAlertsPool.length < 50) {
        smartAlertsPool += 'Happy ${fest.name}! ';
      }

      if (smartAlertsPool.isEmpty) {
        smartAlertsPool = 'Conditions are pleasant. Have a great day!';
      }

      // Calculate daylight remaining
      String daylightRemaining = _calculateDaylightRemaining(sunset);

      // 8. Emergency Numbers Matrix
      EmergencyData emergency = EmergencyData(
          police: '911', fire: '911', ambulance: '911', standardGeneral: '911');
      switch (countryCode) {
        case 'in': // India
          emergency = EmergencyData(
              police: '100',
              fire: '101',
              ambulance: '102 / 108',
              standardGeneral: '112');
          break;
        case 'gb': // UK
          emergency = EmergencyData(
              police: '999',
              fire: '999',
              ambulance: '999',
              standardGeneral: '112 / 999');
          break;
        case 'au': // Australia
          emergency = EmergencyData(
              police: '000',
              fire: '000',
              ambulance: '000',
              standardGeneral: '000');
          break;
        case 'jp': // Japan
          emergency = EmergencyData(
              police: '110',
              fire: '119',
              ambulance: '119',
              standardGeneral: '119');
          break;
        case 'nz': // New Zealand
          emergency = EmergencyData(
              police: '111',
              fire: '111',
              ambulance: '111',
              standardGeneral: '111');
          break;
        case 'cn': // China
          emergency = EmergencyData(
              police: '110',
              fire: '119',
              ambulance: '120',
              standardGeneral: '112');
          break;
        case 'br': // Brazil
          emergency = EmergencyData(
              police: '190',
              fire: '193',
              ambulance: '192',
              standardGeneral: '190');
          break;
        // EU Countries standard
        case 'fr':
        case 'de':
        case 'it':
        case 'es':
        case 'nl':
        case 'se':
          emergency = EmergencyData(
              police: '112',
              fire: '112',
              ambulance: '112',
              standardGeneral: '112');
          break;
      }

      data.value = GodModeData(
        environment: EnvironmentData(
          aqi: aqi,
          pm25: pm25,
          pm10: pm10,
          humidity: humidity,
        ),
        weather: WeatherData(
          temperature: currentTemp,
          feelsLike: feelsLike,
          rainChance: pop,
          windSpeed: windSpeed,
        ),
        sun: SunData(
          sunrise: sunrise,
          sunset: sunset,
          daylightRemaining: daylightRemaining,
        ),
        moon: MoonData(
          phase: moonPhaseResult['phase'] ?? 'Unknown',
          illumination: moonPhaseResult['illumination']?.toInt() ?? 0,
          recommendations: 'Visibility depends on cloud cover',
        ),
        health: HealthData(
          uvIndex: uvMax,
          pollenInfo: pollenInfo,
          outdoorSafety: outdoorSafety,
        ),
        local: LocalData(
          city: city,
          state: state,
          countryCode: countryCode,
          festival: festivalName,
          languageSuggestions: languages,
        ),
        emergency: emergency,
        smartAlerts: smartAlertsPool.isEmpty
            ? 'All clear in your area'
            : smartAlertsPool.trim(),
      );

      _lastFetchTime = DateTime.now();

      // RuFlo: Store a snapshot for historical trend memory (e.g. "is AQI worse than yesterday?")
      try {
        ruflo.memoryStore(
            namespace: 'god_mode_history',
            key: 'god_mode_snapshot_${DateTime.now().millisecondsSinceEpoch}',
            value: data.value!.toJson(),
            metadata: {
              'city': city,
              'state': state,
              'type': 'environmental_snapshot'
            });
      } catch (e) {
        debugPrint('RuFlo Memory Store Error: $e');
      }
    } catch (e) {
      errorMsg.value = 'Failed to fetch God Mode data: $e';
      debugPrint('God Mode Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      int h = dateTime.hour;
      int m = dateTime.minute;
      String ampm = h >= 12 ? 'PM' : 'AM';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      String minStr = m.toString().padLeft(2, '0');
      return '$h:$minStr $ampm';
    } catch (_) {
      return isoString;
    }
  }

  String _calculateDaylightRemaining(String sunsetAmPm) {
    // simplified for now: just return a stub or calculate real duration
    return 'Approx 4h remaining';
  }

  Map<String, dynamic> _calculateSimpleMoonPhase() {
    // Very simple approximation.
    // Replace with a rigorous formula or API later if needed.
    return {
      'phase': 'Waxing Crescent',
      'illumination': 34,
      'recommendation': 'Good time for reflection.'
    };
  }

  String _getLanguagesForState(String state) {
    final lowerState = state.toLowerCase();
    if (lowerState.contains('punjab')) return 'Punjabi, Hindi, English';
    if (lowerState.contains('maharashtra')) return 'Marathi, Hindi, English';
    if (lowerState.contains('tami')) return 'Tamil, English';
    if (lowerState.contains('bengal')) return 'Bengali, Hindi, English';
    if (lowerState.contains('karnataka')) return 'Kannada, English';
    if (lowerState.contains('gujarat')) return 'Gujarati, Hindi, English';
    return 'Hindi, English';
  }
}

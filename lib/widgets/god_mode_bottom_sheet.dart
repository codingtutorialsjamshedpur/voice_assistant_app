import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/god_mode_intelligence_service.dart';
import '../shared/controllers/top_panel_controller.dart';
import '../shared/theme/responsive.dart';
import '../shared/widgets/staggered_fade_in.dart';

class GodModeBottomSheet extends StatelessWidget {
  const GodModeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Obx(() {
          Color accent = Colors.purple;
          try {
            accent = Get.find<TopPanelController>().currentColor;
          } catch (_) {}

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withAlpha(51),
                  Colors.white.withAlpha(26),
                  accent.withAlpha(38),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: accent.withAlpha(128), width: 2),
              boxShadow: [
                BoxShadow(
                    color: accent.withAlpha(77),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, -10)),
                BoxShadow(
                    color: Colors.black.withAlpha(128),
                    blurRadius: 40,
                    spreadRadius: 10),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: context.r.scale(40),
                          height: context.r.scale(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: _buildHeader(context, accent),
                      ),
                      const SizedBox(height: 12),
                      // Grid
                      Expanded(
                        child: _buildGrid(context, scrollController, accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildHeader(BuildContext context, Color accent) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(context.r.scale(9)),
          decoration: BoxDecoration(
            color: accent.withAlpha(50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withAlpha(100)),
          ),
          child: Icon(Icons.public,
              color: Colors.amberAccent, size: context.r.scale(20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'God Mode Intelligence',
                style: TextStyle(
                  fontSize: context.r.sp(17),
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                ),
              ),
              Text(
                'Live contextual data based on your location',
                style: TextStyle(
                  fontSize: context.r.sp(11),
                  color: Colors.white.withAlpha(160),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.close,
                color: Colors.white70, size: context.r.scale(18)),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(
      BuildContext context, ScrollController scrollController, Color accent) {
    final godModeService = Get.find<GodModeIntelligenceService>();

    return Obx(() {
      final godData = godModeService.data.value;
      if (godModeService.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent));
      }

      if (godData == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_rounded,
                  size: context.r.scale(48), color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                'Intelligence Offline',
                style: TextStyle(
                  fontSize: context.r.sp(16),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'God Mode requires GPS coordinate access to generate environmental arrays. Please enable location services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.r.sp(12),
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Get.find<TopPanelController>().checkServicesAndFetch();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.withAlpha(50),
                  foregroundColor: Colors.amberAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        );
      }

      return GridView.count(
        controller: scrollController,
        crossAxisCount: context.r.isTablet ? 3 : 2,
        childAspectRatio: 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          StaggeredFadeIn(
            index: 0,
            child: _buildCard(context, accent, '🌍 Environment', [
              'AQI: ${godData.environment.aqi}',
              'PM2.5: ${godData.environment.pm25}',
              'PM10: ${godData.environment.pm10}',
              'Humidity: ${godData.environment.humidity}%',
            ]),
          ),
          StaggeredFadeIn(
            index: 1,
            child: _buildCard(context, accent, '☀️ Weather', [
              'Temp: ${godData.weather.temperature}°C',
              'Feels Like: ${godData.weather.feelsLike}°C',
              'Rain Chance: ${godData.weather.rainChance}%',
              'Wind: ${godData.weather.windSpeed} km/h',
            ]),
          ),
          StaggeredFadeIn(
            index: 2,
            child: _buildCard(context, accent, '🌅 Sun', [
              'Sunrise: ${godData.sun.sunrise}',
              'Sunset: ${godData.sun.sunset}',
              'Remain: ${godData.sun.daylightRemaining}',
            ]),
          ),
          StaggeredFadeIn(
            index: 3,
            child: _buildCard(context, accent, '🌙 Moon', [
              'Phase: ${godData.moon.phase}',
              'Light: ${godData.moon.illumination}%',
              'Tip: ${godData.moon.recommendations}',
            ]),
          ),
          StaggeredFadeIn(
            index: 4,
            child: _buildCard(context, accent, '🌿 Health', [
              'UV Index: ${godData.health.uvIndex}',
              'Pollen: ${godData.health.pollenInfo}',
              'Safety: ${godData.health.outdoorSafety}',
            ]),
          ),
          StaggeredFadeIn(
            index: 5,
            child: _buildCard(context, accent, '🛕 Local', [
              'State: ${godData.local.state}',
              'Fest: ${godData.local.festival}',
              'Langs: ${godData.local.languageSuggestions}',
            ]),
          ),
          StaggeredFadeIn(
            index: 6,
            child: _buildCard(context, accent, '🚨 Emergency', [
              'Police: ${godData.emergency.police}',
              'Ambulance: ${godData.emergency.ambulance}',
              'Fire: ${godData.emergency.fire}',
              'General: ${godData.emergency.standardGeneral}',
            ]),
          ),
        ],
      );
    });
  }

  Widget _buildCard(
      BuildContext context, Color accent, String title, List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(35),
            Colors.white.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amberAccent.withAlpha(80), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amberAccent.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: context.r.sp(14),
                    color: Colors.amberAccent,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.amberAccent.withAlpha(40), height: 1),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4, right: 6),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(180),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          lines[index],
                          style: TextStyle(
                            fontSize: context.r.sp(12),
                            color: Colors.white.withAlpha(240),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

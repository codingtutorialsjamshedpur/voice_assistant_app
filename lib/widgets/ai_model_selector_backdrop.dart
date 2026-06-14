import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../shared/theme/responsive.dart';
import '../services/ai_model_manager.dart';
import '../shared/controllers/top_panel_controller.dart';

/// ═══════════════════════════════════════════════════════════════
/// AI Model Selector Backdrop — Matches Language Picker Design
/// ═══════════════════════════════════════════════════════════════
///
/// Mirrors the transparent language selection backdrop from
/// LanguagePickerBottomSheet:
/// - DraggableScrollableSheet with gradient transparent glass bg
/// - Color-accent gradient border + box shadow
/// - Handle bar at top
/// - Live health-status rings: 🟢 Green (fast) / 🟡 Yellow (slow) / 🔴 Red (failed)
/// - Real-time "Testing..." progress label while checks run
/// - Sorted by health: Green → Yellow → Untested → Red
///
class AIModelSelectorBackdrop extends StatefulWidget {
  final AIModelManager aiManager;

  const AIModelSelectorBackdrop({
    super.key,
    required this.aiManager,
  });

  @override
  State<AIModelSelectorBackdrop> createState() =>
      _AIModelSelectorBackdropState();
}

class _AIModelSelectorBackdropState extends State<AIModelSelectorBackdrop> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Obx(() {
          // Mirror the exact language picker gradient + border style
          final Color accent = _accentColor;
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
              border: Border.all(
                color: accent.withAlpha(128),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha(77),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, -10),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(128),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
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
                      // ── Handle bar ──────────────────────────────────────
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

                      // ── Header ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: _buildHeader(accent),
                      ),

                      // ── Status Bar ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildStatusBar(accent),
                      ),

                      const SizedBox(height: 10),

                      // ── Auto Option ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAutoCard(accent),
                      ),

                      const SizedBox(height: 8),

                      // ── Divider ─────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                                child:
                                    Divider(color: Colors.white.withAlpha(40))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'AI MODELS',
                                style: TextStyle(
                                  fontSize: context.r.sp(10),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withAlpha(120),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(
                                child:
                                    Divider(color: Colors.white.withAlpha(40))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ── Model List ──────────────────────────────────────
                      Expanded(
                        child: _buildModelList(scrollController, accent),
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

  /// Pull current accent from TopPanelController if available
  Color get _accentColor {
    try {
      return Get.find<TopPanelController>().currentColor;
    } catch (_) {
      return Colors.purple;
    }
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(Color accent) {
    return Row(
      children: [
        // Icon badge
        Container(
            padding: EdgeInsets.all(context.r.scale(9)),
            decoration: BoxDecoration(
              color: accent.withAlpha(50),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withAlpha(100)),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.white, size: context.r.scale(20)),
        ),
        const SizedBox(width: 12),
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose AI Model',
                style: TextStyle(
                  fontSize: context.r.sp(17),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Obx(() {
                final total = AIProvider
                    .values.length; // Dynamic — auto-counts all models
                final tested = widget.aiManager.providerHealth.values
                    .where((h) => h != ProviderHealth.untested)
                    .length;
                final isTesting = tested < total;
                return Text(
                  isTesting
                      ? 'Testing $tested/$total models...'
                      : 'All $total models tested — tap to lock preferred',
                  style: TextStyle(
                    fontSize: context.r.sp(11),
                    color: Colors.white.withAlpha(160),
                  ),
                );
              }),
            ],
          ),
        ),
        // Close button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.close, color: Colors.white70, size: context.r.scale(18)),
          ),
        ),
      ],
    );
  }

  // ── Status Bar ────────────────────────────────────────────────
  Widget _buildStatusBar(Color accent) {
    return Obx(() {
      final health = widget.aiManager.providerHealth;
      final green =
          health.values.where((h) => h == ProviderHealth.healthy).length;
      final yellow =
          health.values.where((h) => h == ProviderHealth.degraded).length;
      final red =
          health.values.where((h) => h == ProviderHealth.failing).length;
      final untested =
          health.values.where((h) => h == ProviderHealth.untested).length;
      final isRunning = untested > 0;

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statusChip('🟢', green, 'Fast', Colors.green),
            _statusDivider(),
            _statusChip('🟡', yellow, 'Slow', Colors.amber),
            _statusDivider(),
            _statusChip('🔴', red, 'Failed', Colors.red),
            if (isRunning) ...[
              _statusDivider(),
              _testingIndicator(untested),
            ],
          ],
        ),
      );
    });
  }

  Widget _statusChip(String emoji, int count, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.r.scale(6),
          height: context.r.scale(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(140), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: context.r.sp(11),
            color: Colors.white.withAlpha(200),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statusDivider() {
    return Container(
      height: context.r.scale(14),
      width: 1,
      color: Colors.white.withAlpha(40),
    );
  }

  Widget _testingIndicator(int remaining) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: context.r.scale(10),
          height: context.r.scale(10),
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(180)),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$remaining left',
          style: TextStyle(fontSize: context.r.sp(10), color: Colors.white.withAlpha(160)),
        ),
      ],
    );
  }

  // ── Auto Card (always on top) ─────────────────────────────────
  Widget _buildAutoCard(Color accent) {
    return Obx(() {
      final isSelected = widget.aiManager.preferredProvider.value == null;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.aiManager.setPreferredProvider(null);
          Navigator.pop(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [accent.withAlpha(80), accent.withAlpha(40)],
                  )
                : null,
            color: isSelected ? null : Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? accent.withAlpha(200)
                  : Colors.white.withAlpha(40),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Pulsing green dot for "auto"
              Container(
                width: context.r.scale(10),
                height: context.r.scale(10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.greenAccent.withAlpha(160),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Text('🎯', style: TextStyle(fontSize: context.r.sp(20))),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto (Best Match)',
                      style: TextStyle(
                        fontSize: context.r.sp(14),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'AI routes to the best model per query',
                      style: TextStyle(
                        fontSize: context.r.sp(10),
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                  ],
                ),
              ),
                if (isSelected)
                Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: context.r.scale(20))
              else
                Icon(Icons.radio_button_unchecked,
                    color: Colors.white.withAlpha(80), size: context.r.scale(18)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildModelList(ScrollController scrollController, Color accent) {
    return Obx(() {
      final healthMap = widget.aiManager.providerHealth;

      // Group models by their 'group' field
      final catalog = _sortedCatalog(healthMap);
      final groups = <String, List<Map<String, String>>>{};
      for (final model in catalog) {
        final group = model['group'] ?? 'Others';
        if (!groups.containsKey(group)) groups[group] = [];
        groups[group]!.add(model);
      }

      final groupOrder = [
        'OpenCode Zen',
        'Google',
        'NVIDIA',
        'Mistral',
        'OpenRouter',
        'AI'
      ];
      final sortedGroups = groups.keys.toList()
        ..sort((a, b) {
          final idxA = groupOrder.indexOf(a);
          final idxB = groupOrder.indexOf(b);
          if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
          if (idxA != -1) return -1;
          if (idxB != -1) return 1;
          return a.compareTo(b);
        });

      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: sortedGroups.expand((groupName) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
              child: Text(
                groupName.toUpperCase(),
                style: TextStyle(
                  fontSize: context.r.sp(11),
                  fontWeight: FontWeight.bold,
                  color: accent.withAlpha(200),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...groups[groupName]!
                .map((model) => _buildModelCard(model, healthMap, accent)),
          ];
        }).toList(),
      );
    });
  }

  /// Sort: Green → Yellow → Untested (with spinner) → Red
  List<Map<String, String>> _sortedCatalog(
      Map<AIProvider, ProviderHealth> healthMap) {
    // Exclude auto (shown separately) and github (routes to groq)
    final catalog = AIModelManager.allModelCatalog
        .where((m) =>
            m['provider'] != 'openRouterAuto' && m['provider'] != 'github')
        .toList();

    catalog.sort((a, b) {
      final pA = _providerFromName(a['provider']!);
      final pB = _providerFromName(b['provider']!);
      return _sortScore(healthMap[pB]).compareTo(_sortScore(healthMap[pA]));
    });
    return catalog;
  }

  int _sortScore(ProviderHealth? h) {
    switch (h) {
      case ProviderHealth.healthy:
        return 4;
      case ProviderHealth.degraded:
        return 3;
      case ProviderHealth.untested:
        return 2;
      default:
        return 1; // failing
    }
  }

  Widget _buildModelCard(
    Map<String, String> model,
    Map<AIProvider, ProviderHealth> healthMap,
    Color accent,
  ) {
    final providerName = model['provider']!;
    final displayName = model['displayName']!;
    final category = model['category']!;
    final icon = model['icon']!;

    final provider = _providerFromName(providerName);
    final health = provider != null
        ? healthMap[provider] ?? ProviderHealth.untested
        : ProviderHealth.untested;
    final isBlacklisted =
        provider != null && widget.aiManager.isBlacklisted(provider);
    final isFailing = health == ProviderHealth.failing || isBlacklisted;
    final isSelected = widget.aiManager.preferredProvider.value == provider;
    final isTesting = health == ProviderHealth.untested;

    final (healthColor, healthText, healthIcon) =
        _healthVisuals(health, isFailing, isTesting);

    return GestureDetector(
      onTap: isFailing
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.aiManager
                  .setPreferredProvider(isSelected ? null : provider);
              Navigator.pop(context);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [accent.withAlpha(80), accent.withAlpha(30)],
                )
              : null,
          color: isSelected ? null : Colors.white.withAlpha(isFailing ? 8 : 18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accent.withAlpha(200)
                : isFailing
                    ? Colors.red.withAlpha(60)
                    : Colors.white.withAlpha(35),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Health status dot
            _buildHealthDot(healthColor, isTesting),
            const SizedBox(width: 10),
            // Emoji icon
                    Text(icon,
                style: TextStyle(fontSize: context.r.sp(20), color: isFailing ? null : null)),
            const SizedBox(width: 12),
            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: context.r.sp(13),
                      fontWeight: FontWeight.w600,
                      color: isFailing
                          ? Colors.white.withAlpha(100)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: context.r.sp(9),
                            color: Colors.white.withAlpha(140),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Health text
                      Text(
                        healthText,
                        style: TextStyle(
                          fontSize: context.r.sp(10),
                          color: healthColor.withAlpha(220),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right indicator
            _buildRightIndicator(isFailing, isSelected, isTesting, healthColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDot(Color color, bool isTesting) {
    if (isTesting) {
      return SizedBox(
        width: context.r.scale(10),
        height: context.r.scale(10),
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor:
              AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(180)),
        ),
      );
    }
    return Container(
      width: context.r.scale(10),
      height: context.r.scale(10),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withAlpha(160), blurRadius: 5, spreadRadius: 1),
        ],
      ),
    );
  }

  Widget _buildRightIndicator(
      bool isFailing, bool isSelected, bool isTesting, Color healthColor) {
    if (isTesting) {
      return Text(
        'Testing...',
        style: TextStyle(fontSize: context.r.sp(10), color: Colors.white.withAlpha(120)),
      );
    }
    if (isFailing) {
      return Icon(Icons.block_rounded,
          color: Colors.red.withAlpha(180), size: context.r.scale(16));
    }
    if (isSelected) {
      return Icon(Icons.check_circle_rounded,
          color: Colors.greenAccent, size: context.r.scale(20));
    }
      return Icon(Icons.radio_button_unchecked,
        color: Colors.white.withAlpha(80), size: context.r.scale(16));
  }

  // ── Health visuals ────────────────────────────────────────────
  (Color, String, String) _healthVisuals(
      ProviderHealth health, bool isFailing, bool isTesting) {
    if (isFailing) return (Colors.red, '● Not Available', '🔴');
    switch (health) {
      case ProviderHealth.healthy:
        return (Colors.green, '● Fast & Reliable (~5s)', '🟢');
      case ProviderHealth.degraded:
        return (Colors.amber, '● Moderate (~10s)', '🟡');
      case ProviderHealth.failing:
        return (Colors.red, '● Not Available', '🔴');
      case ProviderHealth.untested:
        return (Colors.grey, 'Testing...', '⬜');
    }
  }

  /// Convert provider name string to AIProvider enum
  AIProvider? _providerFromName(String name) {
    try {
      return AIProvider.values.firstWhere(
        (p) => p.name == name,
        orElse: () => throw Exception(),
      );
    } catch (_) {
      return null;
    }
  }
}

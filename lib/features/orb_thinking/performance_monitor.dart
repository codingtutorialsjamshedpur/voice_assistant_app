import 'package:flutter/scheduler.dart';

/// Performance Monitor for Orb Thinking System
/// Tracks frame rate and performance metrics during animations
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  bool _isMonitoring = false;
  int _frameCount = 0;
  DateTime? _startTime;
  DateTime? _lastFrameTime;
  final List<int> _frameDurations = [];

  // Performance thresholds
  static const int targetFrameTime = 16; // 60fps = 16.67ms per frame
  static const int maxFrameTime = 33; // 30fps = 33.33ms per frame

  /// Start monitoring frame performance
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _frameCount = 0;
    _startTime = DateTime.now();
    _lastFrameTime = null;
    _frameDurations.clear();

    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    print('🎯 Performance monitoring started');
  }

  /// Stop monitoring and return performance report
  PerformanceReport stopMonitoring() {
    if (!_isMonitoring) {
      return PerformanceReport.empty();
    }

    _isMonitoring = false;
    final endTime = DateTime.now();
    final totalDuration =
        _startTime != null ? endTime.difference(_startTime!) : Duration.zero;

    final report = PerformanceReport(
      frameCount: _frameCount,
      totalDuration: totalDuration,
      frameDurations: List.from(_frameDurations),
    );

    print('📊 Performance monitoring stopped: ${report.summary}');
    return report;
  }

  void _onFrame(Duration timestamp) {
    if (!_isMonitoring) return;

    _frameCount++;
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!).inMilliseconds;
      _frameDurations.add(frameDuration);

      // Log frame drops
      if (frameDuration > maxFrameTime) {
        print('⚠️ Frame drop: ${frameDuration}ms (frame $_frameCount)');
      }
    }

    _lastFrameTime = now;

    // Continue monitoring
    if (_isMonitoring) {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    }
  }
}

/// Performance report containing frame rate statistics
class PerformanceReport {
  final int frameCount;
  final Duration totalDuration;
  final List<int> frameDurations;

  const PerformanceReport({
    required this.frameCount,
    required this.totalDuration,
    required this.frameDurations,
  });

  factory PerformanceReport.empty() {
    return const PerformanceReport(
      frameCount: 0,
      totalDuration: Duration.zero,
      frameDurations: [],
    );
  }

  /// Average FPS during monitoring period
  double get averageFps {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return frameCount / (totalDuration.inMilliseconds / 1000.0);
  }

  /// Average frame duration in milliseconds
  double get averageFrameTime {
    if (frameDurations.isEmpty) return 0.0;
    return frameDurations.reduce((a, b) => a + b) / frameDurations.length;
  }

  /// Percentage of frames that met 60fps target
  double get smoothnessPercentage {
    if (frameDurations.isEmpty) return 0.0;
    final smoothFrames = frameDurations
        .where((duration) => duration <= PerformanceMonitor.targetFrameTime)
        .length;
    return (smoothFrames / frameDurations.length) * 100;
  }

  /// Number of frame drops (>33ms)
  int get frameDrops {
    return frameDurations
        .where((duration) => duration > PerformanceMonitor.maxFrameTime)
        .length;
  }

  /// Performance grade based on smoothness
  String get grade {
    final smoothness = smoothnessPercentage;
    if (smoothness >= 95) return 'A+';
    if (smoothness >= 90) return 'A';
    if (smoothness >= 80) return 'B';
    if (smoothness >= 70) return 'C';
    if (smoothness >= 60) return 'D';
    return 'F';
  }

  /// Summary string for logging
  String get summary {
    return 'FPS: ${averageFps.toStringAsFixed(1)}, '
        'Smoothness: ${smoothnessPercentage.toStringAsFixed(1)}%, '
        'Grade: $grade, '
        'Frame drops: $frameDrops';
  }

  /// Detailed performance breakdown
  Map<String, dynamic> toMap() {
    return {
      'frameCount': frameCount,
      'totalDurationMs': totalDuration.inMilliseconds,
      'averageFps': double.parse(averageFps.toStringAsFixed(2)),
      'averageFrameTimeMs': double.parse(averageFrameTime.toStringAsFixed(2)),
      'smoothnessPercentage':
          double.parse(smoothnessPercentage.toStringAsFixed(2)),
      'frameDrops': frameDrops,
      'grade': grade,
    };
  }
}

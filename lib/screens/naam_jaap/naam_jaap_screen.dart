import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../services/naam_jaap_service.dart';
import '../../services/audio_recording_service.dart';
import '../../services/tts_service.dart';
import '../../services/history_logger_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/dark_mode_scrim.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';

enum InputMode { text, voice }

class Milestone {
  final int value;
  bool hasTriggered = false;
  Milestone(this.value);
}

class JaapMilestones {
  static final List<Milestone> list = [
    Milestone(1),
    Milestone(11),
    Milestone(21),
    Milestone(108),
    Milestone(1008),
    Milestone(1080),
    Milestone(1188),
    Milestone(5508),
    Milestone(10008),
    Milestone(10800),
    Milestone(11000),
    Milestone(21000),
    Milestone(31000),
    Milestone(51000),
    Milestone(100000),
    Milestone(125000),
  ];

  static List<int> get values => list.map((m) => m.value).toList();

  static String getDisplayLabel(int value) {
    switch (value) {
      case 1:
        return '1 (Beej)';
      case 11:
        return '11 (Short)';
      case 21:
        return '21 (Daily)';
      case 108:
        return '108 (1 Mala)';
      case 1008:
        return '1,008 (9 Malas)';
      case 1080:
        return '1,080 (10 Malas)';
      case 1188:
        return '1,188 (11 Malas)';
      case 5508:
        return '5,508 (51 Malas)';
      case 10008:
        return '10,008 (92 Malas)';
      case 10800:
        return '10,800 (100 Malas)';
      case 11000:
        return '11,000 (Sankalp)';
      case 21000:
        return '21,000 (Saptah)';
      case 31000:
        return '31,000';
      case 51000:
        return '51,000';
      case 100000:
        return '1,00,000 (1 Lakh)';
      case 125000:
        return '1,25,000 (Sava-Lakh)';
      default:
        return value.toString();
    }
  }

  static int findNearestMilestone(int value) {
    int nearest = values[0];
    int minDiff = (value - nearest).abs();
    for (int milestone in values) {
      final int diff = (value - milestone).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = milestone;
      }
    }
    return nearest;
  }
}

class NaamJaapScreen extends StatefulWidget {
  const NaamJaapScreen({super.key});

  @override
  State<NaamJaapScreen> createState() => _NaamJaapScreenState();
}

class _NaamJaapScreenState extends State<NaamJaapScreen> {
  final NaamJaapService _jaapService = Get.find<NaamJaapService>();
  final AudioRecordingService _audioService = Get.find<AudioRecordingService>();
  final TTSService _ttsService = Get.find<TTSService>();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _mantraController = TextEditingController();

  int _count = 0;
  int _target = 108;
  bool _isPlaying = false;
  bool _isPaused = false;
  Timer? _loopTimer;
  int _seconds = 0;
  Timer? _sessionTimer;
  String _currentMantraText = '';
  String? _recordedAudioPath;
  bool _hasStarted = false;
  List<Map<String, dynamic>> _recentSessions = [];
  InputMode _inputMode = InputMode.text;
  bool _isRecording = false;
  bool _isAudioPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  double _sliderValue = 6; // Index for 108
  bool _isLoopRunning = false; // Single flag: is the loop actively running
  StreamSubscription? _audioSubscription;
  bool _sessionCompleteCalled =
      false; // Prevent multiple completion notifications

  // Track if session has been saved to prevent duplicates
  bool _sessionSaved = false;

  bool _showCelebration = false;
  String _celebrationMessage = '';
  Timer? _celebrationTimer;
  final Set<int> _triggeredMilestones = {};

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
    _target = JaapMilestones.values[_sliderValue.toInt()];

    _setupAudioPlayerListener();
  }

  void _setupAudioPlayerListener() {
    _audioSubscription?.cancel();
    _audioSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _onAudioComplete();
    });
  }

  void _loadRecentSessions() {
    setState(() {
      _recentSessions = _jaapService.sessionHistory.take(10).toList();
    });
  }

  bool get _hasMantra => _inputMode == InputMode.text
      ? _currentMantraText.isNotEmpty
      : _recordedAudioPath != null;

  String get _mantraDisplay => _inputMode == InputMode.text
      ? _currentMantraText
      : 'Voice Recorded Mantra';

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
      _target = JaapMilestones.values[value.toInt()];
    });
  }

  Future<void> _startJaapLoop() async {
    if (!_hasMantra) {
      _showMantraRequiredDialog();
      return;
    }

    if (_count >= _target) {
      _showCompletionDialog();
      return;
    }

    // Prevent multiple starts
    if (_isPlaying) return;

    // Reset session saved flag when starting fresh
    if (_count == 0) {
      _sessionSaved = false;
      _sessionCompleteCalled = false;
    }

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      if (!_hasStarted) {
        _hasStarted = true;
        _startSessionTimer();
      }
    });

    SoundService.to.playEffect('sounds/game_sounds/Go.mp3');
    await Future.delayed(const Duration(milliseconds: 500));

    // Start the loop
    _runJaapLoop();
  }

  /// Runs the jaap loop sequentially using a simple async loop.
  /// Each iteration waits for TTS/audio to finish before starting the next.
  Future<void> _runJaapLoop() async {
    if (_isLoopRunning) return;
    _isLoopRunning = true;

    try {
      while (_isPlaying && !_sessionCompleteCalled && mounted) {
        if (_count >= _target) {
          _onSessionComplete();
          return;
        }

        setState(() {
          _count++;
        });

        for (final milestone in JaapMilestones.list) {
          if (_count == milestone.value && !milestone.hasTriggered) {
            milestone.hasTriggered = true;
            _triggeredMilestones.add(milestone.value);
            _triggerCelebration(milestone.value);
            break;
          }
        }

        HapticFeedback.lightImpact();
        debugPrint('Playing iteration $_count of $_target');

        // Add a small gap between iterations for pacing
        if (_count > 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }

        // Check again after delay (user may have paused/stopped)
        if (!_isPlaying || _sessionCompleteCalled || !mounted) break;

        try {
          if (_inputMode == InputMode.text) {
            await _speakAndWait(_currentMantraText);
          } else {
            if (_recordedAudioPath != null) {
              await _playAudioAndWait(_recordedAudioPath!);
            }
          }
        } catch (e) {
          debugPrint('Error in jaap iteration: $e');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Check if we finished naturally (count reached target)
      if (_count >= _target && !_sessionCompleteCalled && mounted) {
        _onSessionComplete();
      }
    } finally {
      _isLoopRunning = false;
    }
  }

  /// Splits long text into speakable chunks by line breaks and verse markers.
  /// Each chunk is small enough for the TTS engine to handle reliably.
  List<String> _splitTextIntoChunks(String text) {
    final List<String> chunks = [];

    // Split by double newlines (verse/paragraph boundaries) first
    final paragraphs = text.split(RegExp(r'\n\s*\n'));

    for (final paragraph in paragraphs) {
      // Within each paragraph, split by single newlines
      final lines = paragraph.split(RegExp(r'\n'));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // If a line is still very long (>200 chars), split by verse markers ॥ or ।
        if (trimmed.length > 200) {
          final verseParts = trimmed.split(RegExp(r'[॥।]'));
          for (final part in verseParts) {
            final p = part.trim();
            if (p.isNotEmpty) chunks.add(p);
          }
        } else {
          chunks.add(trimmed);
        }
      }
    }

    return chunks;
  }

  /// Speaks a single chunk of text and waits for TTS to complete.
  Future<void> _speakSingleChunk(String text) async {
    final completer = Completer<void>();
    StreamSubscription? sub;
    bool ttsStarted = false;

    // Start speaking first, then listen for completion
    await _ttsService.speak(text);

    // Listen for TTS completion - only complete after TTS has started
    sub = _ttsService.isSpeaking.listen((speaking) {
      if (speaking) {
        ttsStarted = true;
      } else if (ttsStarted && !completer.isCompleted) {
        // TTS finished after having started
        sub?.cancel();
        completer.complete();
      }
    });

    // Wait a short moment to see if TTS starts
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_ttsService.isSpeaking.value &&
        !ttsStarted &&
        !completer.isCompleted) {
      // TTS never started (e.g., error or empty text)
      sub.cancel();
      completer.complete();
    }

    // Dynamic timeout based on chunk length (generous for Hindi/Sanskrit)
    final textLength = text.length;
    final timeoutSeconds = (8 + (textLength * 0.5)).clamp(8.0, 120.0).toInt();
    await completer.future.timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () {
        sub?.cancel();
        debugPrint(
            'TTS chunk timeout after $timeoutSeconds seconds - continuing');
      },
    );
  }

  /// Speaks text and waits for TTS to complete.
  /// For long texts, splits into chunks and speaks each sequentially.
  Future<void> _speakAndWait(String text) async {
    final chunks = _splitTextIntoChunks(text);

    // If text is short enough (single chunk), speak directly
    if (chunks.length <= 1) {
      await _speakSingleChunk(text.trim());
      return;
    }

    debugPrint('Speaking ${chunks.length} chunks for long mantra text');

    for (int i = 0; i < chunks.length; i++) {
      // Check if user paused or stopped between chunks
      if (!_isPlaying || _sessionCompleteCalled || !mounted) {
        debugPrint(
            'Chunked TTS interrupted at chunk ${i + 1}/${chunks.length}');
        return;
      }

      debugPrint(
          'Speaking chunk ${i + 1}/${chunks.length}: "${chunks[i].substring(0, chunks[i].length.clamp(0, 40))}..."');
      await _speakSingleChunk(chunks[i]);

      // Small pause between chunks for natural pacing
      if (i < chunks.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// Plays audio file and waits for it to complete.
  Future<void> _playAudioAndWait(String audioPath) async {
    final completer = Completer<void>();
    StreamSubscription? sub;

    sub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) {
        sub?.cancel();
        completer.complete();
      }
    });

    await _audioPlayer.play(DeviceFileSource(audioPath));

    await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        sub?.cancel();
        debugPrint('Audio timeout - continuing');
      },
    );
  }

  void _onAudioComplete() {
    // No longer needed - handled by _playAudioAndWait
  }

  void _triggerCelebration(int milestoneValue) {
    _celebrationTimer?.cancel();
    setState(() {
      _showCelebration = true;
      _celebrationMessage = _getCelebrationMessage(milestoneValue);
    });
    _celebrationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showCelebration = false;
        });
      }
    });
  }

  String _getCelebrationMessage(int value) {
    switch (value) {
      case 1: return '1 - Sacred Beej!';
      case 11: return '11 - Sacred count!';
      case 21: return '21 - Daily milestone!';
      case 108: return '108 - Sacred number!';
      case 1008: return '1,008 - 9 Malas complete!';
      case 1080: return '1,080 - 10 Malas!';
      case 1188: return '1,188 - Anushthan milestone!';
      case 5508: return '5,508 - Halfway to 51 Malas!';
      case 10008: return '10,008 - 92 Malas!';
      case 10800: return '10,800 - 100 Malas!';
      case 11000: return '11,000 - Sankalp complete!';
      case 21000: return '21,000 - Saptah complete!';
      case 31000: return '31,000 - Mid-point!';
      case 51000: return '51,000 - Major milestone!';
      case 100000: return '1,00,000 - 1 Lakh! Mantra Siddhi!';
      case 125000: return '1,25,000 - Sava-Lakh! Purashcharana!';
      default: return '$value - Milestone!';
    }
  }

  void _pauseJaap() {
    setState(() {
      _isPlaying = false;
      _isPaused = true;
      _isLoopRunning = false;
    });

    _ttsService.stop();
    _audioPlayer.stop();
  }

  void _resumeJaap() {
    if (_isPlaying) return; // Already playing

    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });

    // Continue from where we left off
    _runJaapLoop();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _stopJaap() {
    // Mark session as complete to prevent any further callbacks
    _sessionCompleteCalled = true;

    // Cancel all timers and subscriptions
    _sessionTimer?.cancel();
    _loopTimer?.cancel();
    _ttsService.stop();
    _audioPlayer.stop();

    _audioSubscription?.cancel();
    _celebrationTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _isLoopRunning = false;
      _showCelebration = false;
    });

    // Save session if there's progress
    if (_count > 0 && _hasMantra) {
      _saveCurrentSession();
    }
  }

  void _reset() {
    _stopJaap();

    setState(() {
      _count = 0;
      _seconds = 0;
      _hasStarted = false;
      _currentMantraText = '';
      _recordedAudioPath = null;
      _inputMode = InputMode.text;
      _isRecording = false;
      _isAudioPlaying = false;
      _recordingDuration = Duration.zero;
      _sliderValue = 6;
      _target = JaapMilestones.values[6];
      _sessionCompleteCalled = false;
      _sessionSaved = false;
      _isLoopRunning = false;
      _celebrationTimer?.cancel();
      _showCelebration = false;
      _celebrationMessage = '';
      _triggeredMilestones.clear();
    });

    for (final m in JaapMilestones.list) {
      m.hasTriggered = false;
    }

    _mantraController.clear();
    SoundService.to.playClick();
    _loadRecentSessions();
  }

  void _onSessionComplete() {
    // Prevent multiple completion calls
    if (_sessionCompleteCalled) return;
    _sessionCompleteCalled = true;

    // Cancel all timers and stop audio first
    _sessionTimer?.cancel();
    _ttsService.stop();
    _audioPlayer.stop();

    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _isLoopRunning = false;
    });

    HistoryLoggerService().logNaamJaapActivity(
      chantCount: _count,
      durationSeconds: _seconds > 0 ? _seconds : null,
    );

    _saveCurrentSession();
    _showCompletionDialog();
    _loadRecentSessions();
  }

  Future<void> _saveCurrentSession() async {
    // Prevent duplicate saves
    if (_sessionSaved) return;
    if (!_hasMantra || _count == 0) return;

    _sessionSaved = true;

    final session = {
      'mantraText': _mantraDisplay,
      'count': _count,
      'target': _target,
      'duration': _seconds,
      'timestamp': DateTime.now().toIso8601String(),
      'percentage': ((_count / _target) * 100).round(),
      'inputMode': _inputMode.index,
      'audioPath': _recordedAudioPath,
      'isVoice': _inputMode == InputMode.voice,
    };

    _jaapService.sessionHistory.insert(0, session);

    if (_jaapService.sessionHistory.length > 100) {
      _jaapService.sessionHistory
          .removeRange(100, _jaapService.sessionHistory.length);
    }

    await _jaapService.saveData();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final recording = await _audioService.stopRecording();
      _recordingTimer?.cancel();

      if (recording != null) {
        setState(() {
          _isRecording = false;
          _recordedAudioPath = recording.filePath;
          _recordingDuration = recording.duration;
        });

        Get.snackbar(
          'Recording Saved',
          'Voice mantra recorded successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } else {
      final started = await _audioService.startRecording();
      if (started) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      }
    }
  }

  Future<void> _playRecordedMantra() async {
    if (_recordedAudioPath == null) return;

    if (_isAudioPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isAudioPlaying = false;
      });
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
      setState(() {
        _isAudioPlaying = true;
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _isAudioPlaying = false;
        });
      });
    }
  }

  Future<void> _playSessionAudio(String? audioPath) async {
    if (audioPath == null) return;

    if (_isAudioPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isAudioPlaying = false;
      });
    } else {
      await _audioPlayer.play(DeviceFileSource(audioPath));
      setState(() {
        _isAudioPlaying = true;
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _isAudioPlaying = false;
        });
      });
    }
  }

  void _showMantraRequiredDialog() {
    GlassmorphicDialogHelper.showWarning(
      title: 'Mantra Required',
      message: _inputMode == InputMode.text
          ? 'Please enter a Mantra (Naam Jaap Word) before starting your session.'
          : 'Please record your voice mantra before starting your session.',
      confirmLabel: 'OK',
    );
  }

  void _showCompletionDialog() {
    final milestone = _target >= 125000
        ? 'Sava-Lakh Complete! Mantra Siddhi achieved!'
        : _target >= 100000
            ? 'Lakh-Jaap Complete! Spiritual milestone reached!'
            : null;

    GlassmorphicDialogHelper.showSuccess(
      title: 'Jaap Complete! 🙏',
      message: 'You have completed $_target Naam Jaap!',
      subtitle:
          'Duration: $_formattedTime\nMantra: "$_mantraDisplay"${milestone != null ? '\n\n$milestone' : ''}',
      confirmLabel: 'Start New Session',
      onConfirm: _reset,
    );
  }

  String get _formattedTime {
    final hours = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatDateTime(String isoString) {
    final dateTime = DateTime.parse(isoString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (sessionDate == today) {
      return 'Today ${DateFormat('hh:mm a').format(dateTime)}';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('hh:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    }
  }

  Future<void> _deleteSession(int index) async {
    setState(() {
      _jaapService.sessionHistory.removeAt(index);
    });
    await _jaapService.saveData();
    _loadRecentSessions();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _recordingTimer?.cancel();
    _audioSubscription?.cancel();
    _celebrationTimer?.cancel();
    _mantraController.dispose();
    _audioPlayer.dispose();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.naamJaap,
      content: SingleChildScrollView(
        child: Column(
          children: [
            const RSizedBox(h: 16),

            // Input Mode Toggle
            GlassContainer(
              padding: context.r.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.input,
                        color: const Color(0xFFFF69B4),
                        size: context.r.scale(20),
                      ),
                      const RSizedBox(w: 8),
                      Text(
                        'Mantra Input Mode',
                        style: TextStyle(
                          fontSize: context.r.sp(14),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const RSizedBox(h: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(context.r.scale(12)),
                                ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Text input mode',
                            button: true,
                            child: GestureDetector(
                              onTap: (_hasStarted || _isPlaying)
                                  ? null
                                  : () {
                                      setState(() {
                                        _inputMode = InputMode.text;
                                        _recordedAudioPath = null;
                                      });
                                    },
                              child: Container(
                                padding: context.r.symmetric(v: 12, h: 0),
                                decoration: BoxDecoration(
                                  color: _inputMode == InputMode.text
                                      ? const Color(0xFFFF69B4)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(context.r.scale(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.keyboard,
                                      color: _inputMode == InputMode.text
                                          ? Colors.white
                                          : AppColors.textPrimary(context),
                                      size: context.r.scale(20),
                                    ),
                                    const RSizedBox(w: 8),
                                    Text(
                                      'Text',
                                      style: TextStyle(
                                        fontSize: context.r.sp(14),
                                        fontWeight: FontWeight.w600,
                                        color: _inputMode == InputMode.text
                                            ? Colors.white
                                            : const Color(0xFF230F1F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            label: 'Voice input mode',
                            button: true,
                            child: GestureDetector(
                              onTap: (_hasStarted || _isPlaying)
                                  ? null
                                  : () {
                                      setState(() {
                                        _inputMode = InputMode.voice;
                                        _currentMantraText = '';
                                        _mantraController.clear();
                                      });
                                    },
                              child: Container(
                                padding: context.r.symmetric(v: 12, h: 0),
                                decoration: BoxDecoration(
                                  color: _inputMode == InputMode.voice
                                      ? const Color(0xFFFF69B4)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(context.r.scale(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      color: _inputMode == InputMode.voice
                                          ? Colors.white
                                          : const Color(0xFF230F1F),
                                      size: context.r.scale(20),
                                    ),
                                    const RSizedBox(w: 8),
                                    Text(
                                      'Voice',
                                      style: TextStyle(
                                        fontSize: context.r.sp(14),
                                        fontWeight: FontWeight.w600,
                                        color: _inputMode == InputMode.voice
                                            ? Colors.white
                                            : const Color(0xFF230F1F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const RSizedBox(h: 16),

            // Mantra Input Section (Text or Voice)
            if (_inputMode == InputMode.text)
              GlassContainer(
                padding: context.r.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          color: const Color(0xFFFF69B4),
                          size: context.r.scale(20),
                        ),
                        const RSizedBox(w: 8),
                        Text(
                          'Mantra Text',
                          style: TextStyle(
                            fontSize: context.r.sp(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const RSizedBox(h: 12),
                    TextField(
                      controller: _mantraController,
                      enabled: !_hasStarted && !_isPlaying,
                      maxLines: null,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText:
                            'Enter your mantra or paste full text\n(e.g., OM Namah Shivay, Hanuman Chalisa...)',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: context.r.sp(14),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r.scale(12)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r.scale(12)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r.scale(12)),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF69B4),
                            width: 2,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r.scale(12)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: context.r.symmetric(
                          h: 16,
                          v: 14,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: context.r.sp(16),
                        color: AppColors.textPrimary(context),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _currentMantraText = value.trim();
                        });
                      },
                    ),
                    if (_hasStarted || _isPlaying)
                      Padding(
                        padding: EdgeInsets.only(top: context.r.scale(8)),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: context.r.scale(14),
                              color: Colors.grey[500],
                            ),
                            const RSizedBox(w: 4),
                              Text(
                                'Mantra locked during session',
                                style: TextStyle(
                                  fontSize: context.r.sp(12),
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // Voice Recording Section
            if (_inputMode == InputMode.voice)
              GlassContainer(
                padding: context.r.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mic,
                          color: const Color(0xFFFF69B4),
                          size: context.r.scale(20),
                        ),
                        const RSizedBox(w: 8),
                        Text(
                          'Voice Mantra',
                          style: TextStyle(
                            fontSize: context.r.sp(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const RSizedBox(h: 16),
                    if (_recordedAudioPath == null) ...[
                      Center(
                        child: Column(
                          children: [
                            Semantics(
                              label: _isRecording ? 'Stop recording' : 'Record mantra',
                              button: true,
                              child: GestureDetector(
                                onTap: (_hasStarted || _isPlaying)
                                    ? null
                                    : _toggleRecording,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: context.r.scale(100),
                                  height: context.r.scale(100),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isRecording
                                        ? Colors.red
                                        : const Color(0xFFFF69B4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isRecording
                                                ? Colors.red
                                                : const Color(0xFFFF69B4))
                                            .withValues(alpha: 0.4),
                                        blurRadius: _isRecording ? 30 : 15,
                                        spreadRadius: _isRecording ? 10 : 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isRecording ? Icons.stop : Icons.mic,
                                    color: Colors.white,
                                    size: context.r.scale(40),
                                  ),
                                ),
                              ),
                            ),
                    const RSizedBox(h: 12),
                            Text(
                              _isRecording
                                  ? 'Recording... ${_formatDuration(_recordingDuration)}'
                                  : 'Tap to Record Your Mantra',
                              style: TextStyle(
                                fontSize: context.r.sp(14),
                                fontWeight: FontWeight.w600,
                                color: _isRecording
                                    ? Colors.red
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                            if (_isRecording)
                              Padding(
                        padding: EdgeInsets.only(top: context.r.scale(8)),
                                child: Text(
                                  'Tap to Stop',
                                  style: TextStyle(
                                    fontSize: context.r.sp(12),
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: context.r.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(context.r.scale(12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: context.r.scale(50),
                              height: context.r.scale(50),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF69B4).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.audio_file,
                                color: const Color(0xFFFF69B4),
                                size: context.r.scale(24),
                              ),
                            ),
                            const RSizedBox(w: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Voice Mantra Recorded',
                                    style: TextStyle(
                                      fontSize: context.r.sp(14),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const RSizedBox(h: 4),
                                  Text(
                                    'Duration: ${_formatDuration(_recordingDuration)}',
                                    style: TextStyle(
                                      fontSize: context.r.sp(12),
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Semantics(
                                  label: _isAudioPlaying ? 'Stop playing' : 'Play recorded mantra',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: _playRecordedMantra,
                                      child: Container(
                                        padding: context.r.all(10),
                                        decoration: BoxDecoration(
                                          color: _isAudioPlaying
                                              ? const Color(0xFFFF69B4)
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFF69B4),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          _isAudioPlaying
                                              ? Icons.stop
                                              : Icons.play_arrow,
                                          color: _isAudioPlaying
                                              ? Colors.white
                                              : const Color(0xFFFF69B4),
                                          size: context.r.scale(20),
                                        ),
                                      ),
                                  ),
                                ),
                                if (!_hasStarted && !_isPlaying) ...[
                                  const RSizedBox(w: 8),
                                  Semantics(
                                    label: 'Delete recording',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _recordedAudioPath = null;
                                          _recordingDuration = Duration.zero;
                                        });
                                      },
                                      child: Container(
                                        padding: context.r.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.refresh,
                                          color: Colors.red,
                                          size: context.r.scale(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_hasStarted || _isPlaying)
                        Padding(
                          padding: EdgeInsets.only(top: context.r.scale(8)),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                              size: context.r.scale(14),
                                color: Colors.grey[500],
                              ),
                              const RSizedBox(w: 4),
                              Text(
                                'Voice mantra locked during session',
                                style: TextStyle(
                                  fontSize: context.r.sp(12),
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),

            const RSizedBox(h: 16),

            // Jaap Counter Slider Section
            GlassContainer(
              padding: context.r.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.repeat,
                            color: Color(0xFFFF69B4),
                      size: context.r.scale(20),
                    ),
                    const RSizedBox(w: 8),
                          Text(
                            'Jaap Count Target',
                            style: TextStyle(
                              fontSize: context.r.sp(14),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding:
                            context.r.symmetric(h: 12, v: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF69B4).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(context.r.scale(20)),
                        ),
                        child: Text(
                          JaapMilestones.getDisplayLabel(_target),
                          style: TextStyle(
                            fontSize: context.r.sp(14),
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF69B4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const RSizedBox(h: 20),

                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFFF69B4),
                      inactiveTrackColor: Colors.grey[300],
                      thumbColor: const Color(0xFFFF69B4),
                      overlayColor: const Color(0xFFFF69B4).withValues(alpha: 0.2),
                      valueIndicatorColor: const Color(0xFFFF69B4),
                      valueIndicatorTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      trackHeight: 8,
                    ),
                    child: Slider(
                      value: _sliderValue,
                      min: 0,
                      max: JaapMilestones.values.length - 1.0,
                      divisions: JaapMilestones.values.length - 1,
                      label: _target.toString(),
                      onChanged:
                          (_hasStarted || _isPlaying) ? null : _onSliderChanged,
                    ),
                  ),

                  const RSizedBox(h: 12),

                  // Milestone indicators with granular tick marks
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final maxVal = JaapMilestones.values.last.toDouble();
                      final keyMilestones = [1, 108, 1008, 10800, 100000, 125000];
                      return SizedBox(
                        height: 28,
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: keyMilestones.map((m) {
                                  final pos = (m / maxVal) * totalWidth;
                                  final isReached = _target >= m;
                                  return Positioned(
                                    left: pos - 1,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 2,
                                      decoration: BoxDecoration(
                                        color: isReached
                                            ? const Color(0xFFFF69B4)
                                            : Colors.grey[400]!,
                                        borderRadius: BorderRadius.circular(context.r.scale(1)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: keyMilestones.map((m) {
                                final isReached = _target >= m;
                                return Text(
                                  m >= 100000 ? '${m ~/ 100000}L' : m >= 1000 ? '${m ~/ 1000}K' : '$m',
                                  style: TextStyle(
                                    fontSize: context.r.sp(10),
                                    fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
                                    color: isReached
                                        ? const Color(0xFFFF69B4)
                                        : Colors.grey[500],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const RSizedBox(h: 16),

                  // Traditional significance text
                  Container(
                    padding: context.r.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(context.r.scale(8)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: context.r.scale(16),
                          color: const Color(0xFFFF69B4),
                        ),
                        const RSizedBox(w: 8),
                        Expanded(
                          child: Text(
                            _getMilestoneDescription(_target),
                            style: TextStyle(
                              fontSize: context.r.sp(12),
                              color: AppColors.textSecondary(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const RSizedBox(h: 16),

            // Timer Display
            GlassContainer(
              padding: context.r.symmetric(h: 32, v: 16),
              child: Text(
                _formattedTime,
                style: TextStyle(
                  fontSize: context.r.sp(48),
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),

            const RSizedBox(h: 24),

            Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: context.r.scale(240),
                    height: context.r.scale(240),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isPlaying
                            ? [const Color(0xFFFF69B4), const Color(0xFFFF1493)]
                            : [const Color(0xFFFFB2EE), const Color(0xFFFF69B4)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB2EE).withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _count.toString(),
                          style: TextStyle(
                            fontSize: context.r.sp(72),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '/ $_target',
                          style: TextStyle(
                            fontSize: context.r.sp(24),
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        if (_isPlaying) ...[
                    const RSizedBox(h: 12),
                          Container(
                            padding:
                                context.r.symmetric(h: 12, v: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(context.r.scale(12)),
                            ),
                            child: Text(
                              'PLAYING',
                              style: TextStyle(
                                fontSize: context.r.sp(12),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_showCelebration)
                  AnimatedOpacity(
                    opacity: _showCelebration ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      width: context.r.scale(260),
                      height: context.r.scale(260),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF69B4).withValues(alpha: 0.6),
                            blurRadius: 60,
                            spreadRadius: 25,
                          ),
                        ],
                      ),
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: context.r.all(16),
                            child: Text(
                              _celebrationMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: context.r.sp(26),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFF69B4),
                                    blurRadius: 25,
                                  ),
                                  Shadow(
                                    color: Color(0xFFFF1493),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const RSizedBox(h: 12),
            TextWithScrim(
              child: Text(
              _isPlaying
                  ? 'Auto-chanting in progress...'
                  : 'Press Play to Start Jaap',
              style: TextStyle(
                fontSize: context.r.sp(16),
                color: Colors.grey[600],
                fontStyle: _isPlaying ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            ),

            const RSizedBox(h: 24),

            // Progress Bar
            GlassContainer(
              padding: context.r.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: context.r.sp(14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${((_count / _target) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: context.r.sp(14),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFB2EE),
                        ),
                      ),
                    ],
                  ),
                  const RSizedBox(h: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.r.scale(8)),
                    child: LinearProgressIndicator(
                      value: _count / _target,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFB2EE),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const RSizedBox(h: 20),

            // Main Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause Button
                Semantics(
                  label: _isPlaying ? 'Pause' : _isPaused ? 'Resume' : 'Start',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      if (_isPlaying) {
                        _pauseJaap();
                      } else if (_isPaused) {
                        _resumeJaap();
                      } else {
                        _startJaapLoop();
                      }
                    },
                    child: Container(
                      width: context.r.scale(80),
                      height: context.r.scale(80),
                    decoration: BoxDecoration(
                      color: _isPlaying
                          ? Colors.orange
                          : (_isPaused ? const Color(0xFFFF69B4) : const Color(0xFF4CAF50)),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isPlaying
                                  ? Colors.orange
                                  : (_isPaused
                                      ? const Color(0xFFFF69B4)
                                      : const Color(0xFF4CAF50)))
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause
                          : (_isPaused ? Icons.play_arrow : Icons.play_arrow),
                      color: Colors.white,
                      size: context.r.scale(40),
                    ),
                  ),
                ),
                  ),
                const RSizedBox(w: 24),
                // Stop Button
                if (_isPlaying || _isPaused || _count > 0)
                  Semantics(
                    label: 'Stop',
                    button: true,
                    child: GestureDetector(
                      onTap: _stopJaap,
                      child: Container(
                        width: context.r.scale(60),
                        height: context.r.scale(60),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: context.r.scale(30),
                        ),
                      ),
                    ),
                  ),
                if (_isPlaying || _isPaused || _count > 0) const RSizedBox(w: 24),
                // Reset Button
                Semantics(
                  label: 'Reset',
                  button: true,
                  child: GestureDetector(
                    onTap: _reset,
                    child: Container(
                      padding: context.r.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: AppColors.textPrimary(context),
                        size: context.r.scale(32),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const RSizedBox(h: 28),

            // Recent Naam Jaap Records Section
            if (_recentSessions.isNotEmpty)
              GlassContainer(
                padding: context.r.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: const Color(0xFFFF69B4),
                              size: context.r.scale(20),
                            ),
                            const RSizedBox(w: 8),
                            Text(
                              'Recent Naam Jaap',
                              style: TextStyle(
                        fontSize: context.r.sp(16),
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_recentSessions.length} sessions',
                          style: TextStyle(
                            fontSize: context.r.sp(12),
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const RSizedBox(h: 16),
                    ...List.generate(
                        _recentSessions.length > 5 ? 5 : _recentSessions.length,
                        (index) {
                      final session = _recentSessions[index];
                      final mantraText =
                          session['mantraText'] ?? 'Unknown Mantra';
                      final count = session['count'] ?? 0;
                      final target = session['target'] ?? 108;
                      final percentage = session['percentage'] ??
                          ((count / target) * 100).round();
                      final timestamp = session['timestamp'] ??
                          DateTime.now().toIso8601String();
                      final isComplete = count >= target;
                      final isVoice = session['isVoice'] == true;
                      final audioPath = session['audioPath'] as String?;

                      return Dismissible(
                        key: Key('session_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: context.r.scale(16)),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                        onDismissed: (_) => _deleteSession(index),
                        child: Container(
                          margin: EdgeInsets.only(bottom: context.r.scale(12)),
                          padding: context.r.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(context.r.scale(12)),
                            border: Border.all(
                              color: isComplete
                                  ? const Color(0xFFFF69B4).withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: context.r.scale(36),
                                height: context.r.scale(36),
                                decoration: BoxDecoration(
                                  color: isComplete
                                      ? const Color(0xFFFF69B4).withValues(alpha: 0.2)
                                      : Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isVoice
                                      ? Icon(
                                          Icons.mic,
                                          size: context.r.scale(18),
                                          color: isComplete
                                              ? const Color(0xFFFF69B4)
                                              : Colors.grey[600],
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: context.r.sp(14),
                                            fontWeight: FontWeight.bold,
                                            color: isComplete
                                                ? const Color(0xFFFF69B4)
                                                : Colors.grey[600],
                                          ),
                                        ),
                                ),
                              ),
                              const RSizedBox(w: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            isVoice
                                                ? 'VOICE JAAP'
                                                : 'JAAP → "$mantraText"',
                                            style: TextStyle(
                          fontSize: context.r.sp(14),
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary(context),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isVoice && audioPath != null)
                                          Semantics(
                                            label: 'Play session audio',
                                            button: true,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _playSessionAudio(audioPath),
                                              child:                                               Container(
                                                padding: context.r.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF69B4)
                                                      .withValues(alpha: 0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _isAudioPlaying
                                                      ? Icons.stop
                                                      : Icons.play_arrow,
                                                  size: context.r.scale(16),
                                                  color: const Color(0xFFFF69B4),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const RSizedBox(h: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: context.r.scale(12),
                                          color: Colors.grey[500],
                                        ),
                            const RSizedBox(w: 4),
                                        Text(
                                          _formatDateTime(timestamp),
                                          style: TextStyle(
                                            fontSize: context.r.sp(12),
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const RSizedBox(h: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: count / target,
                                              minHeight: 6,
                                              backgroundColor: Colors.grey[300],
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                isComplete
                                                    ? const Color(0xFFFF69B4)
                                                    : Colors.grey[500]!,
                                              ),
                                            ),
                                          ),
                                        ),
                              const RSizedBox(w: 12),
                                        Text(
                                          '$count/$target',
                                          style: TextStyle(
                                            fontSize: context.r.sp(12),
                                            fontWeight: FontWeight.w600,
                                            color: isComplete
                                                ? const Color(0xFFFF69B4)
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const RSizedBox(w: 8),
                                        Container(
                                          padding: context.r.symmetric(
                                            h: 8,
                                            v: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isComplete
                                                ? const Color(0xFFFF69B4)
                                                    .withValues(alpha: 0.2)
                                                : Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(context.r.scale(12)),
                                          ),
                                          child: Text(
                                            '$percentage% Complete',
                                            style: TextStyle(
                                              fontSize: context.r.sp(11),
                                              fontWeight: FontWeight.w600,
                                              color: isComplete
                                                  ? const Color(0xFFFF69B4)
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const RSizedBox(h: 20),
          ],
        ),
      ),
    );
  }

  String _getMilestoneDescription(int target) {
    switch (target) {
      case 1:
        return 'Beej Mantra - Single sacred seed sound';
      case 11:
        return 'Short count for daily prayers when time is limited';
      case 21:
        return 'Daily prayer count for quick spiritual connection';
      case 108:
        return 'Standard Mala - 108 Nadis converging at Heart Chakra';
      case 1008:
        return '9 Malas - Sacred multiple for enhanced spiritual power';
      case 1080:
        return '10 Malas (Dash-Mala) - Common daily goal for practitioners';
      case 1188:
        return '11 Malas - Used for specific Anushthans (rituals)';
      case 5508:
        return '51 Malas - Halfway to major milestone';
      case 10008:
        return '92 Malas - Advanced practitioner count';
      case 10800:
        return '100 Malas - Significant spiritual milestone';
      case 11000:
        return 'First major Sankalp (vow) completion';
      case 21000:
        return '7-day Saptah count - Week-long observance';
      case 31000:
        return 'Mid-point marker for long-term Jaap';
      case 51000:
        return 'Major milestone approaching Lakh';
      case 100000:
        return 'Lakh-Jaap - Minimum for Mantra Siddhi (attaining power)';
      case 125000:
        return 'Sava-Lakh - Complete Purashcharana (accounts for mistakes)';
      default:
        return 'Custom count for your spiritual practice';
    }
  }
}

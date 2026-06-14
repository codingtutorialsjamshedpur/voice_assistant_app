import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/voice_effect_model.dart';

/// Pure-Dart DSP voice effect processor.
///
/// The recording pipeline records to PCM-WAV (16-bit, mono, 44100 Hz).
/// This class reads the WAV, applies DSP, and writes a new WAV file.
class VoiceEffectProcessor {
  static const int _sampleRate = 44100;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  // ─────────────────────────────────────────────────────────────────────────
  // Public entry point
  // ─────────────────────────────────────────────────────────────────────────

  /// Applies [effect] to the WAV file at [inputPath].
  /// Returns the path of the processed WAV, or [inputPath] on failure.
  static Future<String> applyEffect(
      String inputPath, VoiceEffect effect) async {
    try {
      debugPrint('VoiceEffectProcessor: applying ${effect.name}');

      final pcm = await _readWavPcm(inputPath);
      if (pcm == null || pcm.isEmpty) {
        debugPrint(
            'VoiceEffectProcessor: could not read PCM, returning original');
        return inputPath;
      }

      final processed =
          await compute(_applyDspIsolate, _DspArgs(pcm, effect.type));

      final outputPath = await _writeWav(processed, effect.id);
      return outputPath ?? inputPath;
    } catch (e, st) {
      debugPrint('VoiceEffectProcessor error: $e\n$st');
      return inputPath;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WAV I/O
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Int16List?> _readWavPcm(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();

      // Minimal WAV parser – find 'data' chunk
      int dataOffset = -1;
      int dataSize = 0;
      for (int i = 12; i < bytes.length - 8; i++) {
        if (bytes[i] == 0x64 && // 'd'
            bytes[i + 1] == 0x61 && // 'a'
            bytes[i + 2] == 0x74 && // 't'
            bytes[i + 3] == 0x61) {
          // 'a'
          final bd = ByteData.sublistView(bytes);
          dataSize = bd.getUint32(i + 4, Endian.little);
          dataOffset = i + 8;
          break;
        }
      }

      if (dataOffset < 0) {
        // Fallback: assume standard 44-byte header
        dataOffset = 44;
        dataSize = bytes.length - 44;
      }

      if (dataOffset >= bytes.length || dataSize <= 0) return null;

      final pcmBytes = bytes.sublist(dataOffset, dataOffset + dataSize);
      final samples = Int16List(pcmBytes.length ~/ 2);
      final bd = ByteData.sublistView(Uint8List.fromList(pcmBytes));
      for (int i = 0; i < samples.length; i++) {
        samples[i] = bd.getInt16(i * 2, Endian.little);
      }
      return samples;
    } catch (e) {
      debugPrint('_readWavPcm error: $e');
      return null;
    }
  }

  static Future<String?> _writeWav(Int16List samples, String effectId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${recordingsDir.path}/fx_${effectId}_$ts.wav';
      final wavBytes = _buildWav(samples);
      await File(outPath).writeAsBytes(wavBytes);
      return outPath;
    } catch (e) {
      debugPrint('_writeWav error: $e');
      return null;
    }
  }

  static Uint8List _buildWav(Int16List samples) {
    final dataSize = samples.length * 2;
    final totalSize = 44 + dataSize;
    final buf = Uint8List(totalSize);
    final bd = ByteData.sublistView(buf);

    void writeStr(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buf[offset + i] = s.codeUnitAt(i);
      }
    }

    writeStr(0, 'RIFF');
    bd.setUint32(4, totalSize - 8, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // chunk size
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, _channels, Endian.little);
    bd.setUint32(24, _sampleRate, Endian.little);
    bd.setUint32(
        28, _sampleRate * _channels * _bitsPerSample ~/ 8, Endian.little);
    bd.setUint16(32, _channels * _bitsPerSample ~/ 8, Endian.little);
    bd.setUint16(34, _bitsPerSample, Endian.little);
    writeStr(36, 'data');
    bd.setUint32(40, dataSize, Endian.little);

    // Write PCM samples
    for (int i = 0; i < samples.length; i++) {
      bd.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return buf;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Isolate wrapper
  // ─────────────────────────────────────────────────────────────────────────

  static Int16List _applyDspIsolate(_DspArgs args) {
    return _applyDsp(args.samples, args.type);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DSP dispatcher
  // ─────────────────────────────────────────────────────────────────────────

  static Int16List _applyDsp(Int16List samples, VoiceEffectType type) {
    switch (type) {
      // ── Basic Modulation ──────────────────────────────────────────────────
      case VoiceEffectType.bassBoost:
        return _bassBoost(samples);
      case VoiceEffectType.trebleBoost:
        return _trebleBoost(samples);
      case VoiceEffectType.whisper:
        return _whisper(samples);
      case VoiceEffectType.monster:
        return _pitchShift(_bassBoostRaw(samples, 1.4), 0.60);
      case VoiceEffectType.chipmunk:
        return _pitchShift(samples, 1.50);
      case VoiceEffectType.demon:
        return _pitchShift(_bassBoostRaw(samples, 1.6), 0.40);
      case VoiceEffectType.helium:
        return _pitchShift(samples, 1.30);
      case VoiceEffectType.radioWalkieTalkie:
        return _radio(samples);

      // ── Space & Environment ───────────────────────────────────────────────
      case VoiceEffectType.caveEcho:
        return _echo(samples, delayMs: 900, decay: 0.55, repeats: 4);
      case VoiceEffectType.concertHall:
        return _reverb(samples, roomSize: 0.85, wet: 0.55);
      case VoiceEffectType.bathroomReverb:
        return _reverb(samples, roomSize: 0.45, wet: 0.65);
      case VoiceEffectType.tunnel:
        return _echo(samples, delayMs: 600, decay: 0.60, repeats: 3);
      case VoiceEffectType.underwater:
        return _underwater(samples);
      case VoiceEffectType.outerSpace:
        return _outerSpace(samples);

      // ── Sci-Fi & Futuristic ───────────────────────────────────────────────
      case VoiceEffectType.cyber:
        return _cyber(samples);
      case VoiceEffectType.glitch:
        return _glitch(samples);
      case VoiceEffectType.alien:
        return _alien(samples);
      case VoiceEffectType.aiAssistant:
        return _aiAssistant(samples);
      case VoiceEffectType.timeWarp:
        return _timeWarp(samples);
      case VoiceEffectType.reverse:
        return _reverse(samples);

      // ── Musical ───────────────────────────────────────────────────────────
      case VoiceEffectType.autoTune:
        return _autoTune(samples);
      case VoiceEffectType.harmony:
        return _harmony(samples);
      case VoiceEffectType.vibrato:
        return _vibrato(samples, rate: 5.0, depth: 0.008);
      case VoiceEffectType.chorus:
        return _chorus(samples);
      case VoiceEffectType.flanger:
        return _flanger(samples);
      case VoiceEffectType.phaser:
        return _phaser(samples);

      // ── Fun & Character ───────────────────────────────────────────────────
      case VoiceEffectType.oldMan:
        return _pitchShift(samples, 0.75);
      case VoiceEffectType.baby:
        return _pitchShift(samples, 1.60);
      case VoiceEffectType.cartoon:
        return _cartoon(samples);
      case VoiceEffectType.ghost:
        return _ghost(samples);
      case VoiceEffectType.zombie:
        return _pitchShift(_bassBoostRaw(samples, 1.3), 0.55);
      case VoiceEffectType.drunk:
        return _drunk(samples);

      // ── Distortion & Texture ──────────────────────────────────────────────
      case VoiceEffectType.megaphone:
        return _megaphone(samples);
      case VoiceEffectType.telephone:
        return _telephone(samples);
      case VoiceEffectType.brokenSpeaker:
        return _brokenSpeaker(samples);
      case VoiceEffectType.staticNoise:
        return _staticNoise(samples);
      case VoiceEffectType.bitcrusher:
        return _bitcrusher(samples, bits: 8);

      // ── Smart / AI ────────────────────────────────────────────────────────
      case VoiceEffectType.emotionModifier:
        return _emotionModifier(samples);
      case VoiceEffectType.accentConverter:
        return _pitchShift(samples, 0.98);
      case VoiceEffectType.genderSwap:
        return _pitchShift(samples, 0.82);
      case VoiceEffectType.voiceCloning:
        return _chorus(samples);
      case VoiceEffectType.noiseRemoval:
        return _noiseGate(samples);
      case VoiceEffectType.spatialAudio:
        return _spatialAudio(samples);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DSP Primitives
  // ─────────────────────────────────────────────────────────────────────────

  static int _clamp(double v) => v.clamp(-32768.0, 32767.0).round();

  // ── Pitch shift via resampling ────────────────────────────────────────────
  /// Shifts pitch by [factor] (>1 = higher, <1 = lower).
  /// Uses linear interpolation resampling then trims/pads to original length.
  static Int16List _pitchShift(Int16List src, double factor) {
    final newLen = (src.length / factor).round();
    final resampled = Int16List(newLen);
    for (int i = 0; i < newLen; i++) {
      final srcIdx = i * factor;
      final lo = srcIdx.floor().clamp(0, src.length - 1);
      final hi = (lo + 1).clamp(0, src.length - 1);
      final frac = srcIdx - lo;
      resampled[i] = _clamp(src[lo] * (1 - frac) + src[hi] * frac);
    }
    // Trim or pad to original length
    final out = Int16List(src.length);
    final copyLen = math.min(resampled.length, src.length);
    out.setRange(0, copyLen, resampled);
    return out;
  }

  // ── Echo ──────────────────────────────────────────────────────────────────
  static Int16List _echo(Int16List src,
      {int delayMs = 500, double decay = 0.4, int repeats = 3}) {
    final delaySamples = (_sampleRate * delayMs / 1000).round();
    final out = Float64List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = src[i].toDouble();
    }
    for (int r = 1; r <= repeats; r++) {
      final d = delaySamples * r;
      final amp = math.pow(decay, r).toDouble();
      for (int i = d; i < src.length; i++) {
        out[i] += src[i - d] * amp;
      }
    }
    return _normalizeToInt16(out);
  }

  // ── Schroeder Reverb ──────────────────────────────────────────────────────
  static Int16List _reverb(Int16List src,
      {double roomSize = 0.7, double wet = 0.4}) {
    const combDelays = [1557, 1617, 1491, 1422];
    const apDelays = [225, 556];
    final dry = 1.0 - wet;

    final combOuts =
        List.generate(combDelays.length, (_) => Float64List(src.length));

    for (int c = 0; c < combDelays.length; c++) {
      final delay = combDelays[c];
      final buf = Float64List(delay);
      int ptr = 0;
      for (int i = 0; i < src.length; i++) {
        final x = src[i].toDouble();
        final y = buf[ptr];
        buf[ptr] = x + y * roomSize;
        ptr = (ptr + 1) % delay;
        combOuts[c][i] = y;
      }
    }

    final mixed = Float64List(src.length);
    for (int i = 0; i < src.length; i++) {
      for (int c = 0; c < combDelays.length; c++) {
        mixed[i] += combOuts[c][i] * 0.25;
      }
    }

    for (final delay in apDelays) {
      final buf = Float64List(delay);
      int ptr = 0;
      for (int i = 0; i < src.length; i++) {
        final x = mixed[i];
        final y = buf[ptr];
        buf[ptr] = x + y * 0.5;
        ptr = (ptr + 1) % delay;
        mixed[i] = y - x * 0.5;
      }
    }

    final out = Float64List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = src[i] * dry + mixed[i] * wet;
    }
    return _normalizeToInt16(out);
  }

  // ── Bass Boost ────────────────────────────────────────────────────────────
  static Int16List _bassBoost(Int16List src) => _bassBoostRaw(src, 1.5);

  static Int16List _bassBoostRaw(Int16List src, double gain) {
    const fc = 200.0 / _sampleRate;
    final a = math.exp(-2 * math.pi * fc);
    final b = 1 - a;
    double prev = 0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final x = src[i].toDouble();
      prev = a * prev + b * x;
      out[i] = _clamp(x + prev * (gain - 1));
    }
    return out;
  }

  // ── Treble Boost ──────────────────────────────────────────────────────────
  static Int16List _trebleBoost(Int16List src) {
    const fc = 3000.0 / _sampleRate;
    final a = math.exp(-2 * math.pi * fc);
    final b = 1 - a;
    double prev = 0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final x = src[i].toDouble();
      prev = a * prev + b * x;
      final high = x - prev;
      out[i] = _clamp(x + high * 1.5);
    }
    return out;
  }

  // ── Whisper ───────────────────────────────────────────────────────────────
  static Int16List _whisper(Int16List src) {
    final rng = math.Random(42);
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final noise = (rng.nextDouble() * 2 - 1) * 2000;
      out[i] = _clamp(src[i] * 0.4 + noise);
    }
    return out;
  }

  // ── Radio / Walkie-Talkie ─────────────────────────────────────────────────
  static Int16List _radio(Int16List src) {
    final bp = _bandPass(src, 300, 3400);
    final rng = math.Random(7);
    final out = Int16List(bp.length);
    for (int i = 0; i < bp.length; i++) {
      final noise = (rng.nextDouble() * 2 - 1) * 800;
      double v = bp[i] * 1.8 + noise;
      v = v.clamp(-28000, 28000);
      out[i] = _clamp(v);
    }
    return out;
  }

  // ── Filters ───────────────────────────────────────────────────────────────
  static Int16List _bandPass(Int16List src, double lowHz, double highHz) {
    return _lowPass(_highPass(src, lowHz), highHz);
  }

  static Int16List _lowPass(Int16List src, double cutoffHz) {
    final rc = 1.0 / (2 * math.pi * cutoffHz);
    const dt = 1.0 / _sampleRate;
    final alpha = dt / (rc + dt);
    double prev = 0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      prev = prev + alpha * (src[i] - prev);
      out[i] = _clamp(prev);
    }
    return out;
  }

  static Int16List _highPass(Int16List src, double cutoffHz) {
    final rc = 1.0 / (2 * math.pi * cutoffHz);
    const dt = 1.0 / _sampleRate;
    final alpha = rc / (rc + dt);
    double prev = 0;
    double prevX = 0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final x = src[i].toDouble();
      prev = alpha * (prev + x - prevX);
      prevX = x;
      out[i] = _clamp(prev);
    }
    return out;
  }

  // ── Underwater ────────────────────────────────────────────────────────────
  static Int16List _underwater(Int16List src) {
    final lp = _lowPass(src, 800);
    return _vibrato(lp, rate: 3.0, depth: 0.005);
  }

  // ── Outer Space ───────────────────────────────────────────────────────────
  static Int16List _outerSpace(Int16List src) {
    final flanged = _flanger(src);
    return _echo(flanged, delayMs: 600, decay: 0.35, repeats: 3);
  }

  // ── Cyber ─────────────────────────────────────────────────────────────────
  static Int16List _cyber(Int16List src) {
    final ch = _chorus(src);
    return _echo(ch, delayMs: 50, decay: 0.4, repeats: 2);
  }

  // ── Glitch ────────────────────────────────────────────────────────────────
  static Int16List _glitch(Int16List src) {
    final rng = math.Random(13);
    final out = Int16List.fromList(src);
    const chunkSize = _sampleRate ~/ 20;
    for (int i = 0; i < src.length - chunkSize; i += chunkSize) {
      if (rng.nextDouble() < 0.15) {
        final start = math.max(0, i - chunkSize);
        out.setRange(i, i + chunkSize, src, start);
      }
    }
    return _vibrato(out, rate: 15.0, depth: 0.006);
  }

  // ── Alien ─────────────────────────────────────────────────────────────────
  static Int16List _alien(Int16List src) {
    final out = Float64List(src.length);
    for (int i = 0; i < src.length; i++) {
      final lfo = math.sin(2 * math.pi * 4.0 * i / _sampleRate);
      final shift = 1.2 + lfo * 0.15;
      final srcIdx = (i * shift).round().clamp(0, src.length - 1);
      out[i] = src[srcIdx].toDouble();
    }
    return _normalizeToInt16(out);
  }

  // ── AI Assistant ──────────────────────────────────────────────────────────
  static Int16List _aiAssistant(Int16List src) {
    final bp = _bandPass(src, 200, 8000);
    return _compress(bp, threshold: 0.6, ratio: 3.0);
  }

  // ── Time Warp ─────────────────────────────────────────────────────────────
  static Int16List _timeWarp(Int16List src) {
    final out = Float64List(src.length);
    double srcPos = 0;
    for (int i = 0; i < src.length; i++) {
      final speed = 0.85 + 0.3 * math.sin(2 * math.pi * 0.5 * i / _sampleRate);
      final idx = srcPos.floor().clamp(0, src.length - 1);
      out[i] = src[idx].toDouble();
      srcPos += speed;
      if (srcPos >= src.length) break;
    }
    return _normalizeToInt16(out);
  }

  // ── Reverse ───────────────────────────────────────────────────────────────
  static Int16List _reverse(Int16List src) {
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = src[src.length - 1 - i];
    }
    return out;
  }

  // ── Auto-Tune ─────────────────────────────────────────────────────────────
  static Int16List _autoTune(Int16List src) {
    return _vibrato(src, rate: 6.0, depth: 0.003);
  }

  // ── Harmony ───────────────────────────────────────────────────────────────
  static Int16List _harmony(Int16List src) {
    final shifted = _pitchShift(src, 1.25);
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = _clamp(src[i] * 0.6 + shifted[i] * 0.4);
    }
    return out;
  }

  // ── Vibrato ───────────────────────────────────────────────────────────────
  static Int16List _vibrato(Int16List src,
      {double rate = 5.0, double depth = 0.008}) {
    final maxDelay = math.max(2, (depth * _sampleRate).round());
    final buf = List<double>.filled(maxDelay + 2, 0.0);
    int writePtr = 0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      buf[writePtr % buf.length] = src[i].toDouble();
      final lfo = (math.sin(2 * math.pi * rate * i / _sampleRate) + 1) / 2;
      final delay = lfo * maxDelay;
      final readPtr = (writePtr - delay).floor();
      final frac = delay - delay.floor();
      final a = buf[((readPtr) % buf.length + buf.length) % buf.length];
      final b = buf[((readPtr - 1) % buf.length + buf.length) % buf.length];
      out[i] = _clamp(a * (1 - frac) + b * frac);
      writePtr++;
    }
    return out;
  }

  // ── Chorus ────────────────────────────────────────────────────────────────
  static Int16List _chorus(Int16List src) {
    final v1 = _vibrato(src, rate: 1.5, depth: 0.006);
    final v2 = _vibrato(src, rate: 2.3, depth: 0.008);
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = _clamp(src[i] * 0.5 + v1[i] * 0.25 + v2[i] * 0.25);
    }
    return out;
  }

  // ── Flanger ───────────────────────────────────────────────────────────────
  static Int16List _flanger(Int16List src) {
    const maxDelay = 441;
    final buf = List<double>.filled(maxDelay + 2, 0.0);
    int writePtr = 0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      buf[writePtr % buf.length] = src[i].toDouble();
      final lfo = (math.sin(2 * math.pi * 0.5 * i / _sampleRate) + 1) / 2;
      final delay = (lfo * maxDelay).round();
      final readPtr =
          ((writePtr - delay) % buf.length + buf.length) % buf.length;
      out[i] = _clamp((src[i] + buf[readPtr] * 0.7) * 0.7);
      writePtr++;
    }
    return out;
  }

  // ── Phaser ────────────────────────────────────────────────────────────────
  static Int16List _phaser(Int16List src) {
    final out = Float64List(src.length);
    double ap1 = 0, ap2 = 0;
    for (int i = 0; i < src.length; i++) {
      final lfo = math.sin(2 * math.pi * 0.5 * i / _sampleRate);
      final coeff = 0.5 + lfo * 0.4;
      final x = src[i].toDouble();
      final y1 = -coeff * x + ap1 + coeff * ap1;
      ap1 = x;
      final y2 = -coeff * y1 + ap2 + coeff * ap2;
      ap2 = y1;
      out[i] = (x + y2) * 0.5;
    }
    return _normalizeToInt16(out);
  }

  // ── Cartoon ───────────────────────────────────────────────────────────────
  static Int16List _cartoon(Int16List src) {
    final shifted = _pitchShift(src, 1.25);
    return _vibrato(shifted, rate: 8.0, depth: 0.005);
  }

  // ── Ghost ─────────────────────────────────────────────────────────────────
  static Int16List _ghost(Int16List src) {
    final hp = _highPass(src, 800);
    final echoed = _echo(hp, delayMs: 800, decay: 0.5, repeats: 3);
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = _clamp(echoed[i] * 0.7);
    }
    return out;
  }

  // ── Drunk ─────────────────────────────────────────────────────────────────
  static Int16List _drunk(Int16List src) {
    return _vibrato(src, rate: 3.0, depth: 0.012);
  }

  // ── Megaphone ─────────────────────────────────────────────────────────────
  static Int16List _megaphone(Int16List src) {
    final bp = _bandPass(src, 200, 4000);
    final out = Int16List(bp.length);
    for (int i = 0; i < bp.length; i++) {
      double v = bp[i] * 2.5;
      v = v.clamp(-24000, 24000);
      out[i] = _clamp(v);
    }
    return out;
  }

  // ── Telephone ─────────────────────────────────────────────────────────────
  static Int16List _telephone(Int16List src) {
    return _bandPass(src, 300, 3400);
  }

  // ── Broken Speaker ────────────────────────────────────────────────────────
  static Int16List _brokenSpeaker(Int16List src) {
    final rng = math.Random(55);
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      double v = src[i].toDouble();
      if (rng.nextDouble() < 0.05) {
        v *= (rng.nextDouble() * 3 + 0.5);
      }
      out[i] = _clamp(v.clamp(-32000, 32000));
    }
    return out;
  }

  // ── Static Noise ──────────────────────────────────────────────────────────
  static Int16List _staticNoise(Int16List src) {
    final rng = math.Random(77);
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final noise = (rng.nextDouble() * 2 - 1) * 3000;
      out[i] = _clamp(src[i] * 0.85 + noise);
    }
    return out;
  }

  // ── Bitcrusher ────────────────────────────────────────────────────────────
  static Int16List _bitcrusher(Int16List src, {int bits = 8}) {
    final levels = math.pow(2, bits).toInt();
    final step = 65536 ~/ levels;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final v = src[i] + 32768;
      final crushed = (v ~/ step) * step;
      out[i] = (crushed - 32768).clamp(-32768, 32767);
    }
    return out;
  }

  // ── Emotion Modifier ──────────────────────────────────────────────────────
  static Int16List _emotionModifier(Int16List src) {
    final shifted = _pitchShift(src, 1.08);
    return _compress(shifted, threshold: 0.5, ratio: 2.5);
  }

  // ── Noise Gate ────────────────────────────────────────────────────────────
  static Int16List _noiseGate(Int16List src) {
    const threshold = 1500.0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = src[i].abs() > threshold ? src[i] : 0;
    }
    return out;
  }

  // ── Spatial Audio ─────────────────────────────────────────────────────────
  static Int16List _spatialAudio(Int16List src) {
    final delayed = _echo(src, delayMs: 30, decay: 0.3, repeats: 1);
    return _vibrato(delayed, rate: 0.5, depth: 0.002);
  }

  // ── Compressor ────────────────────────────────────────────────────────────
  static Int16List _compress(Int16List src,
      {double threshold = 0.7, double ratio = 3.0}) {
    double peak = 0;
    for (final s in src) {
      if (s.abs() > peak) peak = s.abs().toDouble();
    }
    if (peak == 0) return src;
    final threshAbs = threshold * peak;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      final v = src[i].toDouble();
      final abs = v.abs();
      if (abs > threshAbs) {
        final excess = abs - threshAbs;
        final compressed = threshAbs + excess / ratio;
        out[i] = _clamp(v.sign * compressed);
      } else {
        out[i] = src[i];
      }
    }
    return out;
  }

  // ── Normalize Float64 → Int16 ─────────────────────────────────────────────
  static Int16List _normalizeToInt16(Float64List src) {
    double peak = 0;
    for (final v in src) {
      if (v.abs() > peak) peak = v.abs();
    }
    final scale = peak > 32767 ? 32767 / peak : 1.0;
    final out = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      out[i] = (src[i] * scale).round().clamp(-32768, 32767);
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate argument container
// ─────────────────────────────────────────────────────────────────────────────

class _DspArgs {
  final Int16List samples;
  final VoiceEffectType type;
  _DspArgs(this.samples, this.type);
}

import 'package:flutter/material.dart';

enum EffectCategory {
  basicModulation,
  spaceEnvironment,
  sciFiFuturistic,
  musical,
  funCharacter,
  distortionTexture,
  smartAi,
}

extension EffectCategoryExtension on EffectCategory {
  String get displayName {
    switch (this) {
      case EffectCategory.basicModulation:
        return 'Basic Modulation';
      case EffectCategory.spaceEnvironment:
        return 'Space & Environment';
      case EffectCategory.sciFiFuturistic:
        return 'Sci-Fi & Futuristic';
      case EffectCategory.musical:
        return 'Musical';
      case EffectCategory.funCharacter:
        return 'Fun & Character';
      case EffectCategory.distortionTexture:
        return 'Distortion & Texture';
      case EffectCategory.smartAi:
        return 'Smart / AI-Based';
    }
  }

  IconData get icon {
    switch (this) {
      case EffectCategory.basicModulation:
        return Icons.tune;
      case EffectCategory.spaceEnvironment:
        return Icons.landscape;
      case EffectCategory.sciFiFuturistic:
        return Icons.smart_toy;
      case EffectCategory.musical:
        return Icons.music_note;
      case EffectCategory.funCharacter:
        return Icons.emoji_emotions;
      case EffectCategory.distortionTexture:
        return Icons.graphic_eq;
      case EffectCategory.smartAi:
        return Icons.psychology;
    }
  }
}

enum VoiceEffectType {
  // Basic Modulation
  bassBoost,
  trebleBoost,
  whisper,
  monster,
  chipmunk,
  demon,
  helium,
  radioWalkieTalkie,

  // Space & Environment
  caveEcho,
  concertHall,
  bathroomReverb,
  tunnel,
  underwater,
  outerSpace,

  // Sci-Fi & Futuristic
  cyber,
  glitch,
  alien,
  aiAssistant,
  timeWarp,
  reverse,

  // Musical
  autoTune,
  harmony,
  vibrato,
  chorus,
  flanger,
  phaser,

  // Fun & Character
  oldMan,
  baby,
  cartoon,
  ghost,
  zombie,
  drunk,

  // Distortion & Texture
  megaphone,
  telephone,
  brokenSpeaker,
  staticNoise,
  bitcrusher,

  // Smart/AI
  emotionModifier,
  accentConverter,
  genderSwap,
  voiceCloning,
  noiseRemoval,
  spatialAudio,
}

class VoiceEffect {
  final String id;
  final String name;
  final String description;
  final VoiceEffectType type;
  final EffectCategory category;
  final IconData icon;
  final Color color;
  final bool isPremium;
  final Map<String, dynamic> parameters;

  const VoiceEffect({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    required this.icon,
    required this.color,
    this.isPremium = false,
    this.parameters = const {},
  });

  static List<VoiceEffect> get allEffects => [
        // Basic Modulation
        const VoiceEffect(
          id: 'bass_boost',
          name: 'Bass Boost',
          description: 'Deep, radio-style voice',
          type: VoiceEffectType.bassBoost,
          category: EffectCategory.basicModulation,
          icon: Icons.speaker,
          color: Color(0xFF8B4513),
        ),
        const VoiceEffect(
          id: 'treble_boost',
          name: 'Treble Boost',
          description: 'Sharp, crisp voice',
          type: VoiceEffectType.trebleBoost,
          category: EffectCategory.basicModulation,
          icon: Icons.high_quality,
          color: Color(0xFF4682B4),
        ),
        const VoiceEffect(
          id: 'whisper',
          name: 'Whisper',
          description: 'Soft airy voice',
          type: VoiceEffectType.whisper,
          category: EffectCategory.basicModulation,
          icon: Icons.hearing,
          color: Color(0xFFB0C4DE),
        ),
        const VoiceEffect(
          id: 'monster',
          name: 'Monster',
          description: 'Low pitch + distortion',
          type: VoiceEffectType.monster,
          category: EffectCategory.basicModulation,
          icon: Icons.sentiment_very_dissatisfied,
          color: Color(0xFF2F4F4F),
        ),
        const VoiceEffect(
          id: 'chipmunk',
          name: 'Chipmunk',
          description: 'High pitch + fast speed',
          type: VoiceEffectType.chipmunk,
          category: EffectCategory.basicModulation,
          icon: Icons.emoji_nature,
          color: Color(0xFFFFD700),
        ),
        const VoiceEffect(
          id: 'demon',
          name: 'Demon',
          description: 'Very low pitch + slow speed',
          type: VoiceEffectType.demon,
          category: EffectCategory.basicModulation,
          icon: Icons.local_fire_department,
          color: Color(0xFF8B0000),
        ),
        const VoiceEffect(
          id: 'helium',
          name: 'Helium',
          description: 'High pitch with natural tone',
          type: VoiceEffectType.helium,
          category: EffectCategory.basicModulation,
          icon: Icons.bubble_chart,
          color: Color(0xFF87CEEB),
        ),
        const VoiceEffect(
          id: 'radio',
          name: 'Radio/Walkie-Talkie',
          description: 'Band-pass filter + noise',
          type: VoiceEffectType.radioWalkieTalkie,
          category: EffectCategory.basicModulation,
          icon: Icons.radio,
          color: Color(0xFF556B2F),
        ),

        // Space & Environment
        const VoiceEffect(
          id: 'cave_echo',
          name: 'Cave Echo',
          description: 'Long, natural echo',
          type: VoiceEffectType.caveEcho,
          category: EffectCategory.spaceEnvironment,
          icon: Icons.nature,
          color: Color(0xFF696969),
        ),
        const VoiceEffect(
          id: 'concert_hall',
          name: 'Concert Hall',
          description: 'Wide reverb',
          type: VoiceEffectType.concertHall,
          category: EffectCategory.spaceEnvironment,
          icon: Icons.theater_comedy,
          color: Color(0xFF9370DB),
        ),
        const VoiceEffect(
          id: 'bathroom_reverb',
          name: 'Bathroom',
          description: 'Tight reflective echo',
          type: VoiceEffectType.bathroomReverb,
          category: EffectCategory.spaceEnvironment,
          icon: Icons.bathtub,
          color: Color(0xFF00CED1),
        ),
        const VoiceEffect(
          id: 'tunnel',
          name: 'Tunnel',
          description: 'Hollow resonance',
          type: VoiceEffectType.tunnel,
          category: EffectCategory.spaceEnvironment,
          icon: Icons.door_front_door,
          color: Color(0xFF808080),
        ),
        const VoiceEffect(
          id: 'underwater',
          name: 'Underwater',
          description: 'Low-pass filter + bubbling',
          type: VoiceEffectType.underwater,
          category: EffectCategory.spaceEnvironment,
          icon: Icons.water,
          color: Color(0xFF006994),
        ),
        const VoiceEffect(
          id: 'outer_space',
          name: 'Outer Space',
          description: 'Flanger + slow modulation',
          type: VoiceEffectType.outerSpace,
          category: EffectCategory.spaceEnvironment,
          icon: Icons.rocket_launch,
          color: Color(0xFF191970),
        ),

        // Sci-Fi & Futuristic
        const VoiceEffect(
          id: 'cyber',
          name: 'Cyber Voice',
          description: 'Metallic + auto-tune',
          type: VoiceEffectType.cyber,
          category: EffectCategory.sciFiFuturistic,
          icon: Icons.memory,
          color: Color(0xFF00FF00),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'glitch',
          name: 'Glitch',
          description: 'Digital distortion',
          type: VoiceEffectType.glitch,
          category: EffectCategory.sciFiFuturistic,
          icon: Icons.bug_report,
          color: Color(0xFFFF1493),
        ),
        const VoiceEffect(
          id: 'alien',
          name: 'Alien',
          description: 'Random pitch modulation',
          type: VoiceEffectType.alien,
          category: EffectCategory.sciFiFuturistic,
          icon: Icons.face,
          color: Color(0xFF32CD32),
        ),
        const VoiceEffect(
          id: 'ai_assistant',
          name: 'AI Assistant',
          description: 'Clean + slight vocoder',
          type: VoiceEffectType.aiAssistant,
          category: EffectCategory.sciFiFuturistic,
          icon: Icons.support_agent,
          color: Color(0xFF4169E1),
        ),
        const VoiceEffect(
          id: 'time_warp',
          name: 'Time Warp',
          description: 'Speed fluctuations',
          type: VoiceEffectType.timeWarp,
          category: EffectCategory.sciFiFuturistic,
          icon: Icons.timelapse,
          color: Color(0xFF9932CC),
        ),
        const VoiceEffect(
          id: 'reverse',
          name: 'Reverse',
          description: 'Play backward',
          type: VoiceEffectType.reverse,
          category: EffectCategory.sciFiFuturistic,
          icon: Icons.reply,
          color: Color(0xFFFF6347),
        ),

        // Musical
        const VoiceEffect(
          id: 'auto_tune',
          name: 'Auto-Tune',
          description: 'Pitch correction',
          type: VoiceEffectType.autoTune,
          category: EffectCategory.musical,
          icon: Icons.mic,
          color: Color(0xFFFF69B4),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'harmony',
          name: 'Harmony',
          description: 'Adds background vocals',
          type: VoiceEffectType.harmony,
          category: EffectCategory.musical,
          icon: Icons.people,
          color: Color(0xFFDA70D6),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'vibrato',
          name: 'Vibrato',
          description: 'Wavy pitch modulation',
          type: VoiceEffectType.vibrato,
          category: EffectCategory.musical,
          icon: Icons.waves,
          color: Color(0xFF20B2AA),
        ),
        const VoiceEffect(
          id: 'chorus',
          name: 'Chorus',
          description: 'Layered voice effect',
          type: VoiceEffectType.chorus,
          category: EffectCategory.musical,
          icon: Icons.layers,
          color: Color(0xFF6495ED),
        ),
        const VoiceEffect(
          id: 'flanger',
          name: 'Flanger',
          description: 'Jet-like modulation',
          type: VoiceEffectType.flanger,
          category: EffectCategory.musical,
          icon: Icons.airplanemode_active,
          color: Color(0xFF1E90FF),
        ),
        const VoiceEffect(
          id: 'phaser',
          name: 'Phaser',
          description: 'Sweeping frequency effect',
          type: VoiceEffectType.phaser,
          category: EffectCategory.musical,
          icon: Icons.swap_calls,
          color: Color(0xFF00FA9A),
        ),

        // Fun & Character
        const VoiceEffect(
          id: 'old_man',
          name: 'Old Man',
          description: 'Elderly voice simulation',
          type: VoiceEffectType.oldMan,
          category: EffectCategory.funCharacter,
          icon: Icons.elderly,
          color: Color(0xFFCD853F),
        ),
        const VoiceEffect(
          id: 'baby',
          name: 'Baby',
          description: 'Infant voice simulation',
          type: VoiceEffectType.baby,
          category: EffectCategory.funCharacter,
          icon: Icons.child_care,
          color: Color(0xFFFFB6C1),
        ),
        const VoiceEffect(
          id: 'cartoon',
          name: 'Cartoon',
          description: 'Animated character voice',
          type: VoiceEffectType.cartoon,
          category: EffectCategory.funCharacter,
          icon: Icons.animation,
          color: Color(0xFFFFA500),
        ),
        const VoiceEffect(
          id: 'ghost',
          name: 'Ghost',
          description: 'Whisper + echo',
          type: VoiceEffectType.ghost,
          category: EffectCategory.funCharacter,
          icon: Icons.cloud,
          color: Color(0xFFF0F8FF),
        ),
        const VoiceEffect(
          id: 'zombie',
          name: 'Zombie',
          description: 'Distorted + slow',
          type: VoiceEffectType.zombie,
          category: EffectCategory.funCharacter,
          icon: Icons.biotech,
          color: Color(0xFF556B2F),
        ),
        const VoiceEffect(
          id: 'drunk',
          name: 'Drunk',
          description: 'Slight pitch wobble',
          type: VoiceEffectType.drunk,
          category: EffectCategory.funCharacter,
          icon: Icons.local_bar,
          color: Color(0xFF8B4513),
        ),

        // Distortion & Texture
        const VoiceEffect(
          id: 'megaphone',
          name: 'Megaphone',
          description: 'Distorted loudspeaker',
          type: VoiceEffectType.megaphone,
          category: EffectCategory.distortionTexture,
          icon: Icons.record_voice_over,
          color: Color(0xFFFF4500),
        ),
        const VoiceEffect(
          id: 'telephone',
          name: 'Telephone',
          description: 'Narrow frequency',
          type: VoiceEffectType.telephone,
          category: EffectCategory.distortionTexture,
          icon: Icons.phone,
          color: Color(0xFF708090),
        ),
        const VoiceEffect(
          id: 'broken_speaker',
          name: 'Broken Speaker',
          description: 'Crackling distortion',
          type: VoiceEffectType.brokenSpeaker,
          category: EffectCategory.distortionTexture,
          icon: Icons.speaker_notes_off,
          color: Color(0xFF8B0000),
        ),
        const VoiceEffect(
          id: 'static_noise',
          name: 'Static Noise',
          description: 'Radio static mix',
          type: VoiceEffectType.staticNoise,
          category: EffectCategory.distortionTexture,
          icon: Icons.noise_aware,
          color: Color(0xFFA9A9A9),
        ),
        const VoiceEffect(
          id: 'bitcrusher',
          name: 'Bitcrusher',
          description: '8-bit digital sound',
          type: VoiceEffectType.bitcrusher,
          category: EffectCategory.distortionTexture,
          icon: Icons.videogame_asset,
          color: Color(0xFF9400D3),
        ),

        // Smart/AI-Based
        const VoiceEffect(
          id: 'emotion_modifier',
          name: 'Emotion AI',
          description: 'Happy, Angry, Sad tone',
          type: VoiceEffectType.emotionModifier,
          category: EffectCategory.smartAi,
          icon: Icons.mood,
          color: Color(0xFFFF1493),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'accent_converter',
          name: 'Accent AI',
          description: 'Indian, British, American',
          type: VoiceEffectType.accentConverter,
          category: EffectCategory.smartAi,
          icon: Icons.translate,
          color: Color(0xFF4682B4),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'gender_swap',
          name: 'Gender Swap',
          description: 'Voice gender modification',
          type: VoiceEffectType.genderSwap,
          category: EffectCategory.smartAi,
          icon: Icons.swap_horiz,
          color: Color(0xFFFF69B4),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'voice_cloning',
          name: 'Voice Clone',
          description: 'Clone your voice',
          type: VoiceEffectType.voiceCloning,
          category: EffectCategory.smartAi,
          icon: Icons.fingerprint,
          color: Color(0xFF2E8B57),
          isPremium: true,
        ),
        const VoiceEffect(
          id: 'noise_removal',
          name: 'Noise Removal',
          description: 'Clean background noise',
          type: VoiceEffectType.noiseRemoval,
          category: EffectCategory.smartAi,
          icon: Icons.cleaning_services,
          color: Color(0xFF00CED1),
        ),
        const VoiceEffect(
          id: 'spatial_audio',
          name: '3D Spatial',
          description: '3D spatial audio voice',
          type: VoiceEffectType.spatialAudio,
          category: EffectCategory.smartAi,
          icon: Icons.threed_rotation,
          color: Color(0xFF9932CC),
          isPremium: true,
        ),
      ];

  static List<VoiceEffect> getEffectsByCategory(EffectCategory category) {
    return allEffects.where((e) => e.category == category).toList();
  }

  static VoiceEffect? getById(String id) {
    try {
      return allEffects.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  String getFfmpegFilter() {
    switch (type) {
      // Basic Modulation
      case VoiceEffectType.bassBoost:
        return 'bass=g=15:f=100:w=0.5';
      case VoiceEffectType.trebleBoost:
        return 'treble=g=10:f=3000:w=0.5';
      case VoiceEffectType.whisper:
        return 'highpass=f=1000,volume=0.8';
      case VoiceEffectType.monster:
        return 'asetrate=44100*0.6,aresample=44100,bass=g=20';
      case VoiceEffectType.chipmunk:
        return 'asetrate=44100*1.5,aresample=44100,atempo=1.3';
      case VoiceEffectType.demon:
        return 'asetrate=44100*0.4,aresample=44100,atempo=0.7,bass=g=25';
      case VoiceEffectType.helium:
        return 'asetrate=44100*1.3,aresample=44100';
      case VoiceEffectType.radioWalkieTalkie:
        return 'bandpass=f=1000:w=500,highpass=f=300,lowpass=f=3000';

      // Space & Environment
      case VoiceEffectType.caveEcho:
        return 'aecho=0.8:0.9:1000|1800:0.3|0.25';
      case VoiceEffectType.concertHall:
        return 'aecho=0.6:0.7:300|500|700:0.4|0.3|0.2';
      case VoiceEffectType.bathroomReverb:
        return 'aecho=0.7:0.6:200:0.5';
      case VoiceEffectType.tunnel:
        return 'aecho=0.5:0.8:800:0.6,lowpass=f=2000';
      case VoiceEffectType.underwater:
        return 'lowpass=f=800,aecho=0.3:0.4:100:0.2,vibrato=f=3:d=0.5';
      case VoiceEffectType.outerSpace:
        return 'flanger=delay=10:depth=5:regen=50,aecho=0.4:0.5:600:0.3';

      // Sci-Fi & Futuristic
      case VoiceEffectType.cyber:
        return 'aecho=0.3:0.5:50:0.4,chorus=0.7:0.9:55|65|75:0.4|0.32|0.3:0.25|0.4|0.3:2|2.3|2.6';
      case VoiceEffectType.glitch:
        return 'vibrato=f=15:d=0.8,chorus=0.5:0.9:50|60:0.4|0.32:0.25|0.4:2|2.3';
      case VoiceEffectType.alien:
        return 'vibrato=f=8:d=0.9,asetrate=44100*1.2,aresample=44100';
      case VoiceEffectType.aiAssistant:
        return 'highpass=f=200,lowpass=f=8000,compand=0.3|0.3:1|1:-90/-60|-60/-40|-40/-30|-20/-20:6:0:-90:0.2';
      case VoiceEffectType.timeWarp:
        return 'rubberband=tempo=0.7|1.5:pitch=0.8|1.2';
      case VoiceEffectType.reverse:
        return 'areverse';

      // Musical
      case VoiceEffectType.autoTune:
        return 'rubberband=pitch=1.0:formant=1.2';
      case VoiceEffectType.harmony:
        return 'aecho=0.5:0.5:100:0.3,asetrate=44100*1.1,aresample=44100,amix=inputs=2:duration=longest';
      case VoiceEffectType.vibrato:
        return 'vibrato=f=5:d=0.8';
      case VoiceEffectType.chorus:
        return 'chorus=0.7:0.9:55|65|75:0.4|0.32|0.3:0.25|0.4|0.3:2|2.3|2.6';
      case VoiceEffectType.flanger:
        return 'flanger=delay=3:depth=2:regen=0:width=71:speed=0.5:shape=sine:phase=25';
      case VoiceEffectType.phaser:
        return 'aphaser=in_gain=0.8:out_gain=0.8:delay=3.0:decay=0.4:speed=0.5:type=t';

      // Fun & Character
      case VoiceEffectType.oldMan:
        return 'asetrate=44100*0.75,aresample=44100,lowpass=f=4000';
      case VoiceEffectType.baby:
        return 'asetrate=44100*1.6,aresample=44100,highpass=f=500';
      case VoiceEffectType.cartoon:
        return 'asetrate=44100*1.25,aresample=44100,vibrato=f=8:d=0.5';
      case VoiceEffectType.ghost:
        return 'aecho=0.6:0.8:800|1200:0.4|0.3,highpass=f=800,volume=0.7';
      case VoiceEffectType.zombie:
        return 'asetrate=44100*0.55,aresample=44100,atempo=0.6,lowpass=f=1500';
      case VoiceEffectType.drunk:
        return 'vibrato=f=3:d=0.9,rubberband=pitch=0.95|1.05';

      // Distortion & Texture
      case VoiceEffectType.megaphone:
        return 'bandpass=f=1200:w=400,highpass=f=200,volume=2.0';
      case VoiceEffectType.telephone:
        return 'bandpass=f=1000:w=600,highpass=f=300,lowpass=f=3400';
      case VoiceEffectType.brokenSpeaker:
        return 'acrusher=bits=4:mix=0.5,vibrato=f=10:d=0.3';
      case VoiceEffectType.staticNoise:
        return 'anoisesrc=a=0.1:c=pink[noise];[0:a][noise]amix=inputs=2:duration=first,volume=1.5';
      case VoiceEffectType.bitcrusher:
        return 'acrusher=bits=8:mix=0.7';

      // Smart/AI-Based
      case VoiceEffectType.emotionModifier:
        return 'rubberband=formant=1.1:tempo=1.05,compand=0.3|0.3:1|1:-90/-60|-60/-40|-40/-30|-20/-20:6:0:-90:0.2';
      case VoiceEffectType.accentConverter:
        return 'rubberband=pitch=0.98:formant=1.15';
      case VoiceEffectType.genderSwap:
        return 'rubberband=pitch=0.85:formant=1.3';
      case VoiceEffectType.voiceCloning:
        return 'rubberband=pitch=1.0:formant=1.0:tempo=1.0';
      case VoiceEffectType.noiseRemoval:
        return 'anlmdn=s=7:p=0.002:r=0.002';
      case VoiceEffectType.spatialAudio:
        return 'sofalizer=sofa=/path/to/default.sofa:type=freq:radius=1:rotation=45';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.toString(),
        'category': category.toString(),
        'isPremium': isPremium,
        'parameters': parameters,
      };

  factory VoiceEffect.fromJson(Map<String, dynamic> json) {
    return VoiceEffect(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: VoiceEffectType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => VoiceEffectType.caveEcho,
      ),
      category: EffectCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => EffectCategory.spaceEnvironment,
      ),
      icon: Icons.music_note,
      color: const Color(0xFFFFB2EE),
      isPremium: json['isPremium'] ?? false,
      parameters: json['parameters'] ?? {},
    );
  }
}

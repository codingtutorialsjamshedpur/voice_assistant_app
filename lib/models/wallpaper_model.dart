import 'dart:io';

enum WallpaperType {
  image,
  video,
}

enum WallpaperSource {
  asset,
  file,
  network,
}

class Wallpaper {
  final String id;
  final String name;
  final String path;
  final WallpaperType type;
  final WallpaperSource source;
  final bool isDefault;
  final bool isPremium;
  final double volume;
  final bool isMuted;

  const Wallpaper({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.source,
    this.isDefault = false,
    this.isPremium = false,
    this.volume = 0.0,
    this.isMuted = true,
  });

  bool get isVideo => type == WallpaperType.video;
  bool get isImage => type == WallpaperType.image;
  bool get isAsset => source == WallpaperSource.asset;
  bool get isFile => source == WallpaperSource.file;
  bool get isNetwork => source == WallpaperSource.network;

  /// Whether this is a network wallpaper that has been downloaded locally
  bool get isDownloaded => id.startsWith('network_') && isFile;

  /// Whether this is a custom-uploaded wallpaper
  bool get isCustom => id.startsWith('file_');

  /// For network wallpapers, the ID contains the remote filename/path
  String? get remotePath {
    if (id.startsWith('network_')) {
      return id.replaceFirst('network_', '');
    }
    return null;
  }

  /// Get the effective volume (0.0 if muted, otherwise the volume level)
  double get effectiveVolume => isMuted ? 0.0 : volume;

  factory Wallpaper.fromNetwork(String fileName, String networkUrl,
      {bool isDefault = false, bool isPremium = false}) {
    final name = fileName.split('.').first;
    final extension = fileName.split('.').last.toLowerCase();

    final type =
        (extension == 'mp4' || extension == 'mov' || extension == 'avi')
            ? WallpaperType.video
            : WallpaperType.image;

    return Wallpaper(
      id: 'network_$fileName',
      name: name,
      path: networkUrl,
      type: type,
      source: WallpaperSource.network,
      isDefault: isDefault,
      isPremium: isPremium,
    );
  }

  factory Wallpaper.fromAsset(String assetPath, {bool isDefault = false, bool isPremium = false}) {
    final fileName = assetPath.split('/').last;
    final name = fileName.split('.').first;
    final extension = fileName.split('.').last.toLowerCase();

    final type =
        (extension == 'mp4' || extension == 'mov' || extension == 'avi')
            ? WallpaperType.video
            : WallpaperType.image;

    return Wallpaper(
      id: 'asset_$fileName',
      name: name,
      path: assetPath,
      type: type,
      source: WallpaperSource.asset,
      isDefault: isDefault,
      isPremium: isPremium,
    );
  }

  factory Wallpaper.fromFile(String filePath, {bool isDefault = false, bool isPremium = false}) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final name = fileName.split('.').first;
    final extension = fileName.split('.').last.toLowerCase();

    final type =
        (extension == 'mp4' || extension == 'mov' || extension == 'avi')
            ? WallpaperType.video
            : WallpaperType.image;

    return Wallpaper(
      id: 'file_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      name: name,
      path: filePath,
      type: type,
      source: WallpaperSource.file,
      isDefault: isDefault,
      isPremium: isPremium,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type.name,
      'source': source.name,
      'isDefault': isDefault,
      'isPremium': isPremium,
      'volume': volume,
      'isMuted': isMuted,
    };
  }

  factory Wallpaper.fromJson(Map<String, dynamic> json) {
    return Wallpaper(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      type: WallpaperType.values.byName(json['type']),
      source: WallpaperSource.values.byName(json['source']),
      isDefault: json['isDefault'] ?? false,
      isPremium: json['isPremium'] ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      isMuted: json['isMuted'] ?? true,
    );
  }

  Wallpaper copyWith({
    String? id,
    String? name,
    String? path,
    WallpaperType? type,
    WallpaperSource? source,
    bool? isDefault,
    bool? isPremium,
    double? volume,
    bool? isMuted,
  }) {
    return Wallpaper(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      source: source ?? this.source,
      isDefault: isDefault ?? this.isDefault,
      isPremium: isPremium ?? this.isPremium,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../controllers/wallpaper_controller.dart';
import '../../models/wallpaper_model.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../widgets/banner_ad_widget.dart';

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen>
    with SingleTickerProviderStateMixin {
  // Always use the global singleton — never create a second instance here.
  final WallpaperController _controller = Get.find<WallpaperController>();
  late TabController _tabController;

  // Video preview cache
  final Map<String, Uint8List?> _videoThumbnails = {};
  final Set<String> _loadingThumbnails = {};
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  Timer? _scrollDebounceTimer;

  // Color cache for video wallpapers
  final Map<String, Color> _videoColors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);

    // Generate colors for videos
    _generateVideoColors();

    // Load initial thumbnails after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVisibleThumbnails();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  void _generateVideoColors() {
    // Generate consistent colors for each video based on name
    final videoWallpapers = _controller.allWallpapers.where((w) => w.isVideo);
    for (final wallpaper in videoWallpapers) {
      _videoColors[wallpaper.id] = _getColorFromString(wallpaper.name);
    }
  }

  Color _getColorFromString(String input) {
    // Generate a consistent color from string
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.3).toColor();
  }

  void _onScroll() {
    if (!_isScrolling) {
      setState(() => _isScrolling = true);
    }

    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      setState(() => _isScrolling = false);
      _loadVisibleThumbnails();
    });
  }

  void _loadVisibleThumbnails() {
    if (!mounted) return;

    // Find visible videos and load thumbnails
    for (final wallpaper in _controller.allWallpapers.where((w) => w.isVideo)) {
      if (_videoThumbnails.containsKey(wallpaper.id) ||
          _loadingThumbnails.contains(wallpaper.id)) {
        continue;
      }

      // Check if visible (simplified check)
      _queueThumbnailLoad(wallpaper);
    }
  }

  void _queueThumbnailLoad(Wallpaper wallpaper) async {
    if (_loadingThumbnails.length >= 3) return; // Max 3 concurrent

    _loadingThumbnails.add(wallpaper.id);

    try {
      // For asset videos, we can't easily extract thumbnails
      // For file videos, we could use platform channels
      // For now, just use the color placeholder
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          _videoThumbnails[wallpaper.id] = null; // Use color placeholder
        });
      }
    } finally {
      _loadingThumbnails.remove(wallpaper.id);
    }
  }

  void _selectWallpaper(Wallpaper wallpaper) async {
    if (_controller.isMultiSelectMode.value) {
      if (wallpaper.isFile) {
        _controller.toggleSelection(wallpaper.id);
      }
      return;
    }
    await SoundService.to.playClick();
    Get.toNamed(AppRoutes.wallpaperSet, arguments: wallpaper);
  }

  void _onLongPress(Wallpaper wallpaper) {
    if (wallpaper.isFile) {
      _controller.toggleSelection(wallpaper.id);
      HapticFeedback.heavyImpact();
    }
  }

  void _navigateBack() async {
    if (_controller.isMultiSelectMode.value) {
      _controller.clearSelection();
      return;
    }
    await SoundService.to.playClick();
    Get.offAllNamed(AppRoutes.voiceChat);
  }

  void _showAddWallpaperDialog() {
    Get.bottomSheet(
      GlassContainer(
        padding: context.r.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Wallpaper',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF230F1F),
              ),
            ),
            const RSizedBox(h: 24),
            Row(
              children: [
                Expanded(
                  child: _buildAddOption(
                    'Static',
                    Icons.image,
                    const Color(0xFF64B5F6),
                    () {
                      Get.back();
                      _controller.pickAndUploadStaticWallpaper();
                    },
                  ),
                ),
                const RSizedBox(w: 16),
                Expanded(
                  child: _buildAddOption(
                    'Dynamic',
                    Icons.movie,
                    const Color(0xFFF06292),
                    () {
                      Get.back();
                      _controller.pickAndUploadDynamicWallpaper();
                    },
                  ),
                ),
              ],
            ),
            const RSizedBox(h: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Semantics(
      label: 'Add $label wallpaper',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
                  padding: context.r.all(16),
          decoration: BoxDecoration(
            color: color.withAlpha(51),
            borderRadius: BorderRadius.circular(context.r.scale(16)),
            border: Border.all(color: color.withAlpha(128)),
          ),
          child: Column(
            children: [
              Icon(icon, size: context.r.scale(32), color: color),
              const RSizedBox(h: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color.withAlpha(200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Obx(() => _controller.isMultiSelectMode.value
          ? const SizedBox.shrink()
          : Semantics(
              button: true,
              label: 'Add wallpaper',
              child: FloatingActionButton(
                onPressed: _showAddWallpaperDialog,
                backgroundColor: const Color(0xFFFFB2EE),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Obx(() => _buildHeader(context)),
            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary(context),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFFFB2EE),
              tabs: [
                Semantics(label: 'All wallpapers', button: true, child: Tab(text: 'All', icon: Icon(Icons.wallpaper))),
                Semantics(label: 'Static wallpapers', button: true, child: Tab(text: 'Static', icon: Icon(Icons.image))),
                Semantics(label: 'Dynamic wallpapers', button: true, child: Tab(text: 'Dynamic', icon: Icon(Icons.video_library))),
              ],
            ),
            // Static/Dynamic Count Summary
            Obx(() => Container(
                  width: double.infinity,
                  padding:
                      context.r.symmetric(v: 8, h: 16),
                  margin:
                      context.r.symmetric(h: 16, v: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined,
                          size: context.r.scale(16), color: Colors.blue[300]),
                      const RSizedBox(w: 4),
                      Text(
                        'Static: ${_controller.staticCount}',
                        style: AppTextStyles.bodySmall(context),
                      ),
                      const RSizedBox(w: 24),
                      Icon(Icons.videocam_outlined,
                          size: context.r.scale(16), color: Colors.pink[300]),
                      const RSizedBox(w: 4),
                      Text(
                        'Dynamic: ${_controller.dynamicCount}',
                        style: AppTextStyles.bodySmall(context),
                      ),
                    ],
                  ),
                )),
            // Banner Ad (below tabs)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: BannerAdWidget()),
            ),
            // Content
            Expanded(
              child: Obx(() {
                if (_controller.isLoading.value &&
                    _controller.allWallpapers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return TabletConstrained(
                  child: RefreshIndicator(
                  onRefresh: () => _controller.refreshWallpapers(),
                  color: const Color(0xFFFFB2EE),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWallpaperGrid(_controller.allWallpapers),
                      _buildWallpaperGrid(_controller.imageWallpapers),
                      _buildWallpaperGrid(_controller.videoWallpapers),
                    ],
                  ),
                ),
                );
              }),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildWallpaperGrid(List<Wallpaper> wallpapers) {
    if (wallpapers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wallpaper_outlined, size: context.r.scale(64), color: Colors.grey[400]),
            const RSizedBox(h: 16),
            Text('No wallpapers found',
                style: TextStyle(fontSize: context.r.sp(16), color: Colors.grey[600])),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1024 ? 4 : (width >= 600 ? 3 : 2);

    return GridView.builder(
      controller: _scrollController,
      padding: context.r.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: context.r.scale(12),
        mainAxisSpacing: context.r.scale(12),
        childAspectRatio: 0.75,
      ),
      itemCount: wallpapers.length,
      cacheExtent: 200, // Preload items near viewport
      itemBuilder: (context, index) {
        final wallpaper = wallpapers[index];
        return StaggeredFadeIn(index: index, child: _buildWallpaperCard(wallpaper));
      },
    );
  }

  Widget _buildWallpaperCard(Wallpaper wallpaper) {
    final isVideo = wallpaper.isVideo;
    final isCurrent = _controller.currentWallpaper.value?.id == wallpaper.id;
    final isSelected = _controller.selectedWallpaperIds.contains(wallpaper.id);
    final context = this.context;

    return Semantics(
      button: true,
      label: wallpaper.name,
      child: GestureDetector(
      onTap: () => _selectWallpaper(wallpaper),
      onLongPress: () => _onLongPress(wallpaper),
      child: GlassContainer(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'wallpaper_${wallpaper.id}',
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(context.r.scale(12))),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                        // Video thumbnail with color
                        if (isVideo && _videoThumbnails[wallpaper.id] != null)
                          Image.memory(
                            _videoThumbnails[wallpaper.id]!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _videoColors[wallpaper.id] ??
                                        Colors.grey[800]!,
                                    (_videoColors[wallpaper.id] ??
                                            Colors.grey[800]!)
                                        .withAlpha(180),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (isVideo)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _videoColors[wallpaper.id] ??
                                      Colors.grey[800]!,
                                  (_videoColors[wallpaper.id] ??
                                          Colors.grey[800]!)
                                      .withAlpha(120),
                                  Colors.black.withAlpha(60),
                                ],
                              ),
                            ),
                          )
                        else if (wallpaper.isNetwork &&
                            !_controller.isDownloaded(wallpaper))
                          CachedNetworkImage(
                            imageUrl: _controller.getPublicUrl(wallpaper),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[400],
                              child: const Icon(Icons.error_outline,
                                  color: Colors.white),
                            ),
                          )
                        else
                          Image(
                            image: wallpaper.isAsset
                                ? AssetImage(wallpaper.path)
                                : FileImage(File(wallpaper.path))
                                    as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        // Play button overlay for videos
                        if (isVideo)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(100),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(
                                    context.r.scale(_videoThumbnails[wallpaper.id] != null
                                        ? 12
                                        : 16)),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(120),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: context.r.scale(_videoThumbnails[wallpaper.id] != null
                                      ? 32
                                      : 40),
                                ),
                              ),
                            ),
                          ),
                        // Video badge
                        if (isVideo && _videoThumbnails[wallpaper.id] == null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: context.r.symmetric(
                                  h: 6, v: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(180),
                                borderRadius: BorderRadius.circular(context.r.scale(4)),
                              ),
                              child: Text(
                                'VIDEO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.r.sp(8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Duration label
                        if (isVideo)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: context.r.symmetric(
                                  h: 6, v: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(160),
                                borderRadius: BorderRadius.circular(context.r.scale(4)),
                              ),
                              child: Text(
                                '00:15',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.r.sp(10),
                                ),
                              ),
                            ),
                          ),
                        // Status badges (Current/Default)
                        if (isCurrent)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: context.r.symmetric(
                                  h: 8, v: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF66BB6A),
                                borderRadius: BorderRadius.circular(context.r.scale(6)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withAlpha(51),
                                      blurRadius: 4)
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: context.r.scale(10)),
                                  const RSizedBox(w: 4),
                                  Text(
                                    wallpaper.isDefault
                                        ? 'DEFAULT SET'
                                        : 'CURRENT SET',
                                    style: AppTextStyles.labelSmall(context).copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (wallpaper.isDefault)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: context.r.symmetric(
                                  h: 8, v: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB2EE),
                                borderRadius: BorderRadius.circular(context.r.scale(6)),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: AppTextStyles.labelSmall(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: context.r.symmetric(
                                  h: 8, v: 4),
                              decoration: BoxDecoration(
                                color: wallpaper.isPremium
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(context.r.scale(6)),
                              ),
                              child: Text(
                                wallpaper.isPremium ? 'PREMIUM' : 'FREE',
                                style: AppTextStyles.labelSmall(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        // Multi-select checkbox
                        if (_controller.isMultiSelectMode.value &&
                            wallpaper.isFile)
                          Positioned(
                            top: context.r.scale(8),
                            right: context.r.scale(8),
                            child: Container(
                              padding: context.r.all(2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFF69B4)
                                    : Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                Icons.check,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                size: context.r.scale(16),
                              ),
                            ),
                          ),
                      ],
                    ),
                    ),
                  ),
                ),
                Padding(
                  padding: context.r.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wallpaper.name,
                              style: AppTextStyles.labelMedium(context).copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isCurrent)
                              Text(
                                wallpaper.isDefault
                                    ? 'Default wallpaper is set'
                                    : 'Currently Set',
                                style: TextStyle(
                                  fontSize: context.r.sp(10),
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isVideo)
                        Icon(
                          wallpaper.isMuted || wallpaper.volume == 0
                              ? Icons.volume_off
                              : Icons.volume_up,
                          size: context.r.scale(14),
                          color: Colors.grey[600],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: context.r.all(16),
      child: Row(
        children: [
          Semantics(
            label: _controller.isMultiSelectMode.value
                ? 'Cancel multi-select'
                : 'Go back',
            button: true,
            child: GestureDetector(
              onTap: _navigateBack,
              child: Container(
                  padding: context.r.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(77),
                    borderRadius: BorderRadius.circular(context.r.scale(12)),
                ),
                child: Icon(
                  _controller.isMultiSelectMode.value
                      ? Icons.close
                      : Icons.arrow_back,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ),
          const RSizedBox(w: 16),
          Expanded(
            child: Text(
              _controller.isMultiSelectMode.value
                  ? '${_controller.selectedWallpaperIds.length} Selected'
                  : 'Wallpapers',
              style: TextStyle(
                fontSize: context.r.sp(24),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          if (_controller.isMultiSelectMode.value) ...[
            Semantics(
              label: 'Select all wallpapers',
              button: true,
              child: GestureDetector(
                onTap: () => _controller.selectAllSelectableWallpapers(),
                child: Container(
                  padding: context.r.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(51),
                    borderRadius: BorderRadius.circular(context.r.scale(12)),
                  ),
                  child: const Icon(Icons.select_all, color: Colors.blue),
                ),
              ),
            ),
            const RSizedBox(w: 8),
            Semantics(
              label: 'Delete selected wallpapers',
              button: true,
              child: GestureDetector(
                onTap: () => _controller.deleteSelectedWallpapers(),
                child: Container(
                  padding: context.r.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(51),
                    borderRadius: BorderRadius.circular(context.r.scale(12)),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

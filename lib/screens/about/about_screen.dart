import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../routes/app_routes.dart';
import '../../services/tts_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import 'pdf_viewer_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _floatController;
  late AnimationController _blinkController;
  late AnimationController _talkController;
  late AnimationController _rainbowController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contactKey = GlobalKey();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args is Map && args['scrollToContact'] == true) {
        _scrollToContact();
      }
    });
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _talkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);

    _rainbowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _startBlinking();
  }

  void _startBlinking() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
        _startBlinking();
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _floatController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    _rainbowController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToContact() {
    final context = _contactKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    try {
      final whatsappUrl = 'https://wa.me/$phoneNumber';
      if (!await launchUrl(Uri.parse(whatsappUrl))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Copies the PDF from assets to a temporary directory and returns the file path
  Future<String?> _copyPDFToTemp() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/RESUME.pdf');

      // Check if file already exists in temp
      if (await tempFile.exists()) {
        return tempFile.path;
      }

      // Copy from assets
      try {
        final byteData = await rootBundle.load('assets/RESUME.pdf');
        final buffer = byteData.buffer;
        await tempFile.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
        return tempFile.path;
      } catch (e) {
        // Asset doesn't exist
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resume file not found in assets'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _downloadResume() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB2EE)),
          ),
        ),
      );

      final pdfPath = await _copyPDFToTemp();

      // Hide loading indicator
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (pdfPath == null) {
        return;
      }

      // Try to open with system PDF viewer (which allows saving/downloading)
      final result = await OpenFile.open(pdfPath);

      if (result.type == ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Resume opened. Use your PDF viewer to save/download.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (result.type == ResultType.noAppToOpen) {
        // No PDF viewer installed, try to copy to Downloads
        await _copyToDownloads(pdfPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open resume: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToDownloads(String sourcePath) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access storage directory'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final downloadsDir = Directory('${directory.parent.path}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destinationFile =
          File('${downloadsDir.path}/Sourav_Kumar_Resume_$timestamp.pdf');

      await File(sourcePath).copy(destinationFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resume saved to: ${destinationFile.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                await OpenFile.open(destinationFile.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to downloads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _previewResume() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB2EE)),
          ),
        ),
      );

      final pdfPath = await _copyPDFToTemp();

      // Hide loading indicator
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (pdfPath == null) {
        return;
      }

      // Navigate to PDF viewer
      Get.to(() => PDFViewerScreen(
            pdfPath: pdfPath,
            title: 'Sourav Kumar - Resume',
          ));
    } catch (e) {
      // Hide loading indicator
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.about,
      content: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            const RSizedBox(h: 24),
            // NEW SPRITE GLASS ORB WITH FACE
            _buildGlassOrbWithFace(),
            const RSizedBox(h: 24),
            // App Name
            Text(
              'CTJ Voice Chat',
              style: TextStyle(
                fontSize: context.r.sp(32),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const RSizedBox(h: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: context.r.sp(16),
                color: AppColors.textSecondary(context),
              ),
            ),
            const RSizedBox(h: 8),
            Text(
              'Voice • Spirit • Wisdom',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.r.sp(13),
                height: 1.4,
                color: AppColors.textSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
            const RSizedBox(h: 32),
            // Developer Section with Profile Picture
            GlassContainer(
              padding: context.r.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Developer',
                    style: TextStyle(
                      fontSize: context.r.sp(18),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const RSizedBox(h: 16),
                  // Developer Profile Picture with 360° Rainbow Glow
                  _buildProfilePictureWithRainbowGlow(),
                  const RSizedBox(h: 16),
                  Text(
                    'Sourav Kumar',
                    style: TextStyle(
                    fontSize: context.r.sp(16),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const RSizedBox(h: 8),
                Text(
                  'Flutter Developer | AI Applications | Voice Technology',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.r.sp(13),
                      color: Colors.grey[600],
                    ),
                  ),
                  const RSizedBox(h: 12),
                  Text(
                    'Building Family-Friendly AI Experiences that help people learn, communicate, and grow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                    fontSize: context.r.sp(12),
                    height: 1.5,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const RSizedBox(h: 8),
                  Center(
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: context.r.scale(20),
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            const RSizedBox(h: 16),
            // About Content
            GlassContainer(
              padding: context.r.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'About',
                        style: TextStyle(
                    fontSize: context.r.sp(18),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      // AB-02: Read Aloud button
                      Semantics(
                        label: _isSpeaking ? 'Stop reading' : 'Read aloud',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            _isSpeaking ? Icons.volume_off : Icons.volume_up,
                            color: const Color(0xFFFF69B4),
                          ),
                          onPressed: () async {
                          try {
                            final tts = Get.find<TTSService>();
                            if (_isSpeaking) {
                              await tts.stop();
                              if (mounted) setState(() => _isSpeaking = false);
                            } else {
                              if (mounted) setState(() => _isSpeaking = true);
                              await tts.speak(
                                  'CTJ Voice Chat is a family-friendly AI platform designed for learning, communication, creativity, entertainment, and spiritual growth. Using voice or text, users can chat with AI, practice languages, play educational games, record voices, manage reminders, explore global radio and TV, and build positive daily habits. The platform supports multilingual conversations and adapts interactions based on user preferences, making technology more accessible for children, parents, and grandparents alike. Our mission is to create a safe, engaging, and meaningful digital companion that helps users learn, explore, and grow every day.');
                              if (mounted) setState(() => _isSpeaking = false);
                            }
                          } catch (_) {}
                        },
                      ),
                      ),
                    ],
                  ),
                  const RSizedBox(h: 12),
                  Text(
                    'CTJ Voice Chat is a family-friendly AI platform designed for learning, communication, creativity, entertainment, and spiritual growth.',
                    style: TextStyle(
                      fontSize: context.r.sp(14),
                      height: 1.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const RSizedBox(h: 12),
                  Text(
                    'Using voice or text, users can chat with AI, practice languages, play educational games, record voices, manage reminders, explore global radio and TV, and build positive daily habits in a single application.',
                    style: TextStyle(
                      fontSize: context.r.sp(14),
                      height: 1.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const RSizedBox(h: 12),
                  Text(
                    'The platform supports multilingual conversations and adapts interactions based on user preferences, making technology more accessible for children, parents, and grandparents alike.',
                    style: TextStyle(
                      fontSize: context.r.sp(14),
                      height: 1.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const RSizedBox(h: 12),
                  Text(
                    'Our mission is to create a safe, engaging, and meaningful digital companion that helps users learn, explore, and grow every day.',
                    style: TextStyle(
                      fontSize: context.r.sp(14),
                      height: 1.6,
                      color: AppColors.textSecondary(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const RSizedBox(h: 16),
            // Features
            GlassContainer(
              padding: context.r.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features',
                    style: TextStyle(
                      fontSize: context.r.sp(18),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const RSizedBox(h: 16),
                  _buildFeatureItem(Icons.chat, 'AI Voice Chat'),
                  _buildFeatureItem(Icons.sports_esports, 'Educational Games'),
                  _buildFeatureItem(Icons.translate, 'Language Learning'),
                  _buildFeatureItem(Icons.mic, 'Voice Studio'),
                  _buildFeatureItem(Icons.radio, 'World Radio & TV'),
                  _buildFeatureItem(Icons.alarm, 'Smart Reminders'),
                  _buildFeatureItem(Icons.self_improvement,
                      'Naam Jaap & Spiritual Tools'),
                  _buildFeatureItem(Icons.language, 'Multi-Language Support'),
                  _buildFeatureItem(Icons.family_restroom,
                      'Family-Friendly Experience'),
                ],
              ),
            ),
            const RSizedBox(h: 16),
            // Connect With Us Section
            GlassContainer(
              key: _contactKey,
              padding: context.r.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect With Us',
                    style: TextStyle(
                    fontSize: context.r.sp(18),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const RSizedBox(h: 16),
                _buildContactButton(
                    Icons.email,
                    'Email',
                    'support@voiceassistant.app',
                    () => _launchUrl('mailto:ctj.helpdesk@gmail.com'),
                  ),
                  _buildContactButton(
                    Icons.chat,
                    'WhatsApp',
                    '+91 7903638966',
                    () => _launchWhatsApp('917903638966'),
                  ),
                  _buildContactButton(
                    Icons.language,
                    'Website',
                    'voiceassistant.app',
                    () =>
                        _launchUrl('https://codingtutorialsjamshedpur.online'),
                  ),
                  _buildContactButton(
                    Icons.location_on,
                    'Location',
                    'Jamshedpur, India',
                    () =>
                        _launchUrl('https://maps.app.goo.gl/F6UpPpxDPa3wkpzL6'),
                  ),
                  _buildContactButton(
                    Icons.code,
                    'GitHub',
                    'github.com/CTJ-AI',
                    () => _launchUrl('https://github.com/CTJ-AI'),
                  ),
                  _buildContactButton(
                    Icons.people,
                    'LinkedIn',
                    'linkedin.com/company/ctj-ai',
                    () => _launchUrl('https://linkedin.com/company/ctj-ai'),
                  ),
                  const RSizedBox(h: 20),
                  // NEW RESUME BUTTON
                  _buildNewResumeButton(),
                ],
              ),
            ),
            const RSizedBox(h: 24),
            const RSizedBox(h: 16),
            // Copyright
            Text(
              '© 2026 CTJ AI. All rights reserved.',
              style: TextStyle(
                fontSize: context.r.sp(12),
                color: AppColors.textTertiary(context),
              ),
            ),
              const RSizedBox(h: 24),
            ],
          ),
        ),
    );
  }

  /// SPRITE GLASS ORB WITH FACE - Glass material with breathing, blinking & talking animations
  Widget _buildGlassOrbWithFace() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatValue = _floatController.value;
        final offsetY = (floatValue - 0.5) * 8;

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowValue = _glowController.value;
              final glowIntensity = 0.3 + (glowValue * 0.4);

              return Container(
                width: context.r.scale(140),
                height: context.r.scale(140),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.8,
                    colors: [
                      const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                      const Color(0xFFFFE4F5).withValues(alpha: 0.7),
                      const Color(0xFFFFB1EE).withValues(alpha: glowIntensity),
                      const Color(0xFFFF69B4).withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB1EE)
                          .withValues(alpha: 0.3 + glowValue * 0.3),
                      blurRadius: 30 + (glowValue * 15),
                      spreadRadius: 5 + (glowValue * 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.3),
                      blurRadius: 50,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.2, -0.2),
                          radius: 0.6,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Inner reflections
                          Positioned(
                            top: 25,
                            left: 30,
                            child: Container(
                              width: context.r.scale(20),
                              height: context.r.scale(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 35,
                            left: 25,
                            child: Container(
                              width: context.r.scale(8),
                              height: context.r.scale(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          // Animated Face with Blinking Eyes and Talking Mouth
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Blinking Eyes Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Left Blinking Eye
                                  AnimatedBuilder(
                                    animation: _blinkController,
                                    builder: (context, child) {
                                      final scaleY =
                                          1.0 - (_blinkController.value * 0.9);
                                      return Transform.scale(
                                        scaleY: scaleY,
                                        child: Container(
                                          width: context.r.scale(14),
                                          height: context.r.scale(14),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF2D1B2E)
                                                .withValues(alpha: 0.7),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const RSizedBox(w: 20),
                                  // Right Blinking Eye
                                  AnimatedBuilder(
                                    animation: _blinkController,
                                    builder: (context, child) {
                                      final scaleY =
                                          1.0 - (_blinkController.value * 0.9);
                                      return Transform.scale(
                                        scaleY: scaleY,
                                        child: Container(
                                          width: context.r.scale(14),
                                          height: context.r.scale(14),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF2D1B2E)
                                                .withValues(alpha: 0.7),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const RSizedBox(h: 16),
                              // Animated Talking Mouth
                              AnimatedBuilder(
                                animation: _talkController,
                                builder: (context, child) {
                                  final talkValue = _talkController.value;
                                  // Mouth opens and closes smoothly
                                  final mouthHeight = 4.0 + (talkValue * 6.0);
                                  final mouthWidth = 22.0 - (talkValue * 4.0);

                                  return Container(
                                    width: mouthWidth,
                                    height: mouthHeight,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D1B2E)
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: const Radius.circular(12),
                                        bottomRight: const Radius.circular(12),
                                        topLeft: Radius.circular(
                                            4 + (talkValue * 4)),
                                        topRight: Radius.circular(
                                            4 + (talkValue * 4)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildContactButton(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Semantics(
      label: title,
      button: true,
      child: Builder(
        builder: (context) => Padding(
           padding: EdgeInsets.only(bottom: context.r.scale(12)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(context.r.scale(8)),
              child: Row(
                children: [
                  Container(
              width: context.r.scale(40),
              height: context.r.scale(40),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB2EE).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(context.r.scale(10)),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFFFFB2EE),
                      size: context.r.scale(20),
                    ),
                  ),
                  const RSizedBox(w: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: context.r.sp(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const RSizedBox(h: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: context.r.sp(12),
                            color: AppColors.textTertiary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                     const RSizedBox(w: 8),
                  Icon(
                    Icons.arrow_outward,
                    color: Colors.grey[600],
                    size: context.r.scale(16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// NEW RESUME BUTTON - Full width, gradient, download icon
  Widget _buildNewResumeButton() {
    return Semantics(
      label: 'Dev resume',
      button: true,
      child: GestureDetector(
        onTap: () {
          _showResumeOptions();
        },
        child: Container(
          width: double.infinity,
        padding: context.r.symmetric(v: 14, h: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(context.r.scale(12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB2EE).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download,
              color: Colors.white,
              size: context.r.scale(20),
            ),
            const RSizedBox(w: 6),
            Text(
              'Dev Resume',
              style: TextStyle(
                fontSize: context.r.sp(15),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Developer Profile Picture with 360° Rotating Rainbow Glow
  Widget _buildProfilePictureWithRainbowGlow() {
    return AnimatedBuilder(
      animation: _rainbowController,
      builder: (context, child) {
        final rotation = _rainbowController.value * 2 * 3.14159;

        return Container(
          width: context.r.scale(120),
          height: context.r.scale(120),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: 0,
              endAngle: 2 * 3.14159,
              transform: GradientRotation(rotation),
              colors: const [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.indigo,
                Colors.purple,
                Colors.pink,
                Colors.red,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Padding(
            padding: context.r.all(4),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Padding(
                padding: context.r.all(3),
                child: ClipOval(
                  child: _buildProfileImage(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Try to load profile image with fallback (JPG first, then PNG, then icon)
  Widget _buildProfileImage() {
    // Try JPG first
    return Image.asset(
      'assets/images/profile_pic/shourav_pic.jpg',
      fit: BoxFit.cover,
      width: context.r.scale(106),
      height: context.r.scale(106),
      errorBuilder: (context, error, stackTrace) {
        // If JPG fails, try PNG
        return Image.asset(
          'assets/images/profile_pic/shourav_pic.png',
          fit: BoxFit.cover,
                                  width: context.r.scale(106),
                                  height: context.r.scale(106),
          errorBuilder: (context, error, stackTrace) {
            // If both fail, show fallback icon
            return Container(
              width: context.r.scale(106),
              height: context.r.scale(106),
              color: const Color(0xFFFFB2EE).withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: context.r.scale(50),
                color: const Color(0xFFFFB2EE),
              ),
            );
          },
        );
      },
    );
  }

  void _showResumeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: context.r.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                width: context.r.scale(40),
                height: context.r.scale(4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(context.r.scale(2)),
                  ),
                ),
                const RSizedBox(h: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download,
                      color: Colors.white,
                      size: context.r.scale(18),
                    ),
                    const RSizedBox(w: 4),
                    Text(
                      'Download Dev. Resume',
                      style: TextStyle(
                        fontSize: context.r.sp(15),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const RSizedBox(h: 8),
                Text(
                  'Sourav Kumar - Flutter Developer',
                  style: TextStyle(
                    fontSize: context.r.sp(14),
                    color: Colors.grey[600],
                  ),
                ),
                const RSizedBox(h: 24),
                // Preview Option
                _buildOptionButton(
                  Icons.visibility,
                  'Preview Resume',
                  'View in app before downloading',
                  () {
                    Navigator.pop(context);
                    _previewResume();
                  },
                ),
                const RSizedBox(h: 12),
                // Download Option
                _buildOptionButton(
                  Icons.download,
                  'Download PDF',
                  'Save to device storage',
                  () {
                    Navigator.pop(context);
                    _downloadResume();
                  },
                  isPrimary: true,
                ),
                const RSizedBox(h: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: context.r.all(16),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFFFFB2EE).withValues(alpha: 0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(context.r.scale(12)),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFFFB2EE).withValues(alpha: 0.3)
                : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: context.r.scale(48),
              height: context.r.scale(48),
              decoration: BoxDecoration(
                color: isPrimary
                    ? const Color(0xFFFFB2EE)
                    : const Color(0xFFFFB2EE).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(context.r.scale(12)),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : const Color(0xFFFFB2EE),
                size: context.r.scale(24),
              ),
            ),
            const RSizedBox(w: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                    fontSize: context.r.sp(16),
                    fontWeight: FontWeight.w600,
                      color: isPrimary
                          ? const Color(0xFFFF69B4)
                          : const Color(0xFF230F1F),
                    ),
                  ),
                  const RSizedBox(h: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.r.sp(13),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: context.r.scale(16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.r.scale(12)),
      child: Row(
        children: [
            Container(
              width: context.r.scale(40),
              height: context.r.scale(40),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB2EE).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(context.r.scale(10)),
            ),
            child: const Icon(
              Icons.check,
              color: Color(0xFFFFB2EE),
            ),
          ),
          const RSizedBox(w: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: context.r.sp(14),
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

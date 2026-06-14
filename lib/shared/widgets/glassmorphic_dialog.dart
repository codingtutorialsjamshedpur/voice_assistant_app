import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/top_panel_controller.dart';
import '../theme/responsive.dart';
import '../theme/responsive_widgets.dart';

/// Glassmorphic Dialog Widget with Dynamic Color Cycling
///
/// A flexible dialog widget that follows the glasmorphic UI design pattern
/// with dynamic color cycling similar to dual input panel.
/// Used for notifications, confirmations, alerts, and success messages.
class GlassmorphicDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final List<GlassmorphicDialogAction> actions;
  final DialogType type;
  final double blur;
  final Color? backgroundColor;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final Widget? customContent;
  final bool dismissible;
  final bool dynamicColor;

  const GlassmorphicDialog({
    super.key,
    required this.title,
    required this.message,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions = const [],
    this.type = DialogType.info,
    this.blur = 12.0,
    this.backgroundColor,
    this.opacity = 0.25,
    this.padding,
    this.width,
    this.customContent,
    this.dismissible = false,
    this.dynamicColor = true,
  });

  @override
  State<GlassmorphicDialog> createState() => _GlassmorphicDialogState();
}

class _GlassmorphicDialogState extends State<GlassmorphicDialog> {
  late TopPanelController _topPanelController;
  bool _hasController = false;

  @override
  void initState() {
    super.initState();
    if (widget.dynamicColor) {
      try {
        _topPanelController = Get.find<TopPanelController>();
        _hasController = true;
      } catch (_) {
        // TopPanelController not registered, fall back to static mode
        _hasController = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultIconData = _getDefaultIcon(widget.type);
    final defaultIconColor = _getDefaultIconColor(widget.type);
    final defaultBgColor = _getDefaultBackgroundColor(widget.type);

    if (widget.dynamicColor && _hasController) {
      return _buildDynamicDialog(
        defaultIconData,
        defaultIconColor,
        defaultBgColor,
      );
    } else {
      return _buildStaticDialog(
        defaultIconData,
        defaultIconColor,
        defaultBgColor,
      );
    }
  }

  Widget _buildDynamicDialog(
    IconData defaultIconData,
    Color defaultIconColor,
    Color defaultBgColor,
  ) {
    final r = context.r;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.scale(24), vertical: r.scale(24)),
      child: GestureDetector(
        onTap: widget.dismissible ? () => Get.back() : null,
        child: PopScope(
          canPop: widget.dismissible,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Container(
              width: widget.width ?? double.infinity,
              constraints: BoxConstraints(
                maxWidth: r.isTablet ? 600 : r.wp(92),
                minHeight: r.scale(200),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.scale(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r.scale(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: widget.blur, sigmaY: widget.blur),
                  child: Obx(() {
                    final dynamicColor = _topPanelController.currentColor;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      padding: widget.padding ??
                          EdgeInsets.symmetric(
                            horizontal: r.scale(32),
                            vertical: r.scale(32),
                          ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withAlpha(51),
                            Colors.white.withAlpha(26),
                            dynamicColor.withAlpha(26),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(r.scale(24)),
                        border: Border.all(
                          color: dynamicColor.withAlpha(102),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: dynamicColor.withAlpha(51),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withAlpha(51),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: widget.customContent ??
                          _buildDefaultContent(
                            widget.icon ?? defaultIconData,
                            widget.iconColor ?? dynamicColor,
                            dynamicColor,
                          ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticDialog(
    IconData defaultIconData,
    Color defaultIconColor,
    Color defaultBgColor,
  ) {
    final r = context.r;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.scale(24), vertical: r.scale(24)),
      child: GestureDetector(
        onTap: widget.dismissible ? () => Get.back() : null,
        child: PopScope(
          canPop: widget.dismissible,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Container(
              width: widget.width ?? double.infinity,
              constraints: BoxConstraints(
                maxWidth: r.isTablet ? 600 : r.wp(92),
                minHeight: r.scale(200),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.scale(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r.scale(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: widget.blur, sigmaY: widget.blur),
                  child: Container(
                    padding: widget.padding ??
                        EdgeInsets.symmetric(
                          horizontal: r.scale(32),
                          vertical: r.scale(32),
                        ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (widget.backgroundColor ?? defaultBgColor)
                              .withAlpha((255 * widget.opacity).toInt()),
                          (widget.backgroundColor ?? defaultBgColor).withAlpha(
                              (255 * (widget.opacity * 0.8)).toInt()),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(r.scale(24)),
                      border: Border.all(
                        color: Colors.white.withAlpha(77),
                        width: 1.5,
                      ),
                    ),
                    child: widget.customContent ??
                        _buildDefaultContent(
                          widget.icon ?? defaultIconData,
                          widget.iconColor ?? defaultIconColor,
                          null,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(
    IconData icon,
    Color iconColor,
    Color? dynamicColor,
  ) {
    final r = context.r;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: r.scale(80),
          height: r.scale(80),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                iconColor.withAlpha(230),
                iconColor.withAlpha(180),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withAlpha(128),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              if (dynamicColor != null)
                BoxShadow(
                  color: dynamicColor.withAlpha(77),
                  blurRadius: 20,
                  spreadRadius: 8,
                ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: r.scale(40),
            ),
          ),
        ),
        RSizedBox(h: 24),

        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.sp(22),
            fontWeight: FontWeight.w700,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),

        RSizedBox(h: 12),

        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.sp(15),
            fontWeight: FontWeight.w400,
            color: Colors.white.withAlpha(230),
            decoration: TextDecoration.none,
            height: 1.5,
          ),
        ),

        if (widget.subtitle != null) ...[
          RSizedBox(h: 8),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.sp(13),
              fontWeight: FontWeight.w300,
              color: Colors.white.withAlpha(204),
              decoration: TextDecoration.none,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        RSizedBox(h: 32),

        if (widget.actions.isNotEmpty) ...[
          if (widget.actions.length == 1)
            _buildSingleActionButton(widget.actions[0], dynamicColor)
          else if (widget.actions.length == 2)
            _buildTwoActionButtons(
              widget.actions[0],
              widget.actions[1],
              dynamicColor,
            )
          else
            _buildMultipleActionButtons(widget.actions, dynamicColor),
        ],
      ],
    );
  }

  Widget _buildSingleActionButton(
    GlassmorphicDialogAction action,
    Color? dynamicColor,
  ) {
    return SizedBox(
      width: double.infinity,
      height: context.r.buttonHeight,
      child: _buildActionButton(action, dynamicColor),
    );
  }

  Widget _buildTwoActionButtons(
    GlassmorphicDialogAction primary,
    GlassmorphicDialogAction secondary,
    Color? dynamicColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(secondary, dynamicColor),
        ),
        RSizedBox(w: 12),
        Expanded(
          child: _buildActionButton(primary, dynamicColor),
        ),
      ],
    );
  }

  Widget _buildMultipleActionButtons(
    List<GlassmorphicDialogAction> actions,
    Color? dynamicColor,
  ) {
    return Column(
      children: List.generate(
        actions.length,
        (index) => Padding(
          padding: EdgeInsets.only(
            top: index > 0 ? context.r.scale(12) : 0,
          ),
          child: _buildActionButton(actions[index], dynamicColor),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    GlassmorphicDialogAction action,
    Color? dynamicColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          action.onPressed?.call();
          Get.back();
        },
        borderRadius: BorderRadius.circular(context.r.scale(14)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.r.scale(14)),
            gradient: action.gradient ??
                (action.isPrimary
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (dynamicColor ?? const Color(0xFFFFB2EE))
                              .withAlpha(230),
                          (dynamicColor ?? const Color(0xFFFF69B4))
                              .withAlpha(180),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withAlpha(77),
                          Colors.white.withAlpha(38),
                        ],
                      )),
            boxShadow: action.isPrimary && dynamicColor != null
                ? [
                    BoxShadow(
                      color: dynamicColor.withAlpha(102),
                      blurRadius: 15,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              action.label,
              style: TextStyle(
                fontSize: context.r.sp(16),
                fontWeight: FontWeight.w600,
                color: action.isPrimary
                    ? Colors.white
                    : Colors.white.withAlpha(230),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getDefaultIcon(DialogType type) {
    return switch (type) {
      DialogType.success => Icons.check_circle_outline,
      DialogType.error => Icons.error_outline,
      DialogType.warning => Icons.warning_amber_rounded,
      DialogType.delete => Icons.delete_outline,
      DialogType.info => Icons.info_outline,
    };
  }

  Color _getDefaultIconColor(DialogType type) {
    return switch (type) {
      DialogType.success => const Color(0xFF4CAF50),
      DialogType.error => const Color(0xFFE91E63),
      DialogType.warning => const Color(0xFFFFC107),
      DialogType.delete => const Color(0xFFE91E63),
      DialogType.info => const Color(0xFF00BCD4),
    };
  }

  Color _getDefaultBackgroundColor(DialogType type) {
    return switch (type) {
      DialogType.success => const Color(0xFF1B5E20),
      DialogType.error => const Color(0xFF880E4F),
      DialogType.warning => const Color(0xFF6D4C41),
      DialogType.delete => const Color(0xFF880E4F),
      DialogType.info => const Color(0xFF0D47A1),
    };
  }
}

/// Dialog action button configuration
class GlassmorphicDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final LinearGradient? gradient;

  GlassmorphicDialogAction({
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.gradient,
  });
}

/// Dialog type enumeration
enum DialogType {
  success,
  error,
  warning,
  delete,
  info,
}

/// Helper class for showing dialogs with dynamic colors
class GlassmorphicDialogHelper {
  /// Show a success dialog with dynamic colors
  static Future<void> showSuccess({
    required String title,
    required String message,
    String? subtitle,
    VoidCallback? onConfirm,
    String confirmLabel = 'OK',
    bool dismissible = true,
    bool dynamicColor = true,
  }) async {
    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        type: DialogType.success,
        dismissible: dismissible,
        dynamicColor: dynamicColor,
        actions: [
          GlassmorphicDialogAction(
            label: confirmLabel,
            onPressed: onConfirm,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  /// Show an error dialog with dynamic colors
  static Future<void> showError({
    required String title,
    required String message,
    String? subtitle,
    VoidCallback? onConfirm,
    String confirmLabel = 'OK',
    bool dismissible = true,
    bool dynamicColor = true,
  }) async {
    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        type: DialogType.error,
        dismissible: dismissible,
        dynamicColor: dynamicColor,
        actions: [
          GlassmorphicDialogAction(
            label: confirmLabel,
            onPressed: onConfirm,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  /// Show a warning dialog with dynamic colors
  static Future<void> showWarning({
    required String title,
    required String message,
    String? subtitle,
    VoidCallback? onConfirm,
    String confirmLabel = 'OK',
    bool dismissible = true,
    bool dynamicColor = true,
  }) async {
    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        type: DialogType.warning,
        dismissible: dismissible,
        dynamicColor: dynamicColor,
        actions: [
          GlassmorphicDialogAction(
            label: confirmLabel,
            onPressed: onConfirm,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  /// Show a confirmation dialog with Yes/No options and dynamic colors
  static Future<bool?> showConfirmation({
    required String title,
    required String message,
    String? subtitle,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String confirmLabel = 'Yes',
    String cancelLabel = 'No',
    bool isPrimaryConfirm = true,
    bool dynamicColor = true,
  }) async {
    bool? result;

    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        type: DialogType.info,
        dismissible: true,
        dynamicColor: dynamicColor,
        actions: [
          GlassmorphicDialogAction(
            label: cancelLabel,
            onPressed: () {
              result = false;
              onCancel?.call();
            },
            isPrimary: !isPrimaryConfirm,
          ),
          GlassmorphicDialogAction(
            label: confirmLabel,
            onPressed: () {
              result = true;
              onConfirm?.call();
            },
            isPrimary: isPrimaryConfirm,
          ),
        ],
      ),
    );

    return result;
  }

  /// Show a delete confirmation dialog with dynamic colors
  static Future<bool?> showDeleteConfirmation({
    required String title,
    required String message,
    String? subtitle,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool dynamicColor = true,
  }) async {
    bool? result;

    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        type: DialogType.delete,
        dismissible: true,
        dynamicColor: dynamicColor,
        actions: [
          GlassmorphicDialogAction(
            label: cancelLabel,
            onPressed: () {
              result = false;
              onCancel?.call();
            },
            isPrimary: false,
          ),
          GlassmorphicDialogAction(
            label: confirmLabel,
            onPressed: () {
              result = true;
              onConfirm?.call();
            },
            isPrimary: true,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE91E63),
                Color(0xFFC2185B),
              ],
            ),
          ),
        ],
      ),
    );

    return result;
  }

  /// Show an info dialog with dynamic colors
  static Future<void> showInfo({
    required String title,
    required String message,
    String? subtitle,
    VoidCallback? onConfirm,
    String confirmLabel = 'OK',
    bool dismissible = true,
    bool dynamicColor = true,
  }) async {
    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        type: DialogType.info,
        dismissible: dismissible,
        dynamicColor: dynamicColor,
        actions: [
          GlassmorphicDialogAction(
            label: confirmLabel,
            onPressed: onConfirm,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  // ─── CTJ Team: All-Models-Failed Notification ──────────────────────────
  /// Shows a formal, premium notification when every AI model in the pool
  /// has failed (typically because API keys have expired).
  ///
  /// The dialog:
  /// • Explains the outage in professional English
  /// • Credits the CTJ development team
  /// • Provides a "Update App" button that opens the Google Play Store listing
  /// • Has a "Dismiss" secondary button for users who want to close it
  ///
  /// [playStoreUrl] defaults to the generic CTJ app search; pass the exact
  /// package URL once the app is live on the Play Store.
  static Future<void> showAllModelsFailedDialog({
    String playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.ctj.voiceassistant',
  }) async {
    // Guard: don't stack duplicate dialogs
    if (Get.isDialogOpen ?? false) return;

    await Get.dialog(
      barrierDismissible: false,
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A1A00),
                  Color(0xFF1A1000),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFA726).withAlpha(130),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA726).withAlpha(60),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 50,
                  spreadRadius: 8,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Builder(
                  builder: (context) {
                    final r = Responsive.of(context);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: r.scale(76),
                          height: r.scale(76),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFFCC02),
                                Color(0xFFFF8F00),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFA726).withAlpha(140),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.system_update_alt_rounded,
                              color: Colors.white,
                              size: r.scale(38),
                            ),
                          ),
                        ),
                        RSizedBox(h: 22),

                        Text(
                          'Service Temporarily Unavailable',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.sp(20),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                            letterSpacing: 0.2,
                          ),
                        ),
                        RSizedBox(h: 14),

                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFFA726).withAlpha(180),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        RSizedBox(h: 16),

                        Text(
                          'We sincerely apologise for the inconvenience.\n\n'
                          'Our AI Voice Chat service is currently experiencing '
                          'an outage due to expired API credentials.\n\n'
                          'The CTJ development team has been notified and is '
                          'working diligently to restore full service at the '
                          'earliest possible time.\n\n'
                          'A corrected version containing updated API keys has '
                          'been — or will shortly be — published to the '
                          'Google Play Store.\n\n'
                          'Please update your CTJ Voice Chat app to resume '
                          'normal service. Thank you for your patience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.sp(13),
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withAlpha(220),
                            decoration: TextDecoration.none,
                            height: 1.6,
                          ),
                        ),
                        RSizedBox(h: 8),

                        Container(
                          margin: EdgeInsets.symmetric(vertical: r.scale(10)),
                          padding: EdgeInsets.symmetric(
                              horizontal: r.scale(14), vertical: r.scale(6)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA726).withAlpha(28),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFFFFA726).withAlpha(80),
                            ),
                          ),
                          child: Text(
                            '— CTJ Development Team',
                            style: TextStyle(
                              fontSize: r.sp(12),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFCC80),
                              decoration: TextDecoration.none,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),

                        RSizedBox(h: 20),

                        SizedBox(
                          width: double.infinity,
                          height: r.buttonHeight,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(r.scale(16)),
                              onTap: () async {
                                Get.back();
                                final uri = Uri.parse(playStoreUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(r.scale(16)),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFBF00),
                                      Color(0xFFFF8F00),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFA726).withAlpha(120),
                                      blurRadius: 18,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.system_update_rounded,
                                      color: Colors.white,
                                      size: r.scale(20),
                                    ),
                                    RSizedBox(w: 10),
                                    Text(
                                      'Update App on Play Store',
                                      style: TextStyle(
                                        fontSize: r.sp(15),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        RSizedBox(h: 10),

                        SizedBox(
                          width: double.infinity,
                          height: r.scale(46),
                          child: TextButton(
                            onPressed: () => Get.back(),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.scale(14)),
                                side: BorderSide(
                                  color: Colors.white.withAlpha(40),
                                ),
                              ),
                            ),
                            child: Text(
                              'Dismiss',
                              style: TextStyle(
                                fontSize: r.sp(14),
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(160),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show a custom dialog with dynamic colors
  static Future<void> showCustom({
    required String title,
    required String message,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    required List<GlassmorphicDialogAction> actions,
    DialogType type = DialogType.info,
    double blur = 12.0,
    Color? backgroundColor,
    double opacity = 0.25,
    EdgeInsetsGeometry? padding,
    double? width,
    Widget? customContent,
    bool dismissible = true,
    bool dynamicColor = true,
  }) async {
    await Get.dialog(
      GlassmorphicDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        actions: actions,
        type: type,
        blur: blur,
        backgroundColor: backgroundColor,
        opacity: opacity,
        padding: padding,
        width: width,
        customContent: customContent,
        dismissible: dismissible,
        dynamicColor: dynamicColor,
      ),
    );
  }
}

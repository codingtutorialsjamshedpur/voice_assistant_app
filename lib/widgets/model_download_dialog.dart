import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/language_controller.dart';
import '../models/language_model.dart';

/// Dialog shown while downloading a TTS voice model
class ModelDownloadDialog extends StatelessWidget {
  final LanguageModel language;

  const ModelDownloadDialog({super.key, required this.language});

  /// Show the download dialog for a specific language
  static void show(LanguageModel lang) {
    Get.dialog(
      ModelDownloadDialog(language: lang),
      barrierDismissible: false,
    );
    // Trigger the download via controller
    Get.find<LanguageController>().confirmDownload();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<LanguageController>();
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Obx(() {
      final downloading = ctrl.isDownloading.value;
      final progress = ctrl.downloadProgress.value;
      final statusMsg = ctrl.downloadStatusMessage.value;
      final isDone = !downloading && progress >= 1.0;

      return PopScope(
        canPop: !downloading,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Flag ──────────────────────────────────────────────────
                Text(language.flag, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),

                // ── Language name ─────────────────────────────────────────
                Text(
                  '${language.nativeName} · ${language.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                // ── Voice name ────────────────────────────────────────────
                if (language.voices.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      language.voices.first.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Progress indicator ────────────────────────────────────
                if (downloading || isDone) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 5,
                          color: isDone ? Colors.green : accent,
                          backgroundColor: accent.withAlpha(30),
                        ),
                      ),
                      if (isDone)
                        const Icon(Icons.check, color: Colors.green, size: 32)
                      else
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status message
                  Text(
                    statusMsg,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDone ? Colors.green : null,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),
                ],

                // ── Action buttons ────────────────────────────────────────
                if (isDone) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Speaking'),
                    onPressed: () => Get.back(),
                  ),
                ] else if (downloading) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.hintColor,
                    ),
                    onPressed: () {
                      ctrl.cancelDownload();
                      Get.back();
                    },
                  ),
                ] else ...[
                  // Not downloading yet — show start button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: ctrl.confirmDownload,
                    child: Text('Download ${language.name} Voice'
                        '${language.voices.isNotEmpty ? ' (${language.voices.first.sizeMB}MB)' : ''}'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      ctrl.cancelDownload();
                      Get.back();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

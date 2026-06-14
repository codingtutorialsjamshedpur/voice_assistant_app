import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../services/stt_service.dart';
import '../../../services/tts_service.dart';

class GardenPortalScreen extends StatefulWidget {
  final String url;
  final String title;

  const GardenPortalScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<GardenPortalScreen> createState() => _GardenPortalScreenState();
}

class _GardenPortalScreenState extends State<GardenPortalScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _isFullscreen = false;
  Widget? _fullscreenWidget;
  Timer? _popupSweeper;

  // File-extension patterns we never want the WebView to navigate to
  // (these are the typical "download" links that trigger the popup).
  static final RegExp _downloadExtRegex = RegExp(
    r'\.(apk|exe|msi|dmg|iso|bin|zip|rar|7z|tar|gz|bz2|xz|'
    r'pdf|doc|docx|xls|xlsx|ppt|pptx|csv|epub|'
    r'mp3|wav|m4a|aac|ogg|flac|wma|'
    r'mp4|avi|mkv|mov|wmv|webm|flv|3gp|m4v|ts|m3u8|mpd|'
    r'torrent)(\?.*)?(#.*)?$',
    caseSensitive: false,
  );

  // Heuristics for download URLs / ad redirects that throw the popup.
  static final RegExp _downloadHostRegex = RegExp(
    r'(/download|/dl/|/get/|cdn-download|/file/|forcedownload|'
    r'attachment|content-disposition)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Allow all orientations while this screen is alive (video can rotate).
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // ---- Build platform-specific creation params (needed so Android can
    // expose AndroidWebViewController APIs like fullscreen callbacks). -----
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/121.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            _injectGuardScripts();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🌐 WebView error: ${error.description}');
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    // ---- Android-only hardening ------------------------------------------
    if (_controller.platform is AndroidWebViewController) {
      final AndroidWebViewController android =
          _controller.platform as AndroidWebViewController;

      // Auto-play HTML5 video without requiring a user gesture.
      android.setMediaPlaybackRequiresUserGesture(false);

      // HTML5 video fullscreen callbacks – required for Fix 2 & 3.
      android.setCustomWidgetCallbacks(
        onShowCustomWidget: _onShowCustomWidget,
        onHideCustomWidget: _onHideCustomWidget,
      );

      // Fix 1: Refuse every file-chooser / upload prompt that the
      // download popup uses to launch a save dialog.
      android.setOnShowFileSelector(
        (FileSelectorParams _) async => <String>[],
      );

      // Grant only the permissions a TV/radio portal actually needs
      // (audio capture stays denied – nothing to record here).
      android.setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) {
          final bool audioOnly = request.types.length == 1 &&
              request.types.first == WebViewPermissionResourceType.microphone;
          if (audioOnly) {
            request.deny();
          } else {
            request.grant();
          }
        },
      );
    }

    // Re-run the popup sweeper periodically as an extra safety net
    // (ad scripts sometimes inject the popup *after* page-finished).
    _popupSweeper = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _sweepDownloadPopup(),
    );
  }

  @override
  void dispose() {
    _popupSweeper?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // Restore the rest of the app to portrait + normal system UI.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // ── Audio-session cleanup ──────────────────────────────────────────────
    try {
      final tts = Get.find<TTSService>();
      if (tts.isSpeaking.value) {
        tts.stop();
        debugPrint('🔇 [GardenPortalScreen] TTS stopped on dispose');
      }
    } catch (_) {}

    // ── SYNCHRONOUS stale flag ────────────────────────────────────────────
    try {
      final stt = Get.find<STTService>();
      stt.markAudioSessionStale();
    } catch (_) {}

    super.dispose();
  }

  // --------------------------------------------------------------------
  // Fix 1 – Block downloads & "The file is ready to download" popup.
  // --------------------------------------------------------------------
  FutureOr<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) {
    final String url = request.url;
    final Uri? uri = Uri.tryParse(url);

    // Refuse non-http(s) intent links – those are usually external
    // browser/download launchers fired by ad scripts.
    if (uri != null &&
        uri.scheme.isNotEmpty &&
        uri.scheme != 'http' &&
        uri.scheme != 'https' &&
        uri.scheme != 'about' &&
        uri.scheme != 'data' &&
        uri.scheme != 'blob') {
      debugPrint('🚫 Blocked non-http scheme: $url');
      return NavigationDecision.prevent;
    }

    if (_downloadExtRegex.hasMatch(url) || _downloadHostRegex.hasMatch(url)) {
      debugPrint('🚫 Blocked download URL: $url');
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _injectGuardScripts() async {
    // CSS: add real top padding so the website never paints under the
    // status bar (Fix 4) – uses both env() and a hard 28px fallback.
    // JS: neuter window.open / download anchors and remove the
    // recurring "The file is ready to download" popup (Fix 1).
    const String js = r"""
      (function () {
        try {
          if (!document.getElementById('flutter-safe-area-style')) {
            var s = document.createElement('style');
            s.id = 'flutter-safe-area-style';
            s.innerHTML =
              'html, body {' +
              '  padding-top: max(env(safe-area-inset-top, 0px), 0px) !important;' +
              '  box-sizing: border-box !important;' +
              '}' +
              /* Hide chat-style download popups when present */
              '[class*="download"][class*="popup"], ' +
              '[id*="download"][id*="popup"], ' +
              '[class*="downloadDialog"], [id*="downloadDialog"] {' +
              '  display: none !important; visibility: hidden !important;' +
              '}';
            document.head.appendChild(s);
          }

          // Kill every popup window – ads commonly use window.open.
          window.open = function () { return null; };

          // Block clicks on <a download> and direct media links.
          var blockClick = function (e) {
            var el = e.target;
            while (el && el.tagName !== 'A') el = el.parentElement;
            if (!el) return;
            var href = (el.getAttribute('href') || '').toLowerCase();
            var hasDl = el.hasAttribute('download');
            var bad = /\.(apk|exe|zip|rar|7z|mp4|mp3|m3u8|pdf|iso|dmg|torrent)(\?|#|$)/i;
            if (hasDl || bad.test(href)) {
              e.preventDefault();
              e.stopPropagation();
            }
          };
          document.addEventListener('click', blockClick, true);
          document.addEventListener('touchend', blockClick, true);

          // Sweep popups that contain the typical wording.
          window.__flutterSweepDownloadPopup = function () {
            try {
              var probe =
                'file is ready to download|tap here to proceed|click here to download';
              var rx = new RegExp(probe, 'i');
              var nodes = document.querySelectorAll(
                'div, section, aside, dialog, ion-alert, .modal, .popup'
              );
              nodes.forEach(function (n) {
                if (!n || !n.innerText) return;
                if (n.children && n.children.length > 16) return;
                if (rx.test(n.innerText)) {
                  n.style.display = 'none';
                  try { n.remove(); } catch (_) {}
                }
              });
              // Always strip the page-level overlay scrim used by ads.
              document
                .querySelectorAll('body > div[style*="position: fixed"]')
                .forEach(function (n) {
                  var t = (n.innerText || '').toLowerCase();
                  if (rx.test(t)) {
                    n.style.display = 'none';
                    try { n.remove(); } catch (_) {}
                  }
                });
            } catch (_) {}
          };
          window.__flutterSweepDownloadPopup();
        } catch (_) {}
      })();
    """;

    try {
      await _controller.runJavaScript(js);
    } catch (e) {
      debugPrint('inject guard scripts failed: $e');
    }
  }

  Future<void> _sweepDownloadPopup() async {
    if (!mounted) return;
    try {
      await _controller.runJavaScript(
        'window.__flutterSweepDownloadPopup && window.__flutterSweepDownloadPopup();',
      );
    } catch (_) {
      // Page may not be ready yet; ignore.
    }
  }

  // --------------------------------------------------------------------
  // Fix 2 & 3 – HTML5 video fullscreen on Android.
  // --------------------------------------------------------------------
  void _onShowCustomWidget(Widget widget, void Function() onHidden) {
    if (!mounted) return;
    setState(() {
      _isFullscreen = true;
      _fullscreenWidget = widget;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _onHideCustomWidget() {
    if (!mounted) return;
    setState(() {
      _isFullscreen = false;
      _fullscreenWidget = null;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreenFromFlutter() async {
    // Ask the page to leave HTML5 fullscreen – this triggers
    // onHideCustomWidget on Android.
    try {
      await _controller.runJavaScript(
        '(function(){try{document.exitFullscreen && document.exitFullscreen();}catch(_){}})();',
      );
    } catch (_) {}
    // Defensive fallback in case the website never calls exitFullscreen.
    _onHideCustomWidget();
  }

  // --------------------------------------------------------------------
  // Back-button handling (Fix 2 / Additional Checks).
  // --------------------------------------------------------------------
  //
  // ROOT-CAUSE FIX for the STT-broken-after-Radio/TV bug:
  //
  // The WebView holds Android audio focus (AUDIOFOCUS_GAIN) as long as there
  // is a live HTML5 <audio>/<video> element.  Flutter's dispose() is called
  // AFTER the pop animation completes, but the platform WebView is torn down
  // asynchronously — it can keep the audio focus for 1–3 s.  Any STT reinit
  // called during that window fails silently (Android rejects the
  // AudioRecord open).  Result: mic appears working but produces no text.
  //
  // Solution: BEFORE we pop the screen, force the page to:
  //   1. Pause every <audio> and <video> element.
  //   2. Navigate to about:blank — kills the network stream immediately.
  // Then wait 1 s for Android's AudioManager to re-grant focus to the
  // SpeechRecognizer.  Only then do we pop.  By the time dispose() fires
  // the audio session is already clean and the reinit calls succeed.
  Future<bool> _handleBack() async {
    if (_isFullscreen) {
      await _exitFullscreenFromFlutter();
      return false;
    }
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }

    // ── Stop all media BEFORE popping ────────────────────────────────────
    debugPrint('⏹ [GardenPortalScreen] Stopping media before back-navigation');
    try {
      // Pause every <audio> and <video> element on the page.
      await _controller.runJavaScript(
        'try{'
        '  document.querySelectorAll("audio,video").forEach(function(m){'
        '    m.pause(); m.currentTime=0; m.src=""; m.load();'
        '  });'
        '}catch(_){}',
      );
    } catch (_) {}

    try {
      // Navigate to blank — releases all network connections + audio tracks.
      await _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}

    // Give Android AudioManager ≈1 s to hand the audio focus back to the
    // system so SpeechRecognizer can acquire it on the next init call.
    await Future.delayed(const Duration(milliseconds: 1000));
    debugPrint('✅ [GardenPortalScreen] Media stopped — safe to pop');

    return true; // tell caller to do Get.back()
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final bool shouldPop = await _handleBack();
        if (shouldPop && mounted) {
          Get.back<dynamic>();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isFullscreen && _fullscreenWidget != null
            ? _buildFullscreenLayer()
            : _buildPortalLayer(),
      ),
    );
  }

  // True 16:9 fullscreen layer (Fix 3). No AppBar, no SafeArea, no
  // channel list, just the video Android handed us.
  Widget _buildFullscreenLayer() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: Colors.black),
        Positioned.fill(child: _fullscreenWidget!),
      ],
    );
  }

  // Normal portal layer – respects the status bar (Fix 4).
  Widget _buildPortalLayer() {
    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFB2EE),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GestureDetector(
                onTap: () async {
                  final bool shouldPop = await _handleBack();
                  if (shouldPop && mounted) {
                    Get.back<dynamic>();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

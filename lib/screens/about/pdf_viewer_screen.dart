import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import '../../shared/widgets/shared_widgets.dart';

class PDFViewerScreen extends StatefulWidget {
  final String? pdfPath;
  final String? title;

  const PDFViewerScreen({
    super.key,
    this.pdfPath,
    this.title = 'Resume Preview',
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? localPath;
  bool isLoading = true;
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPDF();
  }

  Future<void> _loadPDF() async {
    try {
      if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty) {
        // Use provided path
        if (File(widget.pdfPath!).existsSync()) {
          setState(() {
            localPath = widget.pdfPath;
            isLoading = false;
          });
          return;
        }
      }

      // Copy from assets to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/RESUME.pdf');

      // Check if already copied
      if (await tempFile.exists()) {
        setState(() {
          localPath = tempFile.path;
          isLoading = false;
        });
        return;
      }

      // Copy from assets
      final byteData = await rootBundle.load('assets/RESUME.pdf');
      final buffer = byteData.buffer;
      await tempFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      setState(() {
        localPath = tempFile.path;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading PDF: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF230F1F)),
            onPressed: () => Get.back(),
          ),
          title: Text(
            widget.title ?? 'Resume Preview',
            style: const TextStyle(
              color: Color(0xFF230F1F),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          actions: [
            if (localPath != null)
              IconButton(
                icon: const Icon(Icons.share, color: Color(0xFF230F1F)),
                onPressed: () {
                  _sharePDF();
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            if (isLoading)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFFB2EE)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading resume...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else if (errorMessage.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadPDF,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB2EE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (localPath != null)
              PDFView(
                filePath: localPath!,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onRender: (pages) {
                  setState(() {
                    this.pages = pages;
                    isReady = true;
                  });
                },
                onError: (error) {
                  setState(() {
                    errorMessage = error.toString();
                  });
                },
                onPageError: (page, error) {
                  setState(() {
                    errorMessage = 'Error on page $page: $error';
                  });
                },
                onViewCreated: (PDFViewController pdfViewController) {},
                onLinkHandler: (String? uri) {
                  if (uri != null) {
                    // Handle link clicks if needed
                  }
                },
                onPageChanged: (int? page, int? total) {
                  setState(() {
                    currentPage = page;
                  });
                },
              )
            else
              const Center(
                child: Text(
                  'No PDF file available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            if (isReady && pages != null && pages! > 0)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Page ${currentPage != null ? currentPage! + 1 : 1} of $pages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _sharePDF() {
    // Implement share functionality if needed
    Get.snackbar(
      'Share',
      'Share functionality can be implemented here',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFFB2EE),
      colorText: Colors.white,
    );
  }
}

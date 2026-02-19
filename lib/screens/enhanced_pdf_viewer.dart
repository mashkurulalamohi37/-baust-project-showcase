import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:projectshowcase/utils/pdf_downloader/pdf_downloader.dart';

class EnhancedPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String projectTitle;

  const EnhancedPdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.projectTitle,
  });

  @override
  State<EnhancedPdfViewerScreen> createState() => _EnhancedPdfViewerScreenState();
}

class _EnhancedPdfViewerScreenState extends State<EnhancedPdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController.addListener(_updatePageInfo);
  }

  @override
  void dispose() {
    _pdfViewerController.removeListener(_updatePageInfo);
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _updatePageInfo() {
    setState(() {
      _currentPage = _pdfViewerController.pageNumber;
      _zoomLevel = _pdfViewerController.zoomLevel;
    });
  }

  Future<void> _downloadPdf() async {
    setState(() => _isLoading = true);
    await PdfDownloader.downloadPdf(context, widget.pdfUrl, widget.projectTitle);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printPdf() async {
    try {
      setState(() => _isLoading = true);

      // Download PDF bytes
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load PDF for printing');
      }

      // Print using printing package
      await Printing.layoutPdf(
        onLayout: (pw_pdf.PdfPageFormat format) async => response.bodyBytes,
        name: widget.projectTitle,
      );
    } catch (e) {
      debugPrint('Error printing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPageJumpDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to Page'),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Page number (1-$_totalPages)',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final pageNum = int.tryParse(textController.text);
              if (pageNum != null && pageNum >= 1 && pageNum <= _totalPages) {
                _pdfViewerController.jumpToPage(pageNum);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid page number (1-$_totalPages)')),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E), // Dark background matching viewer theme
        foregroundColor: Colors.white, // White text/icons for visibility
        title: Text(
          '${widget.projectTitle} (v2)', // Added v2 to verify deployment update
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Download button
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: _isLoading ? null : _downloadPdf,
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print PDF',
            onPressed: _isLoading ? null : _printPdf,
          ),
          // Share/Open in browser button
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in Browser',
            onPressed: () async {
              try {
                if (await canLaunchUrl(Uri.parse(widget.pdfUrl))) {
                  await launchUrl(
                    Uri.parse(widget.pdfUrl),
                    mode: LaunchMode.externalApplication,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer
          // PDF Viewer
          kIsWeb
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'PDF Viewing on Web',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For best experience, please open the PDF in a new tab.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open PDF in New Tab'),
                        onPressed: () async {
                           if (await canLaunchUrl(Uri.parse(widget.pdfUrl))) {
                            await launchUrl(
                              Uri.parse(widget.pdfUrl),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                )
              : SfPdfViewer.network(
                  widget.pdfUrl,
                  controller: _pdfViewerController,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  enableDoubleTapZooming: true,
                  enableTextSelection: true,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    setState(() {
                      _totalPages = details.document.pages.count;
                    });
                  },
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    debugPrint('PDF Load Error: ${details.error}');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to load PDF: ${details.error}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                ),

          // Bottom Control Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Navigation
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        tooltip: 'Previous Page',
                        onPressed: _currentPage > 1
                            ? () => _pdfViewerController.previousPage()
                            : null,
                      ),
                      GestureDetector(
                        onTap: _totalPages > 0 ? _showPageJumpDialog : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _totalPages > 0 ? '$_currentPage / $_totalPages' : 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        tooltip: 'Next Page',
                        onPressed: _currentPage < _totalPages
                            ? () => _pdfViewerController.nextPage()
                            : null,
                      ),
                    ],
                  ),

                  // Zoom Controls
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.zoom_out, color: Colors.white),
                        tooltip: 'Zoom Out',
                        onPressed: () {
                          final newZoom = (_zoomLevel - 0.25).clamp(0.5, 3.0);
                          _pdfViewerController.zoomLevel = newZoom;
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${(_zoomLevel * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in, color: Colors.white),
                        tooltip: 'Zoom In',
                        onPressed: () {
                          final newZoom = (_zoomLevel + 0.25).clamp(0.5, 3.0);
                          _pdfViewerController.zoomLevel = newZoom;
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.fit_screen, color: Colors.white),
                        tooltip: 'Fit to Width',
                        onPressed: () => _pdfViewerController.zoomLevel = 1.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

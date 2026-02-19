import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Utility class for extracting text from PDF documents
class PdfContentExtractor {
  /// Download and extract text from a PDF at the given URL
  /// 
  /// [pdfUrl] - The URL of the PDF file
  /// Returns the extracted text content
  static Future<String> extractFromUrl(String pdfUrl) async {
    try {
      // Download PDF
      final response = await http.get(Uri.parse(pdfUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF: HTTP ${response.statusCode}');
      }
      
      // Extract text from bytes
      return await extractFromBytes(response.bodyBytes);
    } catch (e) {
      throw Exception('Failed to extract text from PDF URL: ${e.toString()}');
    }
  }
  
  /// Extract text from PDF bytes
  /// 
  /// [bytes] - The PDF file as bytes
  /// Returns the extracted text content
  static Future<String> extractFromBytes(Uint8List bytes) async {
    try {
      // Load PDF document
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Extract text from all pages
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      
      // Dispose document
      document.dispose();
      
      if (text.trim().isEmpty) {
        throw Exception('No text could be extracted from the PDF. The document might be image-based.');
      }
      
      return text;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: ${e.toString()}');
    }
  }
  
  /// Check if a PDF has extractable text (not just images)
  static Future<bool> hasExtractableText(String pdfUrl) async {
    try {
      final text = await extractFromUrl(pdfUrl);
      return text.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

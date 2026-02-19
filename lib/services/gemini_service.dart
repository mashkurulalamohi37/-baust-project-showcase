import 'package:google_generative_ai/google_generative_ai.dart';

/// Service for interacting with Google's Gemini AI
/// 
/// IMPORTANT: Before using, set your API key in the constructor below.
/// Get your free API key from: https://aistudio.google.com/app/apikey
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  
  late final GenerativeModel _model;
  
  // TODO: REPLACE WITH YOUR ACTUAL API KEY
  // Get your free API key from: https://aistudio.google.com/app/apikey
  static const String _apiKey = 'AIzaSyBHLISLrOb1xLcrlyCksZ-xoLDyZrzD2Eg';
  
  GeminiService._internal() {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception(
        'Gemini API Key not configured!\n'
        'Please get your free API key from https://aistudio.google.com/app/apikey\n'
        'and update the _apiKey constant in lib/services/gemini_service.dart'
      );
    }
    
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
    );
  }
  
  /// Chat with a project using its PDF content as context
  /// 
  /// [pdfContent] - The full extracted text from the project PDF
  /// [userQuestion] - The question the user wants to ask
  /// Returns the AI's answer based on the PDF content
  Future<String> chatWithProject({
    required String pdfContent,
    required String userQuestion,
  }) async {
    try {
      final prompt = '''
You are an intelligent assistant helping users understand academic project documentation.

Below is the full content of a project paper/documentation:

---
$pdfContent
---

User Question: $userQuestion

Based ONLY on the content above, provide a clear and concise answer. If the information is not found in the document, say so. Do not make up information.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'I could not generate a response. Please try again.';
    } catch (e) {
      throw Exception('Failed to get response from Gemini: ${e.toString()}');
    }
  }
  
  /// Stream-based chat for real-time responses
  Stream<String> chatWithProjectStream({
    required String pdfContent,
    required String userQuestion,
  }) async* {
    try {
      final prompt = '''
You are an intelligent assistant helping users understand academic project documentation.

Below is the full content of a project paper/documentation:

---
$pdfContent
---

User Question: $userQuestion

Based ONLY on the content above, provide a clear and concise answer. If the information is not found in the document, say so. Do not make up information.
''';

      final content = [Content.text(prompt)];
      final response = _model.generateContentStream(content);
      
      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null) {
          yield text;
        }
      }
    } catch (e) {
      yield 'Error: ${e.toString()}';
    }
  }
}

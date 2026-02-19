/// Utility class for extracting transcripts from YouTube videos (Web Stub)
class YoutubeTranscriptExtractor {
  /// Extract transcript/captions from a YouTube video URL
  static Future<String> extractFromUrl(String youtubeUrl) async {
    // Return a friendly message instead of throwing immediately, 
    // though the UI might handle throwing better.
    // The IO impl throws Exception if failed.
    // For web, let's return a message that will be part of the context.
    return "Note: Video transcript analysis is currently available only on mobile devices.";
  }
  
  /// Check if a video has available captions
  static Future<bool> hasTranscript(String youtubeUrl) async {
    return false;
  }
}

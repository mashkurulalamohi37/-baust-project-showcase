import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Utility class for extracting transcripts from YouTube videos
class YoutubeTranscriptExtractor {
  /// Extract transcript/captions from a YouTube video URL
  /// 
  /// [youtubeUrl] - The full YouTube URL or video ID
  /// Returns the extracted transcript text
  static Future<String> extractFromUrl(String youtubeUrl) async {
    try {
      final yt = YoutubeExplode();
      
      // Extract video ID from URL
      String? videoId = _extractVideoId(youtubeUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }
      
      try {
        // Get closed captions/transcript
        final manifest = await yt.videos.closedCaptions.getManifest(videoId);
        
        if (manifest.tracks.isEmpty) {
          throw Exception('No captions available for this video');
        }
        
        // Get English captions first, or any available language
        var track = manifest.tracks.firstWhere(
          (t) => t.language.code == 'en',
          orElse: () => manifest.tracks.first,
        );
        
        // Get the actual caption content
        final captions = await yt.videos.closedCaptions.get(track);
        
        // Combine all caption text
        final transcript = captions.captions
            .map((caption) => caption.text)
            .join(' ');
        
        yt.close();
        
        if (transcript.trim().isEmpty) {
          throw Exception('Transcript is empty');
        }
        
        return transcript;
      } catch (e) {
        yt.close();
        throw Exception('Failed to fetch captions: ${e.toString()}');
      }
    } catch (e) {
      throw Exception('Failed to extract YouTube transcript: ${e.toString()}');
    }
  }
  
  /// Check if a video has available captions
  static Future<bool> hasTranscript(String youtubeUrl) async {
    try {
      final yt = YoutubeExplode();
      String? videoId = _extractVideoId(youtubeUrl);
      if (videoId == null) return false;
      
      final manifest = await yt.videos.closedCaptions.getManifest(videoId);
      yt.close();
      return manifest.tracks.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Extract video ID from various YouTube URL formats
  static String? _extractVideoId(String url) {
    // Handle direct video ID
    if (!url.contains('http') && url.length == 11) {
      return url;
    }
    
    // Handle various YouTube URL formats
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    
    return null;
  }
}

import 'package:flutter/material.dart';

import 'youtube_web_mobile.dart' if (dart.library.html) 'youtube_web_web.dart';

Widget buildWebYoutubePlayer(String videoId) {
  return WebYoutubePlayerImpl(videoId: videoId);
}

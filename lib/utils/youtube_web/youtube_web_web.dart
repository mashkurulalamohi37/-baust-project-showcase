import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class WebYoutubePlayerImpl extends StatelessWidget {
  final String videoId;

  const WebYoutubePlayerImpl({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final String viewId = 'youtube-player-$videoId';
    
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1&origin=${Uri.base.origin}'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;
        return iframe;
      },
    );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: viewId),
    );
  }
}

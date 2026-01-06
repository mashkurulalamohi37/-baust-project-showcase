import 'package:flutter/material.dart';

class WebYoutubePlayerImpl extends StatelessWidget {
  final String videoId;

  const WebYoutubePlayerImpl({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Web Player not available on Mobile'));
  }
}

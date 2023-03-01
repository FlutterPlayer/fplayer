import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fplayer/fplayer.dart';

import 'app_bar.dart';
// import 'custom_ui.dart';

class VideoScreen extends StatefulWidget {
  final String url;

  const VideoScreen({super.key, required this.url});

  @override
  VideoScreenState createState() => VideoScreenState();
}

class VideoScreenState extends State<VideoScreen> {
  final FPlayer player = FPlayer();

  VideoScreenState();

  @override
  void initState() {
    super.initState();
    player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    player.setOption(FOption.playerCategory, "mediacodec-all-videos", 1);
    startPlay();
  }

  void startPlay() async {
    await player.setOption(FOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FOption.hostCategory, "request-audio-focus", 1);
    await player.setDataSource(widget.url, autoPlay: true).catchError((e) {
      if (kDebugMode) {
        print("setDataSource error: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FAppBar.defaultSetting(title: "Video"),
      body: Center(
        child: FView(
          player: player,
          panelBuilder: fPanel2Builder(snapShot: true),
          fsFit: FFit.fill,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    player.release();
  }
}

import 'package:flutter/material.dart';
import 'package:fplayer/fplayer.dart';

import 'app_bar.dart';
// import 'custom_ui.dart';

class VideoScreen extends StatefulWidget {
  final String url;

  VideoScreen({required this.url});

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final FPlayer player = FPlayer();

  _VideoScreenState();

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
      print("setDataSource error: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FijkAppBar.defaultSetting(title: "Video"),
      body: Container(
        child: Center(
          child: FView(
            player: player,
            panelBuilder: fPanel2Builder(snapShot: true),
            fsFit: FFit.fill,
            // panelBuilder: simplestUI,
            // panelBuilder: (FijkPlayer player, BuildContext context,
            //     Size viewSize, Rect texturePos) {
            //   return CustomFijkPanel(
            //       player: player,
            //       buildContext: context,
            //       viewSize: viewSize,
            //       texturePos: texturePos);
            // },
          ),
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

# fplayer (Video player plugin for Flutter) Flutter 媒体播放器


A Flutter media player plugin for iOS and android based on [fijkplayer](https://github.com/befovy/fijkplayer)

您的支持是我们开发的动力。 欢迎Star，欢迎PR~。
[Feedback welcome](https://github.com/FlutterPlayer/fplayer/issues) and
[Pull Requests](https://github.com/FlutterPlayer/fplayer/pulls) are most welcome!

## Documentation 文档(本插件文档正在开发中,请先参考fijkplayer文档)

* Development Documentation https://fijkplayer.befovy.com/docs/en/ quick start、guide、and concepts about fijkplayer 
* 开发文档  https://fijkplayer.befovy.com/docs/zh/ 包含快速开始、使用指南、fijkplayer 中的概念理解

## Installation 安装

Add `fplayer` as a [dependency in your pubspec.yaml file](https://flutter.io/using-packages/). 

[![pub package](https://img.shields.io/pub/v/fplayer.svg)](https://pub.dartlang.org/packages/fplayer)

```yaml
dependencies:
  fplayer: ^{{latest version}}
```

Replace `{{latest version}}` with the version number in badge above.

Use git branch which not published to pub.
```yaml
dependencies:
  fplayer:
    git:
      url: https://github.com/FlutterPlayer/fplayer.git
      ref: develop # can be replaced to branch or tag name
```

## Example 示例

```dart
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

```

## iOS Warning 警告

Warning: The fplayer video player plugin is not functional on iOS simulators. An iOS device must be used during development/testing. For more details, please refer to this [issue](https://github.com/flutter/flutter/issues/14647).

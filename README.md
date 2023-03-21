# fplayer (Video player plugin for Flutter) Flutter 媒体播放器


A Flutter media player plugin for iOS and android based on [fplayer-core](https://github.com/FlutterPlayer/ijkplayer)

您的支持是我们开发的动力。 欢迎Star，欢迎PR~。
[Feedback welcome](https://github.com/FlutterPlayer/fplayer/issues) and
[Pull Requests](https://github.com/FlutterPlayer/fplayer/pulls) are most welcome!

## Documentation 文档

* 开发文档  https://fplayer.dev/ 包含首页、入门指南、基础、内核、fplayer 中的概念理解

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

class VideoScreen extends StatefulWidget {
  final String url;

  const VideoScreen({super.key, required this.url});

  @override
  VideoScreenState createState() => VideoScreenState();
}

class VideoScreenState extends State<VideoScreen> {
  final FPlayer player = FPlayer();

  List<VideoItem> videoList = [
    VideoItem(
      title: '第一集',
      subTitle: '视频1副标题',
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    ),
    VideoItem(
      title: '第二集',
      subTitle: '视频2副标题',
      url: 'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    ),
    VideoItem(
      title: '第三集',
      subTitle: '视频3副标题',
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    ),
    VideoItem(
      title: '第四集',
      subTitle: '视频4副标题',
      url: 'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    ),
    VideoItem(
      title: '第五集',
      subTitle: '视频5副标题',
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    ),
    VideoItem(
      title: '第六集',
      subTitle: '视频6副标题',
      url: 'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    ),
    VideoItem(
      title: '第七集',
      subTitle: '视频7副标题',
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    )
  ];

  int videoIndex = 0;

  VideoScreenState();

  @override
  void initState() {
    super.initState();
    player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    player.setOption(FOption.playerCategory, "mediacodec-all-videos", 1);
    startPlay();
  }

  void startPlay() async {
    await player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    await player.setOption(FOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FOption.hostCategory, "request-audio-focus", 1);
    await player.setOption(FOption.playerCategory, "reconnect", 20);
    await player.setOption(FOption.playerCategory, "framedrop", 20);
    await player.setOption(FOption.playerCategory, "enable-accurate-seek", 1);
    await player.setOption(FOption.playerCategory, "mediacodec", 1);
    await player.setOption(FOption.playerCategory, "packet-buffering", 0);
    await player.setOption(FOption.playerCategory, "soundtouch", 1);
    await player.setDataSource(widget.url, autoPlay: true).catchError((e) {
      if (kDebugMode) {
        print("setDataSource error: $e");
      }
    });
  }

  Future<void> setVideoUrl(String url) async {
    try {
      await player.setDataSource(url, autoPlay: true, showCover: true);
    } catch (error) {
      print("播放-异常: $error");
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    Size size = mediaQueryData.size;
    double videoHeight = size.width * 9 / 16;
    return Scaffold(
      appBar: const FAppBar.defaultSetting(title: "Video"),
      body: Column(
        children: [
          FView(
            player: player,
            width: double.infinity,
            height: videoHeight,
            color: Colors.black,
            fsFit: FFit.contain, // 全屏模式下的填充
            fit: FFit.fill, // 正常模式下的填充
            panelBuilder: fPanel2Builder(
              // 单视频配置
              title: '视频标题',
              subTitle: '视频副标题',
              // 右下方截屏按钮
              snapShot: true,
              // 右上方按钮组
              rightButton: true,
              rightButtonList: [
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColorLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColorLight,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(5),
                      ),
                    ),
                    child: Icon(
                      Icons.thumb_up,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                )
              ],
              caption: true,
              // 视频列表配置
              // videos: true,
              // videoMap: videoList,
              // videoIndex: videoIndex,
              // playNextVideoFun: () {
              //   setState(() {
              //     videoIndex += 1;
              //   });
              // },
              settingFun: () {
                print('设置按钮点击事件');
              },
              captionFun: () {
                print('字幕按钮点击事件');
              },
              resolution: true,
              resolutionFun: () {
                print('清晰度按钮点击事件');
              },
            ),
          ),
          // 自定义小屏列表
          // Container(
          //   width: double.infinity,
          //   height: 30,
          //   margin: const EdgeInsets.all(20),
          //   child: ListView.builder(
          //     scrollDirection: Axis.horizontal,
          //     padding: EdgeInsets.zero,
          //     itemCount: videoList.length,
          //     itemBuilder: (context, index) {
          //       bool isCurrent = videoIndex == index;
          //       Color textColor = Theme.of(context).primaryColor;
          //       Color bgColor = Theme.of(context).primaryColorDark;
          //       Color borderColor = Theme.of(context).primaryColor;
          //       if (isCurrent) {
          //         textColor = Theme.of(context).primaryColorDark;
          //         bgColor = Theme.of(context).primaryColor;
          //         borderColor = Theme.of(context).primaryColor;
          //       }
          //       return GestureDetector(
          //         onTap: () async {
          //           await player.reset();
          //           setState(() {
          //             videoIndex = index;
          //           });
          //           setVideoUrl(videoList[index].url);
          //         },
          //         child: Container(
          //           margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
          //           padding: const EdgeInsets.symmetric(horizontal: 5),
          //           decoration: BoxDecoration(
          //             borderRadius: BorderRadius.circular(5),
          //             color: bgColor,
          //             border: Border.all(
          //               width: 1.5,
          //               color: borderColor,
          //             ),
          //           ),
          //           alignment: Alignment.center,
          //           child: Text(
          //             videoList[index].title,
          //             style: TextStyle(
          //               fontSize: 15,
          //               color: textColor,
          //             ),
          //           ),
          //         ),
          //       );
          //     },
          //   ),
          // ),
        ],
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

## 鸣谢以下项目
* [fijkplayer](https://github.com/befovy/fijkplayer)
* [ijkplayer](https://github.com/bilibili/ijkplayer)
* [ffmpeg](https://github.com/FFmpeg/FFmpeg)

## iOS Warning 警告

Warning: The fplayer video player plugin is not functional on iOS simulators. An iOS device must be used during development/testing. For more details, please refer to this [issue](https://github.com/flutter/flutter/issues/14647).

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
import 'package:screen_brightness/screen_brightness.dart';

import 'app_bar.dart';

class VideoScreen extends StatefulWidget {
  final String url;

  const VideoScreen({super.key, required this.url});

  @override
  VideoScreenState createState() => VideoScreenState();
}

class VideoScreenState extends State<VideoScreen> {
  final FPlayer player = FPlayer();

  // 视频列表
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
  ];

  // 倍速列表
  Map<String, double> speedList = {
    "2.0": 2.0,
    "1.5": 1.5,
    "1.0": 1.0,
    "0.5": 0.5,
  };

  // 清晰度列表
  Map<String, ResolutionItem> resolutionList = {
    "480P": ResolutionItem(
      value: 480,
      url: 'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    ),
    "270P": ResolutionItem(
      value: 270,
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    ),
  };

  // 视频索引,单个视频可不传
  int videoIndex = 0;

  // 模拟播放记录视频初始化完需要跳转的进度
  int seekTime = 100000;

  VideoScreenState();

  @override
  void initState() {
    super.initState();
    startPlay();
  }

  void startPlay() async {
    // 视频播放相关配置
    await player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    await player.setOption(FOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FOption.hostCategory, "request-audio-focus", 1);
    await player.setOption(FOption.playerCategory, "reconnect", 20);
    await player.setOption(FOption.playerCategory, "framedrop", 20);
    await player.setOption(FOption.playerCategory, "enable-accurate-seek", 1);
    await player.setOption(FOption.playerCategory, "mediacodec", 1);
    await player.setOption(FOption.playerCategory, "packet-buffering", 0);
    await player.setOption(FOption.playerCategory, "soundtouch", 1);

    // 播放传入的视频
    setVideoUrl(widget.url);

    // 播放视频列表的第一个视频
    // setVideoUrl(videoList[videoIndex].url);
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
            panelBuilder: fPanelBuilder(
              // 单视频配置
              title: '视频标题',
              subTitle: '视频副标题',
              // 右下方截屏按钮
              isSnapShot: true,
              // 右上方按钮组开关
              isRightButton: true,
              // 右上方按钮组
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
              // 字幕功能：待内核提供api
              // caption: true,
              // 视频列表开关
              isVideos: true,
              // 视频列表列表
              videoList: videoList,
              // 当前视频索引
              videoIndex: videoIndex,
              // 全屏模式下点击播放下一集视频按钮
              playNextVideoFun: () {
                setState(() {
                  videoIndex += 1;
                });
              },
              settingFun: () {
                print('设置按钮点击事件');
              },
              // 自定义倍速列表
              speedList: speedList,
              // 清晰度开关
              isResolution: true,
              // 自定义清晰度列表
              resolutionList: resolutionList,
              // 视频播放错误点击刷新回调
              onError: () async {
                await player.reset();
                setVideoUrl(videoList[videoIndex].url);
              },
              // 视频播放完成回调
              onVideoEnd: () async {
                var index = videoIndex + 1;
                if (index < videoList.length) {
                  await player.reset();
                  setState(() {
                    videoIndex = index;
                  });
                  setVideoUrl(videoList[index].url);
                }
              },
              onVideoTimeChange: () {
                // 视频时间变动则触发一次，可以保存视频播放历史
              },
              onVideoPrepared: () async {
                // 视频初始化完毕，如有历史记录时间段则可以触发快进
                try {
                  if (seekTime >= 1) {
                    /// seekTo必须在FState.prepared
                    print('seekTo');
                    await player.seekTo(seekTime);
                    // print("视频快进-$seekTime");
                    seekTime = 0;
                  }
                } catch (error) {
                  print("视频初始化完快进-异常: $error");
                }
              },
            ),
          ),
          // 自定义小屏列表
          Container(
            width: double.infinity,
            height: 30,
            margin: const EdgeInsets.all(20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: videoList.length,
              itemBuilder: (context, index) {
                bool isCurrent = videoIndex == index;
                Color textColor = Theme.of(context).primaryColor;
                Color bgColor = Theme.of(context).primaryColorDark;
                Color borderColor = Theme.of(context).primaryColor;
                if (isCurrent) {
                  textColor = Theme.of(context).primaryColorDark;
                  bgColor = Theme.of(context).primaryColor;
                  borderColor = Theme.of(context).primaryColor;
                }
                return GestureDetector(
                  onTap: () async {
                    await player.reset();
                    setState(() {
                      videoIndex = index;
                    });
                    setVideoUrl(videoList[index].url);
                  },
                  child: Container(
                    margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: bgColor,
                      border: Border.all(
                        width: 1.5,
                        color: borderColor,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      videoList[index].title,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() async {
    super.dispose();
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      print(e);
      throw 'Failed to reset brightness';
    }
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

<span><small>感谢您的关注！开源不易，需要开发者们的不断努力和付出。如果您觉得我的项目对您有所帮助，希望能够支持我继续改进和维护这个项目，您可以考虑打赏我一杯咖啡的钱。
您的支持将是我继续前进的动力，让我能够更加专注地投入到开源社区中，让我的项目变得更加完善和有用。如果您决定打赏我，可以通过以下方式：</small></span>
<ul>
    <li>给该项目点赞 &nbsp;<a style="vertical-align: text-bottom;" href="https://github.com/FlutterPlayer/fplayer">
      <img src="https://img.shields.io/github/stars/FlutterPlayer/fplayer.svg?label=Stars&style=social" alt="给该项目点赞" />
    </a></li>
    <li>关注我的 Github &nbsp;<a style="vertical-align: text-bottom;"  href="https://github.com/FlutterPlayer">
      <img src="https://img.shields.io/github/followers/FlutterPlayer.svg?label=Follow&style=social" alt="关注我的 Github" />
    </a></li>
</ul>
<table>
    <thead><tr>
        <th>微信</th>
        <th>支付宝</th>
    </tr></thead>
    <tbody><tr>
        <td><img style="max-width: 150px" src="/images/wx.png" alt="微信" /></td>
        <td><img style="max-width: 150px" src="/images/zfb.png" alt="支付宝" /></td>
    </tr></tbody>
</table>
再次感谢您的支持和慷慨，让我们一起为开源社区贡献一份力量！
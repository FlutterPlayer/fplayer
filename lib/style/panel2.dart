part of fplayer;

FPanelWidgetBuilder fPanelBuilder({
  Key? key,
  final bool fill = false,

  /// 是否展示视频列表
  final bool isVideos = false,

  /// 视频列表
  final List<VideoItem>? videoList,
  final int videoIndex = 0,

  /// 全屏点击下一集按钮事件
  final void Function()? playNextVideoFun,

  /// 视频标题
  final String title = '',

  /// 视频副标题
  final String subTitle = '',
  final int duration = 5000,
  final bool doubleTap = true,

  /// 中间区域右上方按钮是否展示
  final bool isRightButton = false,

  /// 中间区域右上方按钮Widget集合
  final List<Widget>? rightButtonList,

  /// 截屏按钮是否展示
  final bool isSnapShot = false,

  /// 字幕按钮是否展示
  final bool isCaption = false,

  /// 倍速列表,注意这里一定要包含1倍速
  final Map<String, double>? speedList,

  /// 清晰度按钮是否展示
  final bool isResolution = false,

  /// 清晰度列表
  final Map<String, ResolutionItem>? resolutionList,

  /// 设置点击事件
  final void Function()? settingFun,

  /// 视频错误点击刷新
  final void Function()? onError,

  /// 视频结束
  final void Function()? onVideoEnd,

  /// 视频完成后台任务到稳定期
  final void Function()? onVideoPrepared,

  /// 视频时间更新
  final void Function()? onVideoTimeChange,
}) {
  return (FPlayer player, FData data, BuildContext context, Size viewSize,
      Rect texturePos) {
    return _FPanel2(
      key: key,
      player: player,
      data: data,
      isVideos: isVideos,
      title: title,
      subTitle: subTitle,
      videoList: videoList,
      videoIndex: videoIndex,
      playNextVideoFun: playNextVideoFun,
      isRightButton: isRightButton,
      rightButtonList: rightButtonList,
      viewSize: viewSize,
      texPos: texturePos,
      fill: fill,
      doubleTap: doubleTap,
      isSnapShot: isSnapShot,
      hideDuration: duration,
      isCaption: isCaption,
      speedList: speedList,
      isResolution: isResolution,
      resolutionList: resolutionList,
      settingFun: settingFun,
      onError: onError,
      onVideoEnd: onVideoEnd,
      onVideoPrepared: onVideoPrepared,
      onVideoTimeChange: onVideoTimeChange,
    );
  };
}

class VideoItem {
  String url;
  String title;
  String subTitle;
  VideoItem({
    required this.url,
    required this.title,
    required this.subTitle,
  });
}

class ResolutionItem {
  int value;
  String url;
  ResolutionItem({
    required this.value,
    required this.url,
  });
}

class _FPanel2 extends StatefulWidget {
  final FPlayer player;
  final FData data;
  final bool isVideos;
  final String title;
  final String subTitle;
  final List<VideoItem>? videoList;
  final int videoIndex;
  final void Function()? playNextVideoFun;
  final bool isRightButton;
  final List<Widget>? rightButtonList;
  final Size viewSize;
  final Rect texPos;
  final bool fill;
  final bool doubleTap;
  final bool isSnapShot;
  final int hideDuration;
  final bool isCaption;
  final Map<String, double>? speedList;
  final bool isResolution;
  final Map<String, ResolutionItem>? resolutionList;
  final void Function()? settingFun;
  final void Function()? onError;
  final void Function()? onVideoEnd;
  final void Function()? onVideoPrepared;
  final void Function()? onVideoTimeChange;

  const _FPanel2({
    Key? key,
    required this.player,
    required this.data,
    this.fill = false,
    required this.viewSize,
    this.hideDuration = 5000,
    this.doubleTap = false,
    this.isSnapShot = false,
    required this.texPos,
    this.isVideos = false,
    this.title = '',
    this.subTitle = '',
    this.videoList,
    this.rightButtonList,
    this.isRightButton = false,
    this.isCaption = false,
    this.isResolution = false,
    this.settingFun,
    this.videoIndex = 0,
    this.playNextVideoFun,
    this.resolutionList,
    this.speedList,
    this.onError,
    this.onVideoEnd,
    this.onVideoPrepared,
    this.onVideoTimeChange,
  })  : assert(hideDuration > 0 && hideDuration < 10000),
        super(key: key);

  @override
  __FPanel2State createState() => __FPanel2State();
}

class __FPanel2State extends State<_FPanel2> {
  FPlayer get player => widget.player;

  Timer? _hideTimer;
  bool _hideStuff = true;

  bool _prepared = false;
  bool _playing = false;
  bool _dragLeft = false;
  double? _volume;
  double? _brightness;

  double _seekPos = -1.0;
  Duration _duration = const Duration();
  Duration _currentPos = const Duration();
  Duration _bufferPos = const Duration();

  bool lock = false;
  bool hideSpeed = true;
  double speed = 1.0;

  bool hideCaption = true;
  bool caption = false;

  bool hideResolution = true;
  int resolution = 0;

  bool longPress = false;

  /// 视频错误
  bool _isPlayError = false;

  /// 是否播放完成
  bool _isPlayCompleted = false;

  /// 视频状态是否执行完成成为稳定状态与_prepared不一致
  bool _playStatePrepared = false;

  /// 是否在加载中
  bool _buffering = false;
  int _bufferingPro = 0;
  late StreamSubscription _bufferingSubs;

  int sendCount = 0;

  Map<String, double> speedList = {
    "2.0": 2.0,
    "1.5": 1.5,
    "1.0": 1.0,
  };

  Map<String, bool> captionList = {
    "开": true,
    "关": false,
  };

  Map<String, ResolutionItem> resolutionList = {
    "1080P": ResolutionItem(
      value: 1080,
      url: "https://www.runoob.com/try/demo_source/mov_bbb.mp4",
    ),
    "720P": ResolutionItem(
      value: 720,
      url: "http://player.alicdn.com/video/aliyunmedia.mp4",
    ),
    "480P": ResolutionItem(
      value: 480,
      url: "https://www.runoob.com/try/demo_source/mov_bbb.mp4",
    ),
    "360P": ResolutionItem(
      value: 360,
      url: "http://player.alicdn.com/video/aliyunmedia.mp4",
    ),
  };

  StreamSubscription? _currentPosSubs;
  StreamSubscription? _bufferPosSubs;
  late StreamSubscription<int> _bufferPercunt;

  late StreamController<double> _valController;

  // snapshot
  bool screenshot = false;

  // Is it needed to clear seek data in FData (widget.data)
  bool _needClearSeekData = true;

  // StreamSubscription? connectTypeListener;
  // ConnectivityResult? connectivityResult;

  final Battery battery = Battery();

  StreamSubscription? batteryStateListener;
  BatteryState? batteryState;
  int batteryLevel = 0;
  late Timer timer;

  static const FSliderColors sliderColors = FSliderColors(
    cursorColor: Color(0xFF07B9B9),
    playedColor: Color(0xFF07B9B9),
    baselineColor: Color(0xFFD8D8D8),
    bufferedColor: Color(0xFF787878),
  );

  @override
  void initState() {
    super.initState();

    // 初始化resolution
    Map<String, ResolutionItem> obj = widget.resolutionList ?? resolutionList;

    resolution = obj.values.toList().first.value;

    // connectTypeListener = Connectivity()
    //     .onConnectivityChanged
    //     .listen((ConnectivityResult result) {
    //   setState(() {
    //     connectivityResult = result;
    //   });
    // });

    batteryStateListener =
        battery.onBatteryStateChanged.listen((BatteryState state) {
      if (batteryState == state) return;
      setState(() {
        batteryState = state;
      });
    });

    getBatteryLevel();

    Timer.periodic(const Duration(seconds: 5), (timer) {
      getBatteryLevel();
    });

    _valController = StreamController.broadcast();

    var playerState = player.state;
    _prepared = player.value.prepared;
    _duration = player.value.duration;
    _currentPos = player.currentPos;
    _bufferPos = player.bufferPos;
    _buffering = player.isBuffering;
    _playing = playerState == FState.started;
    _isPlayError = playerState == FState.error;
    _isPlayCompleted = playerState == FState.completed;

    /// 当前进度
    _currentPosSubs = player.onCurrentPosUpdate.listen((v) {
      setState(() {
        _currentPos = v;
        if (_buffering == true) {
          _buffering = false; // 避免有可能出现已经播放时还在显示缓冲中
        }
        if (_playing == false) {
          _playing = true; // 避免播放在false时导致bug
        }
      });
      if (_needClearSeekData) {
        widget.data.clearValue(FData._fViewPanelSeekto);
      }
      _needClearSeekData = false;
      // 每n次才进入一次不然太频繁发送处理业务太复杂则会增加消耗
      if (sendCount % 50 == 0) {
        widget.onVideoTimeChange?.call();
      }
      sendCount++;
    });

    if (widget.data.contains(FData._fViewPanelSeekto)) {
      var pos = widget.data.getValue(FData._fViewPanelSeekto) as double;
      _currentPos = Duration(milliseconds: pos.toInt());
    }

    /// 视频加载进度
    _bufferPosSubs = player.onBufferPosUpdate.listen((v) {
      if (_hideStuff == false) {
        setState(() {
          _bufferPos = v;
        });
      } else {
        _bufferPos = v;
      }
    });

    /// 视频卡顿回调
    _bufferingSubs = player.onBufferStateUpdate.listen((value) {
      print("视频加载中$value");
      if (value == false && _playing == false) {
        playOrPause();
      }
      setState(() {
        _buffering = value;
      });
    });

    /// 视频卡顿当缓冲量回调
    _bufferPercunt = player.onBufferPercentUpdate.listen((value) {
      setState(() {
        _bufferingPro = value;
      });
    });

    player.addListener(_playerValueChanged);
  }

  @override
  void dispose() {
    super.dispose();
    _valController.close();
    _hideTimer?.cancel();
    _currentPosSubs?.cancel();
    _bufferPosSubs?.cancel();
    _bufferPercunt.cancel();
    _bufferingSubs.cancel();
    // connectTypeListener?.cancel();
    batteryStateListener?.cancel();
    player.removeListener(_playerValueChanged);
  }

  getBatteryLevel() async {
    final level = await battery.batteryLevel;
    if (mounted) {
      setState(() {
        batteryLevel = level;
      });
    }
  }

  double dura2double(Duration d) {
    return d.inMilliseconds.toDouble();
  }

  void _playerValueChanged() {
    FValue value = player.value;

    if (value.duration != _duration) {
      setState(() {
        _duration = value.duration;
      });
    }

    var valueState = value.state;
    bool playing = valueState == FState.started;
    bool prepared = value.prepared;
    bool isPlayError = valueState == FState.error;
    bool completed = valueState == FState.completed;
    if (isPlayError != _isPlayError ||
        playing != _playing ||
        prepared != _prepared ||
        completed != _isPlayCompleted) {
      setState(() {
        _isPlayError = isPlayError;
        _playing = playing;
        _prepared = prepared;
        _isPlayCompleted = completed;
      });
    }

    /// 视频初始化完毕后回调
    bool playStatePrepared = valueState == FState.prepared;
    if (_playStatePrepared != playStatePrepared) {
      if (playStatePrepared) {
        widget.onVideoPrepared?.call();
      }
      _playStatePrepared = playStatePrepared;
    }

    /// 播放完成是否播放下一集
    bool isPlayCompleted = valueState == FState.completed;
    if (isPlayCompleted) {
      if (widget.isVideos && widget.videoList!.length - 1 > widget.videoIndex) {
        widget.onVideoEnd?.call();
      } else {
        _isPlayCompleted = isPlayCompleted;
      }
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(milliseconds: widget.hideDuration), () {
      setState(() {
        _hideStuff = true;
        hideSpeed = true;
        hideCaption = true;
      });
    });
  }

  void onTapFun() {
    if (_hideStuff == true) {
      _restartHideTimer();
    }
    setState(() {
      _hideStuff = !_hideStuff;
      if (_hideStuff == true) {
        hideSpeed = true;
        hideCaption = true;
      }
    });
  }

  void playOrPause() {
    if (player.isPlayable() || player.state == FState.asyncPreparing) {
      if (player.state == FState.started) {
        player.pause();
      } else {
        player.start();
      }
    } else if (player.state == FState.initialized) {
      player.start();
    } else {
      FLog.w("Invalid state ${player.state} ,can't perform play or pause");
    }
  }

  Future<void> playNextVideo() async {
    await player.reset();
    try {
      await player.setDataSource(
        widget.videoList![widget.videoIndex + 1].url,
        autoPlay: true,
        showCover: true,
      );
      widget.playNextVideoFun?.call();
    } catch (error) {
      print("播放-异常: $error");
      return;
    }
  }

  void onDoubleTapFun() {
    playOrPause();
  }

  void onLongPressFun() {
    player.setSpeed(2.0);
    setState(() {
      longPress = true;
    });
  }

  void onLongPressUpFun() {
    player.setSpeed(speed);
    setState(() {
      longPress = false;
    });
  }

  void onVerticalDragStartFun(DragStartDetails d) {
    // 唤起菜单栏防止误触
    if (d.localPosition.dy > 40 &&
        d.localPosition.dy < widget.viewSize.height - 40) {
      if (d.localPosition.dx > panelWidth() / 2) {
        // right, volume
        _dragLeft = false;
        FVolume.setUIMode(FVolume.neverShowUI);
        FVolume.getVol().then((v) {
          if (!widget.data.contains(FData._fViewPanelVolume)) {
            widget.data.setValue(FData._fViewPanelVolume, v);
          }
          setState(() {
            _volume = v;
            // _valController.add(v);
          });
        });
      } else {
        // left, brightness
        _dragLeft = true;
        FPlugin.screenBrightness().then((v) {
          if (!widget.data.contains(FData._fViewPanelBrightness)) {
            widget.data.setValue(FData._fViewPanelBrightness, v);
          }
          setState(() {
            _brightness = v;
            _valController.add(v);
          });
        });
      }
    }
  }

  void onVerticalDragUpdateFun(DragUpdateDetails d) {
    double delta = d.primaryDelta! / panelHeight();
    delta = -delta.clamp(-1.0, 1.0);
    if (_dragLeft == false) {
      var volume = _volume;
      if (volume != null) {
        volume += delta;
        volume = volume.clamp(0.0, 1.0);
        _volume = volume;
        FVolume.setVol(volume);
        setState(() {
          _valController.add(volume!);
        });
      }
    } else if (_dragLeft == true) {
      var brightness = _brightness;
      if (brightness != null) {
        brightness += delta;
        brightness = brightness.clamp(0.0, 1.0);
        _brightness = brightness;
        FPlugin.setScreenBrightness(brightness);
        setState(() {
          _valController.add(brightness!);
        });
      }
    }
  }

  void onVerticalDragEndFun(DragEndDetails e) {
    FVolume.setUIMode(FVolume.alwaysShowUI);
    _volume = null;
    _brightness = null;
  }

  /// 快进视频时间
  void onVideoTimeChangeUpdate(double value) {
    print('value:$value');
    print('_duration.inMilliseconds:${_duration.inMilliseconds}');
    if (_duration.inMilliseconds < 0 ||
        value < 0 ||
        value > _duration.inMilliseconds) {
      return;
    }
    _restartHideTimer();
    setState(() {
      _seekPos = value;
    });
  }

  /// 快进视频松手开始跳时间
  void onVideoTimeChangeEnd(double value) {
    var time = _seekPos.toInt();
    _currentPos = Duration(milliseconds: time);
    player.seekTo(time).then((value) {
      if (!_playing) {
        player.start();
      }
    });
    setState(() {
      _seekPos = -1;
    });
  }

  /// 获取视频当前时间, 如拖动快进时间则显示快进的时间
  double getCurrentVideoValue() {
    double duration = _duration.inMilliseconds.toDouble();
    double currentValue;
    if (_seekPos > 0) {
      currentValue = _seekPos;
    } else {
      currentValue = _currentPos.inMilliseconds.toDouble();
    }
    currentValue = min(currentValue, duration);
    currentValue = max(currentValue, 0);
    return currentValue;
  }

  // 播放与暂停图标
  Widget buildPlayButton(BuildContext context, double height) {
    Widget icon = (player.state == FState.started)
        ? Icon(Icons.pause_rounded, color: Theme.of(context).primaryColor)
        : Icon(Icons.play_arrow_rounded, color: Theme.of(context).primaryColor);
    bool fullScreen = player.value.fullScreen;
    return IconButton(
      padding: EdgeInsets.zero,
      iconSize: fullScreen ? height : height * 0.8,
      icon: icon,
      onPressed: playOrPause,
    );
  }

  // 下一集图标
  Widget buildPlayNextButton(BuildContext context, double height) {
    bool fullScreen = player.value.fullScreen;
    return IconButton(
      padding: EdgeInsets.zero,
      iconSize: fullScreen ? height : height * 0.8,
      icon: Icon(
        Icons.skip_next_rounded,
        color: Theme.of(context).primaryColor,
      ),
      onPressed: playNextVideo,
    );
  }

  Widget buildOptTextButton(BuildContext context, double height) {
    return Row(
      children: [
        if (widget.isCaption)
          TextButton(
            onPressed: () {
              setState(() {
                if (hideSpeed == false) {
                  hideSpeed = true;
                }
                if (hideResolution == false) {
                  hideResolution = true;
                }
                hideCaption = !hideCaption;
              });
            },
            child: Text(
              '字幕',
              style: TextStyle(
                color: Theme.of(context).primaryColorDark,
              ),
            ),
          ),
        TextButton(
          onPressed: () {
            setState(() {
              if (hideCaption == false) {
                hideCaption = true;
              }
              if (hideResolution == false) {
                hideResolution = true;
              }
              hideSpeed = !hideSpeed;
            });
          },
          child: Text(
            '倍速',
            style: TextStyle(
              color: Theme.of(context).primaryColorDark,
            ),
          ),
        ),
        if (widget.isResolution)
          TextButton(
            onPressed: () {
              if (hideCaption == false) {
                hideCaption = true;
              }
              if (hideSpeed == false) {
                hideSpeed = true;
              }
              hideResolution = !hideResolution;
            },
            child: Text(
              '${resolution}P',
              style: TextStyle(
                color: Theme.of(context).primaryColorDark,
              ),
            ),
          ),
      ],
    );
  }

  // 字幕开关
  List<Widget> buildCaptionListWidget() {
    List<Widget> columnChild = [];
    captionList.forEach((String mapKey, bool captionVals) {
      columnChild.add(
        Ink(
          child: InkWell(
            onTap: () {
              if (caption == captionVals) return;
              setState(() {
                caption = captionVals;
                hideCaption = true;
                // player.setCaption(captionVals);
              });
            },
            child: Container(
              alignment: Alignment.center,
              width: 50,
              height: 30,
              child: Text(
                mapKey,
                style: TextStyle(
                  color: caption == captionVals
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
      columnChild.add(
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 5),
          child: Container(
            width: 50,
            height: 1,
            color: Colors.white54,
          ),
        ),
      );
    });
    columnChild.removeAt(columnChild.length - 1);
    return columnChild;
  }

  // 倍速选择
  List<Widget> buildSpeedListWidget() {
    List<Widget> columnChild = [];
    Map<String, double> obj = widget.speedList ?? speedList;
    obj.forEach((String mapKey, double speedVals) {
      columnChild.add(
        Ink(
          child: InkWell(
            onTap: () {
              if (speed == speedVals) return;
              setState(() {
                speed = speedVals;
                hideSpeed = true;
                player.setSpeed(speedVals);
              });
            },
            child: Container(
              alignment: Alignment.center,
              width: 50,
              height: 30,
              child: Text(
                "${mapKey}X",
                style: TextStyle(
                  color: speed == speedVals
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
      columnChild.add(
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 5),
          child: Container(
            width: 50,
            height: 1,
            color: Colors.white54,
          ),
        ),
      );
    });
    columnChild.removeAt(columnChild.length - 1);
    return columnChild;
  }

  // 清晰度选择
  List<Widget> buildResolutionListWidget() {
    List<Widget> columnChild = [];
    Map<String, ResolutionItem> obj = widget.resolutionList ?? resolutionList;
    obj.forEach((String mapKey, ResolutionItem resolutionItem) {
      columnChild.add(
        Ink(
          child: InkWell(
            onTap: () async {
              if (resolution == resolutionItem.value) return;
              await player.reset();
              try {
                await player.setDataSource(
                  resolutionItem.url,
                  autoPlay: true,
                  showCover: true,
                );
                setState(() {
                  resolution = resolutionItem.value;
                  hideResolution = true;
                });
              } catch (error) {
                print("播放-异常: $error");
                return;
              }
            },
            child: Container(
              alignment: Alignment.center,
              width: 50,
              height: 30,
              child: Text(
                mapKey,
                style: TextStyle(
                  color: resolution == resolutionItem.value
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
      columnChild.add(
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 5),
          child: Container(
            width: 50,
            height: 1,
            color: Colors.white54,
          ),
        ),
      );
    });
    columnChild.removeAt(columnChild.length - 1);
    return columnChild;
  }

  // 全屏与退出全屏图标
  Widget buildFullScreenButton(BuildContext context, double height) {
    Icon icon = player.value.fullScreen
        ? Icon(
            Icons.fullscreen_exit_rounded,
            color: Theme.of(context).primaryColor,
          )
        : Icon(
            Icons.fullscreen_rounded,
            color: Theme.of(context).primaryColor,
          );
    bool fullScreen = player.value.fullScreen;
    return IconButton(
      padding: EdgeInsets.zero,
      iconSize: fullScreen ? height : height * 0.8,
      color: Theme.of(context).primaryColorDark,
      icon: icon,
      onPressed: () {
        player.value.fullScreen
            ? player.exitFullScreen()
            : player.enterFullScreen();
      },
    );
  }

  // 时间进度
  Widget buildTimeText(BuildContext context, double height) {
    String text =
        "${_duration2String(_currentPos)}/${_duration2String(_duration)}";
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).primaryColorDark,
      ),
    );
  }

  // 进度条
  Widget buildSlider(BuildContext context) {
    double duration = dura2double(_duration);

    double currentValue = _seekPos > 0 ? _seekPos : dura2double(_currentPos);
    currentValue = currentValue.clamp(0.0, duration);

    double bufferPos = dura2double(_bufferPos);
    bufferPos = bufferPos.clamp(0.0, duration);

    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: FSlider(
        colors: sliderColors,
        value: currentValue,
        cacheValue: bufferPos,
        min: 0.0,
        max: duration,
        onChanged: (v) {
          _restartHideTimer();
          setState(() {
            _seekPos = v;
          });
        },
        onChangeEnd: (v) {
          setState(() {
            player.seekTo(v.toInt());
            _currentPos = Duration(milliseconds: _seekPos.toInt());
            widget.data.setValue(FData._fViewPanelSeekto, _seekPos);
            _needClearSeekData = true;
            _seekPos = -1.0;
          });
        },
      ),
    );
  }

  // 播放器顶部菜单栏
  Widget buildTop(BuildContext context, double height) {
    if (player.value.fullScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: <Widget>[
                buildBack(context),
                buildTitle(),
                const Spacer(),
                buildTimeNow(),
                buildPower(),
                // buildNetConnect(),
                buildSetting(context),
              ],
            ),
          ),
          buildSubTitle(),
        ],
      );
    } else {
      return Row(
        children: <Widget>[
          buildBack(context),
          Expanded(child: Container()),
          buildSetting(context),
        ],
      );
    }
  }

  // 播放器底部菜单栏
  Widget buildBottom(BuildContext context, double height) {
    if (_duration.inMilliseconds > 0) {
      if (player.value.fullScreen) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Row(
                children: <Widget>[
                  Text(
                    _duration2String(_currentPos),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColorDark,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: buildSlider(context),
                    ),
                  ),
                  Text(
                    _duration2String(_duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColorDark,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  buildPlayButton(context, height),
                  if (widget.isVideos &&
                      widget.videoList!.length - 1 > widget.videoIndex)
                    buildPlayNextButton(context, height),
                  const Spacer(),
                  buildOptTextButton(context, height),
                  buildFullScreenButton(context, height),
                ],
              ),
            ),
          ],
        );
      } else {
        return Row(
          children: <Widget>[
            buildPlayButton(context, height),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 10),
                child: buildSlider(context),
              ),
            ),
            buildTimeText(context, height),
            buildFullScreenButton(context, height),
          ],
        );
      }
    } else {
      return Row(
        children: <Widget>[
          buildPlayButton(context, height),
          Expanded(child: Container()),
          buildFullScreenButton(context, height),
        ],
      );
    }
  }

  void takeSnapshot() {
    player.takeSnapShot().then((v) {
      var provider = MemoryImage(v);
      precacheImage(provider, context).then((_) {
        setState(() {
          screenshot = true;
          Timer.periodic(const Duration(seconds: 2), (timer) {
            screenshot = false;
          });
        });
      });
      FLog.d("get snapshot succeed");
    }).catchError((e) {
      FLog.d("get snapshot failed");
    });
  }

  Widget screenshotMsg() {
    return Offstage(
      offstage: !screenshot,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, .2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Text(
          "截图成功",
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, .8),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget buildPanel(BuildContext context) {
    double height = panelHeight();

    bool fullScreen = player.value.fullScreen;
    Widget leftWidget = Container(
      color: const Color(0x00000000),
    );
    Widget rightWidget = Container(
      color: const Color(0x00000000),
    );

    if (fullScreen) {
      rightWidget = Padding(
        padding: const EdgeInsets.only(left: 10, right: 25, top: 8, bottom: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Visibility(
              visible: widget.isRightButton,
              child: Column(
                children: widget.rightButtonList ?? [],
              ),
            ),
            Visibility(
              visible: widget.isRightButton,
              child: const SizedBox(
                height: 20,
              ),
            ),
            if (widget.isSnapShot &&
                (player.value.videoRenderStart &&
                    player.value.audioRenderStart))
              InkWell(
                onTap: () {
                  takeSnapshot();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColorLight,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(5),
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
      );
      leftWidget = Padding(
        padding: const EdgeInsets.only(left: 25, right: 10, top: 8, bottom: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            InkWell(
              onTap: () {
                setState(() {
                  lock = !lock;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColorLight,
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                ),
                child: Visibility(
                  visible: lock,
                  replacement: Icon(
                    Icons.lock_open,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            )
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!lock)
          Container(
            height: height > 200 ? 80 : height / 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x88000000), Color(0x00000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            alignment: Alignment.topCenter,
            child: Container(
              height: height > 80
                  ? fullScreen
                      ? 80
                      : 45
                  : height / 2,
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 5),
              child: buildTop(context, height > 80 ? 40 : height / 2),
            ),
          ),
        // 中间按钮
        Expanded(
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: leftWidget,
              ),
              // 字幕开关
              Positioned(
                right: 170,
                bottom: 0,
                child: Visibility(
                  visible: !hideCaption,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: buildCaptionListWidget(),
                      ),
                    ),
                  ),
                ),
              ),
              // 倍数选择
              Positioned(
                right: 105,
                bottom: 0,
                child: Visibility(
                  visible: !hideSpeed,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: buildSpeedListWidget(),
                      ),
                    ),
                  ),
                ),
              ),
              // 清晰度选择
              Positioned(
                right: 50,
                bottom: 0,
                child: Visibility(
                  visible: !hideResolution,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: buildResolutionListWidget(),
                      ),
                    ),
                  ),
                ),
              ),
              if (!lock)
                Align(
                  alignment: Alignment.centerRight,
                  child: rightWidget,
                ),
            ],
          ),
        ),
        if (!lock)
          Container(
            height: height > 80 ? 80 : height / 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x88000000), Color(0x00000000)],
                end: Alignment.topCenter,
                begin: Alignment.bottomCenter,
              ),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height > 80
                  ? fullScreen
                      ? 80
                      : 45
                  : height / 2,
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 5),
              child: buildBottom(context, height > 80 ? 40 : height / 2),
            ),
          )
      ],
    );
  }

  Widget buildLongPress() {
    return Offstage(
      offstage: !longPress,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, .2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Text(
          "2倍速播放中",
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, .8),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget buildDragProgressTime() {
    return Offstage(
      offstage: _seekPos == -1,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(0, 0, 0, .5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            "${_duration2String(
              Duration(milliseconds: _seekPos.toInt()),
            )} / ${_duration2String(_duration)}",
            style: TextStyle(
              color: Theme.of(context).primaryColorDark,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector buildGestureDetector(BuildContext context) {
    double currentValue = getCurrentVideoValue();
    Widget videoLoading = Container(); // 视频缓冲
    if (_buffering) {
      videoLoading = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 25,
            height: 25,
            margin: const EdgeInsets.only(bottom: 10),
            child: const CircularProgressIndicator(
              backgroundColor: Color.fromRGBO(250, 250, 250, 0.5),
              valueColor: AlwaysStoppedAnimation(Colors.white70),
            ),
          ),
          Text(
            "缓冲中 $_bufferingPro %",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: onTapFun,
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.doubleTap && !lock ? onDoubleTapFun : null,
      onLongPressUp: _playing && !lock ? onLongPressUpFun : null,
      onLongPress: _playing && !lock ? onLongPressFun : null,
      onVerticalDragUpdate: !lock ? onVerticalDragUpdateFun : null,
      onVerticalDragStart: !lock ? onVerticalDragStartFun : null,
      onVerticalDragEnd: !lock ? onVerticalDragEndFun : null,
      onHorizontalDragStart: (d) =>
          !lock ? onVideoTimeChangeUpdate.call(currentValue) : null,
      onHorizontalDragUpdate: (d) {
        double deltaDx = d.delta.dx;
        if (deltaDx == 0) {
          return; // 避免某些手机会返回0.0
        }
        var dragValue = (deltaDx * 4000) + currentValue;
        !lock ? onVideoTimeChangeUpdate.call(dragValue) : null;
      },
      onHorizontalDragEnd: (d) =>
          !lock ? onVideoTimeChangeEnd.call(currentValue) : null,
      child: Stack(
        children: <Widget>[
          AbsorbPointer(
            absorbing: _hideStuff,
            child: AnimatedOpacity(
              opacity: _hideStuff ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: buildPanel(context),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: buildLongPress(),
          ),
          Align(
            alignment: Alignment.center,
            child: videoLoading,
          ),
          Align(
            alignment: Alignment.center,
            child: screenshotMsg(),
          ),
          Align(
            alignment: Alignment.center,
            child: buildDragProgressTime(),
          ),
        ],
      ),
    );
  }

  Rect panelRect() {
    Rect rect = player.value.fullScreen || (true == widget.fill)
        ? Rect.fromLTWH(0, 0, widget.viewSize.width, widget.viewSize.height)
        : Rect.fromLTRB(
            max(0.0, widget.texPos.left),
            max(0.0, widget.texPos.top),
            min(widget.viewSize.width, widget.texPos.right),
            min(widget.viewSize.height, widget.texPos.bottom));
    return rect;
  }

  double panelHeight() {
    if (player.value.fullScreen || (true == widget.fill)) {
      return widget.viewSize.height;
    } else {
      return min(widget.viewSize.height, widget.texPos.bottom) -
          max(0.0, widget.texPos.top);
    }
  }

  double panelWidth() {
    if (player.value.fullScreen || (true == widget.fill)) {
      return widget.viewSize.width;
    } else {
      return min(widget.viewSize.width, widget.texPos.right) -
          max(0.0, widget.texPos.left);
    }
  }

  // 返回
  Widget buildBack(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.arrow_back_ios_rounded,
        color: Theme.of(context).primaryColor,
      ),
      onPressed: () {
        player.value.fullScreen
            ? player.exitFullScreen()
            : Navigator.of(context).pop();
      },
    );
  }

  Widget buildTitle() {
    return Text(
      widget.isVideos
          ? widget.videoList![widget.videoIndex].title
          : widget.title,
      style: const TextStyle(
        fontSize: 22,
        color: Color(0xFF787878),
      ),
    );
  }

  Widget buildSubTitle() {
    return Container(
      padding: const EdgeInsets.only(left: 55),
      child: Text(
        widget.isVideos
            ? widget.videoList![widget.videoIndex].subTitle
            : widget.subTitle,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF787878),
        ),
      ),
    );
  }

  // 当前时间显示
  Widget buildTimeNow() {
    return Container(
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        '${DateTime.now().hour}:${DateTime.now().minute}',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
        ),
      ),
    );
  }

  // 电量显示
  Widget buildPower() {
    if (batteryState == BatteryState.charging) {
      return Row(
        children: [
          Text(
            '$batteryLevel%',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 10,
            ),
          ),
          Icon(
            Icons.battery_charging_full_rounded,
            color: Theme.of(context).primaryColor,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Text(
            '$batteryLevel%',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 10,
            ),
          ),
          if (batteryLevel < 14)
            Icon(
              Icons.battery_1_bar_rounded,
              color: Theme.of(context).primaryColor,
            )
          else if (batteryLevel < 28)
            Icon(
              Icons.battery_2_bar_rounded,
              color: Theme.of(context).primaryColor,
            )
          else if (batteryLevel < 42)
            Icon(
              Icons.battery_3_bar_rounded,
              color: Theme.of(context).primaryColor,
            )
          else if (batteryLevel < 56)
            Icon(
              Icons.battery_4_bar_rounded,
              color: Theme.of(context).primaryColor,
            )
          else if (batteryLevel < 70)
            Icon(
              Icons.battery_5_bar_rounded,
              color: Theme.of(context).primaryColor,
            )
          else if (batteryLevel < 84)
            Icon(
              Icons.battery_6_bar_rounded,
              color: Theme.of(context).primaryColor,
            )
          else
            Icon(
              Icons.battery_full_rounded,
              color: Theme.of(context).primaryColor,
            )
        ],
      );
    }
  }

  // 5G、WIFI、无网络
  // Widget buildNetConnect() {
  //   return IconButton(
  //     padding: EdgeInsets.zero,
  //     icon: Visibility(
  //       visible: connectivityResult == ConnectivityResult.none,
  //       replacement: Visibility(
  //         visible: connectivityResult == ConnectivityResult.mobile,
  //         replacement: const Text(
  //           'WIFI',
  //           style: TextStyle(color: Color(0xFF07B9B9)),
  //         ),
  //         child: const Text(
  //           '5G',
  //           style: TextStyle(color: Color(0xFF07B9B9)),
  //         ),
  //       ),
  //       child: const Icon(
  //         Icons.signal_cellular_connected_no_internet_4_bar_rounded,
  //         color: Color(0xFF07B9B9),
  //       ),
  //     ),
  //     onPressed: null,
  //   );
  // }

  // 设置
  Widget buildSetting(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      icon: Transform.rotate(
        angle: pi / 2,
        alignment: Alignment.center,
        child: Icon(
          Icons.tune_rounded,
          color: Theme.of(context).primaryColor,
        ),
      ),
      onPressed: widget.settingFun,
    );
  }

  Widget buildStateless() {
    if (player.state == FState.asyncPreparing) {
      return Container(
        alignment: Alignment.center,
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).primaryColorDark,
            ),
          ),
        ),
      );
    } else if (_isPlayError) {
      return Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: 15),
              child: Icon(
                Icons.error_rounded,
                color: Colors.white70,
                size: 70,
              ),
            ),
            RichText(
              text: TextSpan(
                text: "播放异常！",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: "刷新",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        widget.onError?.call();
                      },
                  )
                ],
              ),
            ),
          ],
        ),
      );
    } else if (!player.value.audioRenderStart &&
        !player.value.videoRenderStart) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(5)),
            color: Color.fromRGBO(0, 0, 0, 0.5),
          ),
          child: const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    Rect rect = panelRect();

    List<Widget> ws = [];

    if (player.state == FState.asyncPreparing) {
      ws.add(buildStateless());
    } else if (player.state == FState.error) {
      ws.add(buildStateless());
    } else if (!player.value.audioRenderStart &&
        !player.value.videoRenderStart) {
      ws.add(buildStateless());
    } else {
      var volume = _volume;
      var brightness = _brightness;
      if (volume != null || brightness != null) {
        Widget toast = volume == null
            ? defaultFBrightnessToast(brightness!, _valController.stream)
            : defaultFVolumeToast(volume, _valController.stream);
        ws.add(
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 500),
              child: toast,
            ),
          ),
        );
      }
      ws.add(buildGestureDetector(context));
    }

    return Positioned.fromRect(
      rect: rect,
      child: Stack(children: ws),
    );
  }
}

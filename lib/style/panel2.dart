part of fplayer;

FPanelWidgetBuilder fPanel2Builder({
  Key? key,
  final bool fill = false,
  final bool videos = false,

  /// 视频标题
  final String title = '',

  /// 视频副标题
  final String subTitle = '',
  final List<Map<String, String>>? videoMap,
  final int duration = 4000,
  final bool doubleTap = true,

  /// 中间区域右上方按钮是否展示
  final bool rightButton = false,

  /// 中间区域右上方按钮Widget集合
  final List<Widget>? rightButtonList,

  /// 截屏按钮是否展示
  final bool snapShot = false,

  /// 字幕按钮是否展示
  final bool caption = false,

  /// 字幕点击事件
  final void Function()? captionFun,

  /// 清晰度按钮是否展示
  final bool resolution = false,

  /// 清晰度点击事件
  final void Function()? resolutionFun,

  /// 设置点击事件
  final void Function()? settingFun,
  // final VoidCallback? onBack,
}) {
  return (FPlayer player, FData data, BuildContext context, Size viewSize,
      Rect texturePos) {
    return _FPanel2(
      key: key,
      player: player,
      data: data,
      // onBack: onBack,
      videos: videos,
      title: title,
      subTitle: subTitle,
      videoMap: videoMap,
      rightButton: rightButton,
      rightButtonList: rightButtonList,
      viewSize: viewSize,
      texPos: texturePos,
      fill: fill,
      doubleTap: doubleTap,
      snapShot: snapShot,
      hideDuration: duration,
      caption: caption,
      captionFun: captionFun,
      resolution: resolution,
      resolutionFun: resolutionFun,
      settingFun: settingFun,
    );
  };
}

class _FPanel2 extends StatefulWidget {
  final FPlayer player;
  final FData data;
  // final VoidCallback? onBack;
  final bool videos;
  final String title;
  final String subTitle;
  final List<Map<String, String>>? videoMap;
  final bool rightButton;
  final List<Widget>? rightButtonList;
  final Size viewSize;
  final Rect texPos;
  final bool fill;
  final bool doubleTap;
  final bool snapShot;
  final int hideDuration;
  final bool caption;
  final void Function()? captionFun;
  final bool resolution;
  final void Function()? resolutionFun;
  final void Function()? settingFun;

  const _FPanel2({
    Key? key,
    required this.player,
    required this.data,
    this.fill = false,
    // this.onBack,
    required this.viewSize,
    this.hideDuration = 4000,
    this.doubleTap = false,
    this.snapShot = false,
    required this.texPos,
    this.videos = false,
    this.title = '',
    this.subTitle = '',
    this.videoMap,
    this.rightButtonList,
    this.rightButton = false,
    this.caption = false,
    this.resolution = false,
    this.captionFun,
    this.resolutionFun,
    this.settingFun,
  })  : assert(hideDuration > 0 && hideDuration < 10000),
        super(key: key);

  @override
  __FPanel2State createState() => __FPanel2State();
}

class __FPanel2State extends State<_FPanel2> {
  FPlayer get player => widget.player;

  Timer? _hideTimer;
  bool _hideStuff = true;

  Timer? _statelessTimer;
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

  Map<String, double> speedList = {
    "2.0": 2.0,
    "1.5": 1.5,
    "1.0": 1.0,
  };

  StreamSubscription? _currentPosSubs;
  StreamSubscription? _bufferPosSubs;

  late StreamController<double> _valController;

  // snapshot
  ImageProvider? _imageProvider;
  Timer? _snapshotTimer;

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
    _prepared = player.state.index >= FState.prepared.index;
    _playing = player.state == FState.started;
    _duration = player.value.duration;
    _currentPos = player.currentPos;
    _bufferPos = player.bufferPos;

    _currentPosSubs = player.onCurrentPosUpdate.listen((v) {
      if (_hideStuff == false) {
        setState(() {
          _currentPos = v;
        });
      } else {
        _currentPos = v;
      }
      if (_needClearSeekData) {
        widget.data.clearValue(FData._fViewPanelSeekto);
      }
      _needClearSeekData = false;
    });

    if (widget.data.contains(FData._fViewPanelSeekto)) {
      var pos = widget.data.getValue(FData._fViewPanelSeekto) as double;
      _currentPos = Duration(milliseconds: pos.toInt());
    }

    _bufferPosSubs = player.onBufferPosUpdate.listen((v) {
      if (_hideStuff == false) {
        setState(() {
          _bufferPos = v;
        });
      } else {
        _bufferPos = v;
      }
    });

    player.addListener(_playerValueChanged);
  }

  @override
  void dispose() {
    super.dispose();
    _valController.close();
    _hideTimer?.cancel();
    _statelessTimer?.cancel();
    _snapshotTimer?.cancel();
    _currentPosSubs?.cancel();
    _bufferPosSubs?.cancel();
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
    bool playing = (value.state == FState.started);
    bool prepared = value.prepared;
    if (playing != _playing ||
        prepared != _prepared ||
        value.state == FState.asyncPreparing) {
      setState(() {
        _playing = playing;
        _prepared = prepared;
      });
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(milliseconds: widget.hideDuration), () {
      setState(() {
        _hideStuff = true;
        hideSpeed = true;
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

  void onDoubleTapFun() {
    playOrPause();
  }

  void onVerticalDragStartFun(DragStartDetails d) {
    if (d.localPosition.dx > panelWidth() / 2) {
      // right, volume
      _dragLeft = false;
      FVolume.getVol().then((v) {
        if (!widget.data.contains(FData._fViewPanelVolume)) {
          widget.data.setValue(FData._fViewPanelVolume, v);
        }
        setState(() {
          _volume = v;
          _valController.add(v);
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
    _statelessTimer?.cancel();
    _statelessTimer = Timer(const Duration(milliseconds: 2000), () {
      setState(() {});
    });
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
    print('value:$value');
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
      color: Theme.of(context).primaryColorDark,
      icon: icon,
      onPressed: playOrPause,
    );
  }

  Widget buildOptTextButton(BuildContext context, double height) {
    return Row(
      children: [
        if (widget.caption)
          TextButton(
            onPressed: widget.captionFun,
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
        if (widget.resolution)
          TextButton(
            onPressed: widget.resolutionFun,
            child: Text(
              '自动',
              style: TextStyle(
                color: Theme.of(context).primaryColorDark,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> buildSpeedListWidget() {
    List<Widget> columnChild = [];
    speedList.forEach((String mapKey, double speedVals) {
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
            Expanded(child: buildSlider(context)),
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
          _imageProvider = provider;
        });
      });
      FLog.d("get snapshot succeed");
    }).catchError((e) {
      FLog.d("get snapshot failed");
    });
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
        padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Visibility(
              visible: widget.rightButton,
              child: Column(
                children: widget.rightButtonList ?? [],
              ),
            ),
            Visibility(
              visible: widget.rightButton,
              child: const SizedBox(
                height: 20,
              ),
            ),
            if (widget.snapShot)
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
        padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
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
              // 倍数选择
              Positioned(
                right: 100,
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
    return GestureDetector(
      onTap: onTapFun,
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.doubleTap && !lock ? onDoubleTapFun : null,
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
            alignment: Alignment.center,
            child: buildDragProgressTime(),
          )
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
      widget.title,
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
        widget.subTitle,
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
    var volume = _volume;
    var brightness = _brightness;
    if (volume != null || brightness != null) {
      Widget toast = volume == null
          ? defaultFBrightnessToast(brightness!, _valController.stream)
          : defaultFVolumeToast(volume, _valController.stream);
      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 500),
          child: toast,
        ),
      );
    } else if (player.state == FState.asyncPreparing) {
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
    } else if (player.state == FState.error) {
      return Container(
        alignment: Alignment.center,
        child: const Icon(
          Icons.error,
          size: 30,
          color: Color(0x99FFFFFF),
        ),
      );
    } else if (_imageProvider != null) {
      _snapshotTimer?.cancel();
      _snapshotTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _imageProvider = null;
          });
        }
      });
      return Center(
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.yellowAccent, width: 3)),
            child:
                Image(height: 200, fit: BoxFit.contain, image: _imageProvider!),
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

    List ws = <Widget>[];

    if (_statelessTimer != null && _statelessTimer!.isActive) {
      ws.add(buildStateless());
    } else if (player.state == FState.asyncPreparing) {
      ws.add(buildStateless());
    } else if (player.state == FState.error) {
      ws.add(buildStateless());
    } else if (_imageProvider != null) {
      ws.add(buildStateless());
    }
    ws.add(buildGestureDetector(context));
    // if (widget.onBack != null) {
    //   ws.add(buildBack(context));
    // }
    return Positioned.fromRect(
      rect: rect,
      child: Stack(children: ws as List<Widget>),
    );
  }
}

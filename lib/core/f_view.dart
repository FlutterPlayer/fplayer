part of fplayer;

typedef FPanelWidgetBuilder = Widget Function(FPlayer player, FData data,
    BuildContext context, Size viewSize, Rect texturePos);

/// How a video should be inscribed into [FView].
///
/// See also [BoxFit]
class FFit {
  const FFit(
      {this.alignment = Alignment.center,
      this.aspectRatio = -1,
      this.sizeFactor = 1.0});

  /// [Alignment] for this [FView] Container.
  /// alignment is applied to Texture inner FView
  final Alignment alignment;

  /// [aspectRatio] controls inner video texture widget's aspect ratio.
  ///
  /// A [FView] has an important child widget which display the video frame.
  /// This important inner widget is a [Texture] in this version.
  /// Normally, we want the aspectRatio of [Texture] to be same
  /// as playback's real video frame's aspectRatio.
  /// It's also the default behaviour of [FView]
  /// or if aspectRatio is assigned null or negative value.
  ///
  /// If you want to change this default behaviour,
  /// just pass the aspectRatio you want.
  ///
  /// Addition: double.infinate is a special value.
  /// The aspect ratio of inner Texture will be same as FView's aspect ratio
  /// if you set double.infinate to attribute aspectRatio.
  final double aspectRatio;

  /// The size of [Texture] is multiplied by this factor.
  ///
  /// Some spacial values:
  ///  * (-1.0, -0.0) scaling up to max of [FView]'s width and height
  ///  * (-2.0, -1.0) scaling up to [FView]'s width
  ///  * (-3.0, -2.0) scaling up to [FView]'s height
  final double sizeFactor;

  /// Fill the target FView box by distorting the video's aspect ratio.
  static const FFit fill = FFit(
    sizeFactor: 1.0,
    aspectRatio: double.infinity,
    alignment: Alignment.center,
  );

  /// As large as possible while still containing the video entirely within the
  /// target FView box.
  static const FFit contain = FFit(
    sizeFactor: 1.0,
    aspectRatio: -1,
    alignment: Alignment.center,
  );

  /// As small as possible while still covering the entire target FView box.
  static const FFit cover = FFit(
    sizeFactor: -0.5,
    aspectRatio: -1,
    alignment: Alignment.center,
  );

  /// Make sure the full width of the source is shown, regardless of
  /// whether this means the source overflows the target box vertically.
  static const FFit fitWidth = FFit(sizeFactor: -1.5);

  /// Make sure the full height of the source is shown, regardless of
  /// whether this means the source overflows the target box horizontally.
  static const FFit fitHeight = FFit(sizeFactor: -2.5);

  /// As large as possible while still containing the video entirely within the
  /// target FView box. But change video's aspect ratio to 4:3.
  static const FFit ar4_3 = FFit(aspectRatio: 4.0 / 3.0);

  /// As large as possible while still containing the video entirely within the
  /// target FView box. But change video's aspect ratio to 16:9.
  static const FFit ar16_9 = FFit(aspectRatio: 16.0 / 9.0);
}

/// [FView] is a widget that can display the video frame of [FPlayer].
///
/// Actually, it is a Container widget contains many children.
/// The most important is a Texture which display the read video frame.
class FView extends StatefulWidget {
  const FView({
    super.key,
    required this.player,
    this.width,
    this.height,
    this.fit = FFit.contain,
    this.fsFit = FFit.contain,
    this.panelBuilder = defaultFPanelBuilder,
    this.color = const Color(0xFF607D8B),
    this.cover,
    this.fs = true,
    this.onDispose,
  });

  /// The player that need display video by this [FView].
  /// Will be passed to [panelBuilder].
  final FPlayer player;

  /// builder to build panel Widget
  final FPanelWidgetBuilder panelBuilder;

  /// This method will be called when fView dispose.
  /// FData is managed inner FView. User can change fData in custom panel.
  /// See [panelBuilder]'s second argument.
  /// And check if some value need to be recover on FView dispose.
  final void Function(FData)? onDispose;

  /// background color
  final Color color;

  /// cover image provider
  final ImageProvider? cover;

  /// How a video should be inscribed into this [FView].
  final FFit fit;

  /// How a video should be inscribed into this [FView] at fullScreen mode.
  final FFit fsFit;

  /// Nullable, width of [FView]
  /// If null, the weight will be as big as possible.
  final double? width;

  /// Nullable, height of [FView].
  /// If null, the height will be as big as possible.
  final double? height;

  /// Enable or disable the full screen
  ///
  /// If [fs] is true, FView make response to the [FValue.fullScreen] value changed,
  /// and push o new full screen mode page when [FValue.fullScreen] is true, pop full screen page when [FValue.fullScreen]  become false.
  ///
  /// If [fs] is false, FView never make response to the change of [FValue.fullScreen].
  /// But you can still call [FPlayer.enterFullScreen] and [FPlayer.exitFullScreen] and make your own full screen pages.
  final bool fs;

  @override
  createState() => _FViewState();
}

class _FViewState extends State<FView> {
  int _textureId = -1;
  double _vWidth = -1;
  double _vHeight = -1;
  bool _fullScreen = false;

  final FData _fData = FData();
  ValueNotifier<int> paramNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    Size? s = widget.player.value.size;
    if (s != null) {
      _vWidth = s.width;
      _vHeight = s.height;
    }
    widget.player.addListener(_fValueListener);
    _nativeSetup();
  }

  Future<void> _nativeSetup() async {
    if (widget.player.value.prepared) {
      _setupTexture();
    }
    paramNotifier.value = paramNotifier.value + 1;
  }

  void _setupTexture() async {
    final int? vid = await widget.player.setupSurface();
    if (vid == null) {
      FLog.e("failed to set surface");
      return;
    }
    FLog.i("view setup, vid:$vid");
    if (mounted) {
      setState(() {
        _textureId = vid;
      });
    }
  }

  void _fValueListener() async {
    FValue value = widget.player.value;
    if (value.prepared && _textureId < 0) {
      _setupTexture();
    }

    if (widget.fs) {
      if (value.fullScreen && !_fullScreen) {
        _fullScreen = true;
        await _pushFullScreenWidget(context);
      } else if (_fullScreen && !value.fullScreen) {
        Navigator.of(context).pop();
        _fullScreen = false;
      }

      // save width and height to make judgement about whether to
      // request landscape when enter full screen mode
      Size? size = value.size;
      if (size != null && value.prepared) {
        _vWidth = size.width;
        _vHeight = size.height;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.player.removeListener(_fValueListener);

    var brightness = _fData.getValue(FData._fViewPanelBrightness);
    if (brightness != null && brightness is double) {
      FPlugin.setScreenBrightness(brightness);
      _fData.clearValue(FData._fViewPanelBrightness);
    }

    var volume = _fData.getValue(FData._fViewPanelVolume);
    if (volume != null && volume is double) {
      FVolume.setVol(volume);
      _fData.clearValue(FData._fViewPanelVolume);
    }

    widget.onDispose?.call(_fData);
  }

  AnimatedWidget _defaultRoutePageBuilder(
      BuildContext context, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: _InnerFView(
            fViewState: this,
            fullScreen: true,
            cover: widget.cover,
            data: _fData,
          ),
        );
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation) {
    return _defaultRoutePageBuilder(context, animation);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    final TransitionRoute<void> route = PageRouteBuilder<void>(
      settings: const RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: []);
    var orientation = MediaQuery.of(context).orientation;
    FLog.d("start enter fullscreen. orientation:$orientation");
    await FPlugin.setOrientationLandscape();

    await Navigator.of(context).push(route);
    _fullScreen = false;
    widget.player.exitFullScreen();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    await FPlugin.setOrientationPortrait();
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget as FView);
    paramNotifier.value = paramNotifier.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _fullScreen
          ? Container()
          : _InnerFView(
              fViewState: this,
              fullScreen: false,
              cover: widget.cover,
              data: _fData,
            ),
    );
  }
}

class _InnerFView extends StatefulWidget {
  const _InnerFView({
    required this.fViewState,
    required this.fullScreen,
    required this.cover,
    required this.data,
  });

  final _FViewState fViewState;
  final bool fullScreen;
  final ImageProvider? cover;
  final FData data;

  @override
  __InnerFViewState createState() => __InnerFViewState();
}

class __InnerFViewState extends State<_InnerFView> {
  late FPlayer _player;
  FPanelWidgetBuilder? _panelBuilder;
  Color? _color;
  FFit _fit = FFit.contain;
  int _textureId = -1;
  double _vWidth = -1;
  double _vHeight = -1;
  final bool _vFullScreen = false;
  int _degree = 0;
  bool _videoRender = false;

  @override
  void initState() {
    super.initState();
    _player = fView.player;
    _fValueListener();
    fView.player.addListener(_fValueListener);
    if (widget.fullScreen) {
      widget.fViewState.paramNotifier.addListener(_voidValueListener);
    }
  }

  FView get fView => widget.fViewState.widget;

  void _voidValueListener() {
    var binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => _fValueListener());
  }

  void _fValueListener() {
    if (!mounted) return;

    FPanelWidgetBuilder panelBuilder = fView.panelBuilder;
    Color color = fView.color;
    FFit fit = widget.fullScreen ? fView.fsFit : fView.fit;
    int textureId = widget.fViewState._textureId;

    FValue value = _player.value;

    _degree = value.rotate;
    double width = _vWidth;
    double height = _vHeight;
    bool fullScreen = value.fullScreen;
    bool videoRender = value.videoRenderStart;

    Size? size = value.size;
    if (size != null && value.prepared) {
      width = size.width;
      height = size.height;
    }

    if (width != _vWidth ||
        height != _vHeight ||
        fullScreen != _vFullScreen ||
        panelBuilder != _panelBuilder ||
        color != _color ||
        fit != _fit ||
        textureId != _textureId ||
        _videoRender != videoRender) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Size applyAspectRatio(BoxConstraints constraints, double aspectRatio) {
    assert(constraints.hasBoundedHeight && constraints.hasBoundedWidth);

    constraints = constraints.loosen();

    double width = constraints.maxWidth;
    double height = width;

    if (width.isFinite) {
      height = width / aspectRatio;
    } else {
      height = constraints.maxHeight;
      width = height * aspectRatio;
    }

    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / aspectRatio;
    }

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * aspectRatio;
    }

    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / aspectRatio;
    }

    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * aspectRatio;
    }

    return constraints.constrain(Size(width, height));
  }

  double getAspectRatio(BoxConstraints constraints, double ar) {
    if (ar < 0) {
      ar = _vWidth / _vHeight;
    } else if (ar.isInfinite) {
      ar = constraints.maxWidth / constraints.maxHeight;
    }
    return ar;
  }

  /// calculate Texture size
  Size getTxSize(BoxConstraints constraints, FFit fit) {
    Size childSize = applyAspectRatio(
        constraints, getAspectRatio(constraints, fit.aspectRatio));
    double sizeFactor = fit.sizeFactor;
    if (-1.0 < sizeFactor && sizeFactor < -0.0) {
      sizeFactor = max(constraints.maxWidth / childSize.width,
          constraints.maxHeight / childSize.height);
    } else if (-2.0 < sizeFactor && sizeFactor < -1.0) {
      sizeFactor = constraints.maxWidth / childSize.width;
    } else if (-3.0 < sizeFactor && sizeFactor < -2.0) {
      sizeFactor = constraints.maxHeight / childSize.height;
    } else if (sizeFactor < 0) {
      sizeFactor = 1.0;
    }
    childSize = childSize * sizeFactor;
    return childSize;
  }

  /// calculate Texture offset
  Offset getTxOffset(BoxConstraints constraints, Size childSize, FFit fit) {
    final Alignment resolvedAlignment = fit.alignment;
    final Offset diff = (constraints.biggest - childSize) as Offset;
    return resolvedAlignment.alongOffset(diff);
  }

  Widget buildTexture() {
    Widget tex = _textureId > 0 ? Texture(textureId: _textureId) : Container();
    if (_degree != 0 && _textureId > 0) {
      return RotatedBox(
        quarterTurns: _degree ~/ 90,
        child: tex,
      );
    }
    return tex;
  }

  @override
  void dispose() {
    super.dispose();
    fView.player.removeListener(_fValueListener);
    widget.fViewState.paramNotifier.removeListener(_fValueListener);
  }

  @override
  Widget build(BuildContext context) {
    _panelBuilder = fView.panelBuilder;
    _color = fView.color;
    _fit = widget.fullScreen ? fView.fsFit : fView.fit;
    _textureId = widget.fViewState._textureId;

    FValue value = _player.value;
    FData data = widget.data;
    Size? size = value.size;
    if (size != null && value.prepared) {
      _vWidth = size.width;
      _vHeight = size.height;
    }
    _videoRender = value.videoRenderStart;

    return LayoutBuilder(builder: (ctx, constraints) {
      // get child size
      final Size childSize = getTxSize(constraints, _fit);
      final Offset offset = getTxOffset(constraints, childSize, _fit);
      final Rect pos = Rect.fromLTWH(
          offset.dx, offset.dy, childSize.width, childSize.height);

      List ws = <Widget>[
        Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          color: _color,
        ),
        Positioned.fromRect(
            rect: pos,
            child: Container(
              color: const Color(0xFF000000),
              child: buildTexture(),
            )),
      ];

      if (widget.cover != null && !value.videoRenderStart) {
        ws.add(Positioned.fromRect(
          rect: pos,
          child: Image(
            image: widget.cover!,
            fit: BoxFit.fill,
          ),
        ));
      }

      if (_panelBuilder != null) {
        ws.add(_panelBuilder!(_player, data, ctx, constraints.biggest, pos));
      }
      return Stack(
        children: ws as List<Widget>,
      );
    });
  }
}

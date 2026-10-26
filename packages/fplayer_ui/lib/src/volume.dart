//MIT License
//
//Copyright (c) [2019] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

part of fplayer_ui;

/// Default builder generate default FVolToast UI
Widget defaultFVolumeToast(double value, Stream<double> emitter) {
  return _FSliderToast(value, 0, emitter);
}

Widget defaultFBrightnessToast(double value, Stream<double> emitter) {
  return _FSliderToast(value, 1, emitter);
}

class _FSliderToast extends StatefulWidget {
  final Stream<double> emitter;
  final double initial;

  // type 0 volume
  // type 1 screen brightness
  final int type;

  const _FSliderToast(this.initial, this.type, this.emitter);

  @override
  _FSliderToastState createState() => _FSliderToastState();
}

class _FSliderToastState extends State<_FSliderToast> {
  double value = 0;
  StreamSubscription? subs;

  @override
  void initState() {
    super.initState();
    value = widget.initial;
    subs = widget.emitter.listen((v) {
      setState(() {
        value = v;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    subs?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    final type = widget.type;
    if (value <= 0) {
      iconData = type == 0 ? Icons.volume_mute : Icons.brightness_low;
    } else if (value < 0.5) {
      iconData = type == 0 ? Icons.volume_down : Icons.brightness_medium;
    } else {
      iconData = type == 0 ? Icons.volume_up : Icons.brightness_high;
    }

    final primaryColor = Theme.of(context).primaryColor;
    return Align(
      alignment: const Alignment(0, -0.4),
      child: Card(
        color: const Color(0x33000000),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                iconData,
                color: Colors.white,
              ),
              Container(
                width: 100,
                height: 1.5,
                margin: const EdgeInsets.only(left: 8),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.black,
                  valueColor: AlwaysStoppedAnimation(primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Volume changed callback func.
///
/// See [FVolumeEvent]
/// [value] is the value of volume, and has been mapped into range [0.0, 1.0]
/// true value of [ui] indicates that Android/iOS system volume changed UI is shown for this volume change event
/// [streamType] shows track\stream type for this volume change, this value is always [FVolume.STREAM_MUSIC] in this version
typedef FVolumeCallback = void Function(FVolumeEvent value);

/// stateful widget that watching system volume, no ui widget
/// when system volume changed, [watcher] will be invoked.
class FVolumeWatcher extends StatefulWidget {
  /// volume changed callback
  final FVolumeCallback watcher;

  /// child widget, must be non-null
  final Widget child;

  /// whether show default volume changed toast, default value is false.
  ///
  /// The default toast ui insert an OverlayEntry to current context's overlay
  final bool showToast;

  const FVolumeWatcher({
    super.key,
    required this.watcher,
    /*required*/ required this.child,
    this.showToast = false,
  });

  @override
  _FVolumeWatcherState createState() => _FVolumeWatcherState();
}

class _FVolumeWatcherState extends State<FVolumeWatcher> {
  static OverlayEntry? _entry;
  static Timer? _timer;
  late StreamController<double> _volController;

  @override
  void initState() {
    super.initState();
    _volController = StreamController.broadcast();
    FVolume.addListener(volChanged);
    FVolume.setUIMode(FVolume.hideUIWhenPlayable);
  }

  void volChanged() {
    FVolumeEvent value = FVolume.value;
    _volController.add(value.vol);
    widget.watcher(value);
    if (widget.showToast && !value.sui) {
      showVolToast(value.vol);
    }
  }

  /// reference https://www.kikt.top/posts/flutter/toast/oktoast/
  void showVolToast(double vol) {
    bool active = _timer?.isActive ?? false;
    _timer?.cancel();
    Widget widget = defaultFVolumeToast(vol, _volController.stream);
    if (active == false) {
      var entry = OverlayEntry(builder: (_) => widget);
      _entry = entry;
      Overlay.of(context).insert(entry);
    }
    _timer = Timer(const Duration(milliseconds: 800), () {
      _entry?.remove();
    });
  }

  @override
  void dispose() {
    super.dispose();
    FVolume.removeListener(volChanged);
    _volController.close();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

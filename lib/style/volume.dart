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

part of fplayer;

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

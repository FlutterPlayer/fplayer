part of fplayer;

enum FState {
  /// The state when a [FPlayer] is just created.
  /// Native ijkplayer memory and objects also be alloced or created when a [FPlayer] is created.
  ///
  /// * setDataSource()  -> [initialized]
  /// * reset()          -> self
  /// * release()        -> [end]
  idle,

  /// After call [FPlayer.setDataSource] on state [idle], the state becomes [initialized].
  ///
  /// * prepareAsync()   -> [asyncPreparing]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  initialized,

  /// There're many tasks to do during prepare, such as detect stream info in datasource, find and open decoder, start decode and refresh thread.
  /// So ijkplayer export a async api prepareAsync.
  /// When [FPlayer.prepareAsync] is called on state [initialized], ths state changed to [asyncPreparing] immediately.
  /// After all task in prepare have finished, the state changed to [prepared].
  /// Additionally, if any error occurs during prepare, the state will change to [error].
  ///
  /// * .....            -> [prepared]
  /// * .....            -> [error]
  /// * .....            -> [stopped]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  asyncPreparing,

  /// After finish all the heavy tasks during [FPlayer.prepareAsync],
  /// the state becomes [prepared] from [asyncPreparing].
  ///
  /// * seekTo()         -> self
  /// * start()          -> [started]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  prepared,

  /// * seekTo()         -> self
  /// * start()          -> self
  /// * pause()          -> [paused]
  /// * stop()           -> [stopped]
  /// * ......           -> [completed]
  /// * ......           -> [error]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  started,

  /// * seekTo()         -> self
  /// * start()          -> [started]
  /// * pause()          -> self
  /// * stop()           -> [stopped]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  paused,

  /// * seekTo()         -> [paused]
  /// * start()          -> [started] (from beginning)
  /// * pause()          -> self
  /// * stop()           -> [stopped]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  completed,

  /// * stop()           -> self
  /// * prepareAsync()   -> [asyncPreparing]
  /// * reset()          -> [idle]
  /// * release()        -> [end]
  stopped,

  /// * reset()          -> [idle]
  /// * release()        -> [end]
  error,

  /// * release()        -> self
  end
}

/// FValue include the properties of a [FPlayer] which update not frequently.
///
/// To get the updated value of other frequently updated properties,
/// add listener of the value stream.
/// See
///  * [FPlayer.onBufferPosUpdate]
///  * [FPlayer.onCurrentPosUpdate]
///  * [FPlayer.onBufferStateUpdate]
@immutable
class FValue {
  /// Indicates if the player is ready
  final bool prepared;

  /// Indicates if the player is completed
  ///
  /// If the playback stream is realtime/live, [completed] never be true.
  final bool completed;

  /// Indicates if audio is started rendering
  ///
  /// When first audio frame rendered, this value changes to true from false.
  /// After call [FPlayer.reset], this value becomes to false.
  final bool audioRenderStart;

  /// Indicates if video is started rendering
  ///
  /// When first video frame rendered, this value changes to true from false.
  /// After call [FPlayer.reset], this value becomes to false.
  final bool videoRenderStart;

  /// Current state of the player
  final FState state;

  /// The pixel [size] of current video
  ///
  /// Is null when [prepared] is false.
  /// Is negative width and height if playback is audio only.
  final Size? size;

  /// The rotation degrees
  final int rotate;

  /// The current playback duration
  ///
  /// Is null when [prepared] is false.
  /// Is zero when playback is realtime stream.
  final Duration duration;

  /// whether if player should be displayed in full screen mode
  final bool fullScreen;

  final FException exception;

  /// A constructor requires all value.
  const FValue({
    required this.prepared,
    required this.completed,
    required this.audioRenderStart,
    required this.videoRenderStart,
    required this.state,
    required this.size,
    required this.rotate,
    required this.duration,
    required this.fullScreen,
    required this.exception,
  });

  /// Construct FValue with uninitialized value
  const FValue.uninitialized()
      : this(
          prepared: false,
          completed: false,
          videoRenderStart: false,
          audioRenderStart: false,
          state: FState.idle,
          size: null,
          rotate: 0,
          duration: const Duration(),
          fullScreen: false,
          exception: FException.noException,
        );

  /// Return new FValue which combines the old value and the assigned new value
  FValue copyWith({
    bool? prepared,
    bool? completed,
    bool? videoRenderStart,
    bool? audioRenderStart,
    FState? state,
    Size? size,
    int? rotate,
    Duration? duration,
    bool? fullScreen,
    FException? exception,
  }) {
    return FValue(
      prepared: prepared ?? this.prepared,
      completed: completed ?? this.completed,
      videoRenderStart: videoRenderStart ?? this.videoRenderStart,
      audioRenderStart: audioRenderStart ?? this.audioRenderStart,
      state: state ?? this.state,
      size: size ?? this.size,
      rotate: rotate ?? this.rotate,
      duration: duration ?? this.duration,
      fullScreen: fullScreen ?? this.fullScreen,
      exception: exception ?? this.exception,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FValue &&
          runtimeType == other.runtimeType &&
          hashCode == other.hashCode;

  @override
  int get hashCode => Object.hash(
        prepared,
        completed,
        state,
        size,
        rotate,
        videoRenderStart,
        audioRenderStart,
        duration,
        fullScreen,
        exception,
      );

  @override
  String toString() {
    return "prepared:$prepared, completed:$completed, state:$state, "
        "size:$size, rotate:$rotate, duration:$duration, "
        "fullScreen:$fullScreen, exception:$exception";
  }
}

@immutable
class FException implements Exception {
  static const int ok = 0;
  static const FException noException = FException(ok);

  /// local file or asset not found,
  static const int local404 = -875574348;

  /// local io exception
  static const int localIOe = -1162824012;

  /// Internal bug
  static const int interBug = -558323010;

  /// Buffer too small
  static const int smallBuf = -1397118274;

  /// Decoder not found
  static const int noDecoder = -1128613112;

  /// Demuxer not found
  static const int noDemuxer = -1296385272;

  /// Encoder not found
  static const int noEncoder = -1129203192;

  /// End of file
  static const int fileEnd = -541478725;

  /// Immediate exit was requested
  static const int exitImm = -1414092869;

  /// Generic error in an external library
  static const int extErr = -542398533;

  /// Filter not found
  static const int noFilter = -1279870712;

  /// Invalid data found when processing input
  static const int badData = -1094995529;

  /// Muxer not found
  static const int noMuxer = -1481985528;

  /// Option not found
  static const int noOption = -1414549496;

  /// Not yet implemented in FFmpeg, patches welcome
  static const int noImplemented = -1163346256;

  /// Protocol not found
  static const int noProtocol = -1330794744;

  /// Stream not found
  static const int noStream = -1381258232;

  /// unknown error
  static const int unknown = -1313558101;

  /// Http 400
  static const int http400 = -808465656;

  /// Http 401
  static const int http401 = -825242872;

  /// Http 403
  static const int http403 = -858797304;

  /// Http 404
  static const int http404 = -875574520;

  /// Http 4xx
  static const int http4xx = -1482175736;

  /// Http 5xx
  static const int http5xx = -1482175992;

  /// exception code
  final int code;

  /// human readable exception message
  final String? message;

  // const FException(code, [this.message]) : code = code;

  const FException(this.code, [this.message]);

  static FException fromPlatformException(PlatformException e) {
    int? code = int.tryParse(e.code);
    return code != null
        ? FException(code, e.message)
        : FException(unknown, e.message);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FException &&
          runtimeType == other.runtimeType &&
          hashCode == other.hashCode;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() {
    return "FException($code, $message)";
  }
}

class FData {
  static const String _fViewPanelVolume = "__fview_panel_init_volume";
  static const String _fViewPanelBrightness = "__fview_panel_init_brightness";
  static const String _fViewPanelSeekto = "__fview_panel_sekto_position";

  final Map<String, dynamic> _data = HashMap();

  void setValue(String key, dynamic value) {
    _data[key] = value;
  }

  void clearValue(String key) {
    _data.remove(key);
  }

  bool contains(String key) {
    return _data.containsKey(key);
  }

  dynamic getValue(String key) {
    return _data[key];
  }
}

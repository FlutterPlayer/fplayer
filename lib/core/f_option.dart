part of fplayer;

class FOption {
  final Map<int, Map<String, dynamic>> _options = HashMap();

  final Map<String, dynamic> _hostOption = HashMap();
  final Map<String, dynamic> _formatOption = HashMap();
  final Map<String, dynamic> _codecOption = HashMap();
  final Map<String, dynamic> _swsOption = HashMap();
  final Map<String, dynamic> _playerOption = HashMap();
  final Map<String, dynamic> _swrOption = HashMap();

  static const int hostCategory = 0;
  static const int formatCategory = 1;
  static const int codecCategory = 2;
  static const int swsCategory = 3;
  static const int playerCategory = 4;
  static const int swrCategory = 5;

  /// return a deep copy of option datas
  Map<int, Map<String, dynamic>> get data {
    final Map<int, Map<String, dynamic>> options = HashMap();
    options[0] = Map.from(_hostOption);
    options[1] = Map.from(_formatOption);
    options[2] = Map.from(_codecOption);
    options[3] = Map.from(_swsOption);
    options[4] = Map.from(_playerOption);
    options[5] = Map.from(_swrOption);
    FLog.i("FOption cloned");
    return options;
  }

  FOption() {
    _options[0] = _hostOption;
    _options[1] = _formatOption;
    _options[2] = _codecOption;
    _options[3] = _swsOption;
    _options[4] = _playerOption;
    _options[5] = _swrOption;
  }

  /// set host option
  /// [value] must be int or String
  void setHostOption(String key, dynamic value) {
    if (value is String || value is int) {
      _hostOption[key] = value;
      FLog.v("FOption.setHostOption key:$key, value :$value");
    } else {
      FLog.e("FOption.setHostOption with invalid value:$value");
      throw ArgumentError.value(value, "value", "Must be int or String");
    }
  }

  /// set player option
  /// [value] must be int or String
  void setPlayerOption(String key, dynamic value) {
    if (value is String || value is int) {
      _playerOption[key] = value;
      FLog.v("FOption.setPlayerOption key:$key, value :$value");
    } else {
      FLog.e("FOption.setPlayerOption with invalid value:$value");
      throw ArgumentError.value(value, "value", "Must be int or String");
    }
  }

  /// set ffmpeg avformat option
  /// [value] must be int or String
  void setFormatOption(String key, dynamic value) {
    if (value is String || value is int) {
      _formatOption[key] = value;
      FLog.v("FOption.setFormatOption key:$key, value :$value");
    } else {
      FLog.e("FOption.setFormatOption with invalid value:$value");
      throw ArgumentError.value(value, "value", "Must be int or String");
    }
  }

  /// set ffmpeg avcodec option
  /// [value] must be int or String
  void setCodecOption(String key, dynamic value) {
    if (value is String || value is int) {
      _codecOption[key] = value;
      FLog.v("FOption.setCodecOption key:$key, value :$value");
    } else {
      FLog.e("FOption.setCodecOption with invalid value:$value");
      throw ArgumentError.value(value, "value", "Must be int or String");
    }
  }

  /// set ffmpeg swscale option
  /// [value] must be int or String
  void setSwsOption(String key, dynamic value) {
    if (value is String || value is int) {
      _swsOption[key] = value;
      FLog.v("FOption.setSwsOption key:$key, value :$value");
    } else {
      FLog.e("FOption.setSwsOption with invalid value:$value");
      throw ArgumentError.value(value, "value", "Must be int or String");
    }
  }

  /// set ffmpeg swresample option
  /// [value] must be int or String
  void setSwrOption(String key, dynamic value) {
    if (value is String || value is int) {
      _swrOption[key] = value;
      FLog.v("FOption.setSwrOption key:$key, value :$value");
    } else {
      FLog.e("FOption.setSwrOption with invalid value:$value");
      throw ArgumentError.value(value, "value", "Must be int or String");
    }
  }
}

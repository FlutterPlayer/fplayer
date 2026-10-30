part of fplayer;

/// Metadata of an audio stream in the current media source.
class FAudioTrack {
  /// The stream index used to select this track.
  final int index;

  /// The stream language, if the media declares one.
  final String? language;

  /// The short codec name, for example `aac`.
  final String? codec;

  /// The descriptive codec name, for example `AAC (Advanced Audio Coding)`.
  final String? codecLongName;

  /// The audio sample rate in Hz.
  final int? sampleRate;

  /// The FFmpeg channel layout bit mask.
  final int? channelLayout;

  /// Whether this is the currently selected audio track.
  final bool selected;

  const FAudioTrack({
    required this.index,
    this.language,
    this.codec,
    this.codecLongName,
    this.sampleRate,
    this.channelLayout,
    this.selected = false,
  });

  factory FAudioTrack.fromMap(Map<dynamic, dynamic> map) {
    int? readInt(String key) {
      final value = map[key];
      return value is num ? value.toInt() : null;
    }

    String? readString(String key) {
      final value = map[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return FAudioTrack(
      index: readInt('index') ?? -1,
      language: readString('language'),
      codec: readString('codec'),
      codecLongName: readString('codec_long_name'),
      sampleRate: readInt('sample_rate'),
      channelLayout: readInt('channel_layout'),
      selected: map['selected'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FAudioTrack &&
            index == other.index &&
            language == other.language &&
            codec == other.codec &&
            codecLongName == other.codecLongName &&
            sampleRate == other.sampleRate &&
            channelLayout == other.channelLayout &&
            selected == other.selected;
  }

  @override
  int get hashCode => Object.hash(index, language, codec, codecLongName,
      sampleRate, channelLayout, selected);

  @override
  String toString() =>
      'FAudioTrack{index:$index, language:$language, codec:$codec, selected:$selected}';
}

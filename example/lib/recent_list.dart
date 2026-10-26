import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_bar.dart';
import 'media_item.dart';

const List<MediaUrl> samples = [
  MediaUrl(
      title: "Aliyun", url: "http://player.alicdn.com/video/aliyunmedia.mp4"),
  MediaUrl(title: "http 404", url: "https://fplayer.dev/butterfly.flv"),
  MediaUrl(title: "assets file", url: "asset:///assets/butterfly.mp4"),
  MediaUrl(title: "assets file", url: "asset:///assets/birthday.mp4"),
  MediaUrl(title: "assets file 404", url: "asset:///assets/beebee.mp4"),
  MediaUrl(
      title: "Protocol not found", url: "noprotocol://assets/butterfly.mp4"),
  MediaUrl(
      title: "rtsp test",
      url: "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov"),
  MediaUrl(
      title: "Sample Video 360 * 240",
      url:
          "https://sample-videos.com/video123/flv/240/big_buck_bunny_240p_10mb.flv"),
  MediaUrl(
      title: "bipbop basic master playlist",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"),
  MediaUrl(
      title: "bipbop basic 400x300 @ 232 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop basic 640x480 @ 650 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear2/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop basic 640x480 @ 1 Mbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear3/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop basic 960x720 @ 2 Mbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear4/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop basic 22.050Hz stereo @ 40 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop advanced master playlist",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"),
  MediaUrl(
      title: "bipbop advanced 416x234 @ 265 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop advanced 640x360 @ 580 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear2/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop advanced 960x540 @ 910 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear3/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop advanced 1280x720 @ 1 Mbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear4/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop advanced 1920x1080 @ 2 Mbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear5/prog_index.m3u8"),
  MediaUrl(
      title: "bipbop advanced 22.050Hz stereo @ 40 kbps",
      url:
          "http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear0/prog_index.m3u8"),
];

class SamplesScreen extends StatelessWidget {
  const SamplesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FAppBar.defaultSetting(title: "Online Samples"),
      body: ListView.builder(
        itemCount: samples.length,
        itemBuilder: (BuildContext context, int index) {
          MediaUrl mediaUrl = samples[index];
          return MediaItem(mediaUrl: mediaUrl);
        },
      ),
    );
  }
}

class RecentMediaList extends StatefulWidget {
  const RecentMediaList({super.key});

  @override
  _RecentMediaListState createState() => _RecentMediaListState();
}

class _RecentMediaListState extends State<RecentMediaList> {
  List<MediaUrl> _items = <MediaUrl>[];
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    RecentStore.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RecentStore.revision.removeListener(_load);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await RecentStore.load();
    if (!mounted) return;
    setState(() {
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        controller: _controller,
        itemCount: _items.length,
        itemBuilder: (BuildContext context, int index) {
          return MediaItem(mediaUrl: _items[index]);
        });
  }
}

class RecentStore {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static const int maxItems = 20;

  static File get _file => File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}fplayer_recent.json');

  static Future<List<MediaUrl>> load() async {
    try {
      if (!await _file.exists()) return <MediaUrl>[];
      final text = await _file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! List) return <MediaUrl>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => MediaUrl.fromJson(item))
          .toList();
    } catch (_) {
      return <MediaUrl>[];
    }
  }

  static Future<void> add(MediaUrl mediaUrl) async {
    final items = await load();
    items.removeWhere((item) => item.url == mediaUrl.url);
    items.insert(0, mediaUrl);
    if (items.length > maxItems) {
      items.removeRange(maxItems, items.length);
    }
    try {
      await _file.writeAsString(
        jsonEncode(items.map((item) => item.toJson()).toList()),
        flush: true,
      );
    } catch (_) {
      return;
    }
    revision.value++;
  }
}

Future<void> addToHistory(MediaUrl mediaUrl) => RecentStore.add(mediaUrl);

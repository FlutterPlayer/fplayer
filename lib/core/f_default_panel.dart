part of fplayer;

/// Minimal panel used when the application does not provide a panel builder.
///
/// Rich panels live in the optional `fplayer_ui` package.
Widget minimalFPanelBuilder(
  FPlayer player,
  FData data,
  BuildContext context,
  Size viewSize,
  Rect texturePos,
) {
  return ValueListenableBuilder<FValue>(
    valueListenable: player,
    builder: (BuildContext context, FValue value, Widget? child) {
      if (!value.prepared) {
        return const SizedBox.shrink();
      }
      final bool playing = value.state == FState.started;
      return Center(
        child: IconButton(
          color: Colors.white,
          iconSize: 48,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          onPressed: () async {
            try {
              if (playing) {
                await player.pause();
              } else {
                await player.start();
              }
            } catch (error) {
              FLog.e("minimal panel play/pause failed: $error");
            }
          },
        ),
      );
    },
  );
}

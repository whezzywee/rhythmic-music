import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/core/core.dart';

class PlayerProgress extends StatefulWidget {
  const PlayerProgress({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<PlayerProgress> createState() => _PlayerProgressState();
}

class _PlayerProgressState extends State<PlayerProgress> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return StreamBuilder<PlaybackProgress>(
      stream: widget.backend.playback.progress,
      builder: (context, snapshot) {
        final progress = snapshot.data ??
            const PlaybackProgress(
              current: Duration.zero,
              buffered: Duration.zero,
              total: Duration.zero,
            );
        final totalMillis = progress.total.inMilliseconds;
        final currentMillis = progress.current.inMilliseconds;
        final value = _dragValue ??
            (totalMillis == 0
                ? 0.0
                : currentMillis.clamp(0, totalMillis).toDouble());

        return Column(
          children: [
            Slider(
              value:
                  value.clamp(0, totalMillis == 0 ? 1 : totalMillis).toDouble(),
              min: 0,
              max: totalMillis == 0 ? 1 : totalMillis.toDouble(),
              onChangeStart: (value) {
                setState(() => _dragValue = value);
              },
              onChanged: totalMillis == 0
                  ? null
                  : (value) {
                      setState(() => _dragValue = value);
                    },
              onChangeEnd: totalMillis == 0
                  ? null
                  : (value) async {
                      setState(() => _dragValue = null);
                      await widget.backend.playback.seek(
                        Duration(milliseconds: value.round()),
                      );
                    },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    _formatDuration(
                      Duration(milliseconds: value.round()),
                    ),
                    style: TextStyle(color: colors.muted),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(progress.total),
                    style: TextStyle(color: colors.muted),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/widgets/artwork.dart';

class SongResultTile extends StatelessWidget {
  const SongResultTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.actions,
  });

  final MediaItem song;
  final int index;
  final VoidCallback onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted),
                ),
              ),
              Artwork(uri: song.artUri, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist ?? song.album ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Play',
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: onTap,
              ),
              if (actions != null) actions!,
            ],
          ),
        ),
      ),
    );
  }
}

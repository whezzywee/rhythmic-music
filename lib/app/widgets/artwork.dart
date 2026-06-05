import 'package:flutter/material.dart';

import '/app/app_theme.dart';

class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.uri, required this.size});

  final Uri? uri;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final url = uri?.toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: colors.surfaceHigh,
        child: url == null || url.isEmpty
            ? Icon(Icons.music_note_rounded, color: colors.muted)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.music_note_rounded, color: colors.muted);
                },
              ),
      ),
    );
  }
}

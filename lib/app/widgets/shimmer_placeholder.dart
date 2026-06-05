import 'package:flutter/material.dart';

import '/app/app_theme.dart';

/// Animated shimmer placeholder used while content loads.
/// Displays [rows] grey bars to mimic the target layout shape.
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key, this.rows = 6, this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24)});

  final int rows;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(rows, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _Bar(width: 52, height: 52, radius: 8, color: colors.surfaceHigh),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(width: double.infinity, height: 15, radius: 4, color: colors.surfaceHigh),
                      const SizedBox(height: 8),
                      _Bar(width: 160, height: 13, radius: 4, color: colors.surfaceHigh),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class ShimmerSection extends StatelessWidget {
  const ShimmerSection({super.key, this.cardCount = 5, this.cardWidth = 142, this.cardHeight = 142});

  final int cardCount;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _Bar(width: 180, height: 20, radius: 4, color: colors.surfaceHigh),
          ),
          SizedBox(
            height: cardHeight + 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cardCount,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(width: cardWidth, height: cardHeight, radius: 8, color: colors.surfaceHigh),
                      const SizedBox(height: 9),
                      _Bar(width: cardWidth * 0.8, height: 14, radius: 4, color: colors.surfaceHigh),
                      const SizedBox(height: 4),
                      _Bar(width: cardWidth * 0.5, height: 12, radius: 4, color: colors.surfaceHigh),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.radius, required this.color});

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

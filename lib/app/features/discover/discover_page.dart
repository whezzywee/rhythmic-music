import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/features/details/media_collection_detail_page.dart';
import '/app/widgets/artwork.dart';
import '/app/widgets/inline_message.dart';
import '/app/widgets/page_header.dart';
import '/app/widgets/shimmer_placeholder.dart';
import '/core/core.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late Future<List<_DiscoverSection>> _sectionsFuture = _loadSections();
  MediaCollectionDetail? _detail;

  Future<List<_DiscoverSection>> _loadSections() async {
    final home = await widget.backend.music.getHome(limit: 8);
    final sections = <_DiscoverSection>[];
    for (final section in home) {
      if (section is! Map) continue;
      final title = section['title']?.toString();
      final contents = section['contents'];
      if (title == null || contents is! List || contents.isEmpty) continue;
      final items = contents.where((item) => item != null).toList();
      if (items.isEmpty) continue;
      sections.add(_DiscoverSection(title: title, items: items));
    }
    return sections;
  }

  void _refresh() {
    setState(() {
      _detail = null;
      _sectionsFuture = _loadSections();
    });
  }

  void _openItem(dynamic item, List<dynamic> sectionItems, int index) {
    if (item is MediaItem) {
      final songs = sectionItems.whereType<MediaItem>().toList();
      final songIndex = songs.indexWhere((song) => song.id == item.id);
      widget.backend.playback.playQueue(
        songs,
        startIndex: songIndex < 0 ? 0 : songIndex,
      );
      return;
    }

    if (item is Album) {
      setState(() {
        _detail = MediaCollectionDetail.album(
          backend: widget.backend,
          album: item,
        );
      });
      return;
    }

    if (item is Playlist) {
      setState(() {
        _detail = MediaCollectionDetail.playlist(
          backend: widget.backend,
          playlist: item,
        );
      });
      return;
    }

    if (item is Artist) {
      setState(() {
        _detail = MediaCollectionDetail.artist(
          backend: widget.backend,
          artist: item,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail != null) {
      return MediaCollectionDetailPage(
        detail: detail,
        backend: widget.backend,
        onBack: () => setState(() => _detail = null),
      );
    }

    return FutureBuilder<List<_DiscoverSection>>(
      future: _sectionsFuture,
      builder: (context, snapshot) {
        final sections = snapshot.data ?? const <_DiscoverSection>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Discover',
                subtitle: 'Fresh picks from YouTube Music',
                action: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ),
            ),
            if (loading)
              ..._shimmerSections()
            else if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: InlineMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Discover failed to load',
                  subtitle: 'Check your connection',
                  onRetry: _refresh,
                ),
              )
            else if (sections.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: InlineMessage(
                  icon: Icons.explore_rounded,
                  title: 'Nothing to show yet',
                  subtitle: 'Pull to refresh or try again',
                ),
              )
            else
              SliverList.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  return _DiscoverSectionView(
                    section: sections[index],
                    onTap: _openItem,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  List<Widget> _shimmerSections() {
    return const [
      SliverToBoxAdapter(child: ShimmerSection(cardCount: 6)),
      SliverToBoxAdapter(child: ShimmerSection(cardCount: 5)),
    ];
  }
}

class _DiscoverSection {
  const _DiscoverSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<dynamic> items;
}

class _DiscoverSectionView extends StatelessWidget {
  const _DiscoverSectionView({
    required this.section,
    required this.onTap,
  });

  final _DiscoverSection section;
  final void Function(dynamic item, List<dynamic> sectionItems, int index)
      onTap;

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
            child: Text(
              section.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: 194,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: section.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = section.items[index];
                return _DiscoverItemCard(
                  item: item,
                  mutedColor: colors.muted,
                  onTap: () => onTap(item, section.items, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverItemCard extends StatelessWidget {
  const _DiscoverItemCard({
    required this.item,
    required this.mutedColor,
    required this.onTap,
  });

  final dynamic item;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscoverArtwork(item: item),
              const SizedBox(height: 9),
              Text(
                _title(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(dynamic item) {
    if (item is MediaItem) return item.title;
    if (item is Album) return item.title;
    if (item is Playlist) return item.title;
    if (item is Artist) return item.name;
    return 'Untitled';
  }

  String _subtitle(dynamic item) {
    if (item is MediaItem) return item.artist ?? item.album ?? 'Song';
    if (item is Album) return item.description ?? _artistNames(item.artists);
    if (item is Playlist) return item.description ?? 'Playlist';
    if (item is Artist) return item.subscribers ?? 'Artist';
    return 'Music';
  }
}

class _DiscoverArtwork extends StatelessWidget {
  const _DiscoverArtwork({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final uri = _uri(item);

    if (uri != null) {
      return Artwork(uri: uri, size: 142);
    }

    return Container(
      width: 142,
      height: 142,
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_icon(item), color: colors.muted, size: 38),
    );
  }

  Uri? _uri(dynamic item) {
    if (item is MediaItem) return item.artUri;
    if (item is Album) return Uri.tryParse(item.thumbnailUrl);
    if (item is Playlist) return Uri.tryParse(item.thumbnailUrl);
    if (item is Artist) return Uri.tryParse(item.thumbnailUrl);
    return null;
  }

  IconData _icon(dynamic item) {
    if (item is Album) return Icons.album_rounded;
    if (item is Playlist) return Icons.queue_music_rounded;
    if (item is Artist) return Icons.person_rounded;
    return Icons.music_note_rounded;
  }
}

String _artistNames(List<Map<dynamic, dynamic>>? artists) {
  final names = artists
      ?.map((artist) => artist['name']?.toString())
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toList();
  if (names == null || names.isEmpty) return 'Album';
  return names.join(', ');
}

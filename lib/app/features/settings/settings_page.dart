import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/widgets/page_header.dart';
import '/core/core.dart';
import '/services/music_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<SettingsSnapshot> _settingsFuture = _loadSettings();

  Future<SettingsSnapshot> _loadSettings() {
    return widget.backend.settings.load();
  }

  void _refresh() {
    setState(() => _settingsFuture = _loadSettings());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SettingsSnapshot>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Settings',
                subtitle: loading
                    ? 'Loading preferences'
                    : 'Playback, storage, language',
                action: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (settings == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Settings failed to load')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.list(
                  children: [
                    _PlaybackSection(
                      backend: widget.backend,
                      settings: settings,
                      onChanged: _refresh,
                    ),
                    const SizedBox(height: 20),
                    _StorageSection(
                      backend: widget.backend,
                      settings: settings,
                      onChanged: _refresh,
                    ),
                    const SizedBox(height: 20),
                    _LanguageSection(
                      backend: widget.backend,
                      settings: settings,
                      onChanged: _refresh,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection({
    required this.backend,
    required this.settings,
    required this.onChanged,
  });

  final HarmonyBackend backend;
  final SettingsSnapshot settings;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Playback',
      children: [
        _PreferenceSelect<AudioQuality>(
          title: 'Streaming quality',
          subtitle: 'Choose the preferred stream quality',
          value: settings.streamingQuality,
          values: AudioQuality.values,
          labelBuilder: (value) => value == AudioQuality.High ? 'High' : 'Low',
          onChanged: (value) async {
            await backend.settings.setStreamingQuality(value);
            onChanged();
          },
        ),
        _PreferenceSwitch(
          value: settings.skipSilenceEnabled,
          title: 'Skip silence',
          subtitle: 'Trim quiet sections while playing',
          onChanged: (value) async {
            await backend.settings.setBool('skipSilenceEnabled', value);
            await backend.playback.setSkipSilenceEnabled(value);
            onChanged();
          },
        ),
        _PreferenceSwitch(
          value: settings.loudnessNormalizationEnabled,
          title: 'Loudness normalization',
          subtitle: 'Keep playback volume more consistent',
          onChanged: (value) async {
            await backend.settings
                .setBool('loudnessNormalizationEnabled', value);
            await backend.playback.setLoudnessNormalizationEnabled(value);
            onChanged();
          },
        ),
        _PreferenceSwitch(
          value: settings.backgroundPlayEnabled,
          title: 'Background play',
          subtitle: 'Keep audio active outside the app',
          onChanged: (value) async {
            await backend.settings.setBool('backgroundPlayEnabled', value);
            onChanged();
          },
        ),
      ],
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({
    required this.backend,
    required this.settings,
    required this.onChanged,
  });

  final HarmonyBackend backend;
  final SettingsSnapshot settings;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return _SettingsSection(
      title: 'Storage',
      children: [
        _PreferenceSelect<DownloadFormat>(
          title: 'Download format',
          subtitle: 'Audio container for saved songs',
          value: settings.downloadFormat,
          values: DownloadFormat.values,
          labelBuilder: (value) => value.value,
          onChanged: (value) async {
            await backend.settings.setDownloadFormat(value);
            onChanged();
          },
        ),
        _PreferenceSwitch(
          value: settings.cacheSongs,
          title: 'Cache songs',
          subtitle: 'Keep streamed songs available for reuse',
          onChanged: (value) async {
            await backend.settings.setBool('cacheSongs', value);
            onChanged();
          },
        ),
        _PreferenceSwitch(
          value: settings.restorePlaybackSession,
          title: 'Restore session',
          subtitle: 'Remember queue and position after closing',
          onChanged: (value) async {
            await backend.settings.setBool('restrorePlaybackSession', value);
            onChanged();
          },
        ),
        _PreferenceSwitch(
          value: settings.cacheHomeScreenData,
          title: 'Cache Discover',
          subtitle: 'Reuse Discover content between app launches',
          onChanged: (value) async {
            await backend.settings.setBool('cacheHomeScreenData', value);
            onChanged();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Download location'),
          subtitle: Text(
            settings.downloadLocationPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Choose folder',
                icon: const Icon(Icons.folder_open_rounded),
                onPressed: () async {
                  final picked = await backend.settings.pickDownloadLocation();
                  if (!context.mounted) return;
                  if (picked != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Download folder updated')),
                    );
                    onChanged();
                  }
                },
              ),
              IconButton(
                tooltip: 'Reset folder',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: () async {
                  await backend.settings.resetDownloadLocation();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download folder reset')),
                  );
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({
    required this.backend,
    required this.settings,
    required this.onChanged,
  });

  final HarmonyBackend backend;
  final SettingsSnapshot settings;
  final VoidCallback onChanged;

  static const _languages = ['en', 'es', 'fr', 'de', 'hi', 'ja', 'ko', 'pt'];

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Language',
      children: [
        _PreferenceSelect<String>(
          title: 'App language',
          subtitle: 'Used on next app rebuild',
          value: _validLanguage(settings.appLanguageCode),
          values: _languages,
          labelBuilder: _languageName,
          onChanged: (value) async {
            await backend.settings.setAppLanguageCode(value);
            onChanged();
          },
        ),
        _PreferenceSelect<String>(
          title: 'Content language',
          subtitle: 'Affects YouTube Music requests',
          value: _validLanguage(settings.contentLanguageCode),
          values: _languages,
          labelBuilder: _languageName,
          onChanged: (value) async {
            await backend.settings.setContentLanguageCode(value);
            onChanged();
          },
        ),
      ],
    );
  }

  String _validLanguage(String value) {
    return _languages.contains(value) ? value : 'en';
  }

  String _languageName(String code) {
    switch (code) {
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'hi':
        return 'Hindi';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'pt':
        return 'Portuguese';
      case 'en':
      default:
        return 'English';
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.muted),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _PreferenceSelect<T> extends StatelessWidget {
  const _PreferenceSelect({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.muted),
      ),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        items: [
          for (final item in values)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder(item)),
            ),
        ],
      ),
    );
  }
}

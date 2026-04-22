import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'package:mp3tageditor/core/services/audio_editor_service.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/core/widgets/main_app_bar.dart';
import 'package:mp3tageditor/features/home/presentation/library_provider.dart';
import 'package:mp3tageditor/features/home/presentation/library_refresh_provider.dart';

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  Future<List<_ArtistGroup>> _loadArtists(
    WidgetRef ref,
    List<File> files,
  ) async {
    final service = ref.read(audioEditorServiceProvider);
    final grouped = <String, List<_TrackMeta>>{};

    for (final file in files) {
      try {
        final tag = await service.readTags(file.path);
        final artist = (tag?.trackArtist ?? '').trim();
        final album =
            (tag?.album ?? '').trim().isNotEmpty
                ? tag!.album!.trim()
                : 'Unknown Album';
        final fileName = file.path.split(RegExp(r'[\\/]')).last;
        final dot = fileName.lastIndexOf('.');
        final fallbackTitle = dot > 0 ? fileName.substring(0, dot) : fileName;
        final title =
            (tag?.title ?? '').trim().isNotEmpty
                ? tag!.title!.trim()
                : fallbackTitle;
        final imageBytes =
            (tag != null && tag.pictures.isNotEmpty)
                ? Uint8List.fromList(tag.pictures.first.bytes)
                : null;
        final key = artist.isEmpty ? 'Unknown Artist' : artist;
        grouped
            .putIfAbsent(key, () => <_TrackMeta>[])
            .add(
              _TrackMeta(
                file: file,
                title: title,
                artist: key,
                album: album,
                imageBytes: imageBytes,
              ),
            );
      } catch (_) {
        final fileName = file.path.split(RegExp(r'[\\/]')).last;
        final dot = fileName.lastIndexOf('.');
        final fallbackTitle = dot > 0 ? fileName.substring(0, dot) : fileName;
        grouped
            .putIfAbsent('Unknown Artist', () => <_TrackMeta>[])
            .add(
              _TrackMeta(
                file: file,
                title: fallbackTitle,
                artist: 'Unknown Artist',
                album: 'Unknown Album',
                imageBytes: null,
              ),
            );
      }
    }

    final result = <_ArtistGroup>[];
    final sorted =
        grouped.entries.toList()
          ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    for (final entry in sorted) {
      final tracks = [
        ...entry.value,
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final representative = tracks.firstWhere(
        (t) => t.imageBytes != null,
        orElse: () => tracks.first,
      );

      result.add(
        _ArtistGroup(
          name: entry.key,
          tracks: tracks,
          previewText: representative.album,
          imageBytes: representative.imageBytes,
        ),
      );
    }

    return result;
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    File file,
  ) async {
    final audioService = ref.read(audioEditorServiceProvider);
    final remaining = await audioService.getRemainingFreeEdits();

    if (!context.mounted) return;
    if (remaining == 0) {
      try {
        await RevenueCatUI.presentPaywallIfNeeded('premium');
        final newInfo = await audioService.purchaseService.getCustomerInfo();
        ref.read(customerInfoProvider.notifier).updateInfo(newInfo);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load subscriptions at this time.'),
            ),
          );
        }
      }

      final updatedRemaining = await audioService.getRemainingFreeEdits();
      if (updatedRemaining == 0) return;
    }

    if (!context.mounted) return;
    await context.push('/editor', extra: file.path);
    if (context.mounted) {
      ref.read(libraryRefreshProvider.notifier).markUpdated();
    }
  }

  Future<void> _showTracksSheet(
    BuildContext context,
    WidgetRef ref,
    _ArtistGroup group,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).padding.bottom;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${group.tracks.length} track(s)',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset + 8),
                    itemBuilder: (context, index) {
                      final track = group.tracks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: _RoundArtwork(
                          imageBytes: track.imageBytes,
                          fallbackLabel: track.title,
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(CupertinoIcons.pencil),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _openEditor(context, ref, track.file);
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: group.tracks.length,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(selectedFilesProvider);
    ref.watch(libraryRefreshProvider);

    return Scaffold(
      appBar: const MainAppBar(),
      body: FutureBuilder<List<_ArtistGroup>>(
        future: _loadArtists(ref, files),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final artists = snapshot.data ?? const <_ArtistGroup>[];
          if (artists.isEmpty) {
            return const Center(
              child: Text('No artists found. Import audio files first.'),
            );
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
            itemBuilder: (context, index) {
              final artist = artists[index];
              final subtitle =
                  '${artist.tracks.length} track(s) | ${artist.previewText}';

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _showTracksSheet(context, ref, artist),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.black.withOpacity(0.05),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            isDark
                                ? const [Color(0xFF252B3A), Color(0xFF1D2230)]
                                : const [Color(0xFFFFFFFF), Color(0xFFF2F5FA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDark
                                  ? Colors.black.withOpacity(0.26)
                                  : const Color(0xFF919EAB).withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Row(
                        children: [
                          _RoundArtwork(
                            imageBytes: artist.imageBytes,
                            fallbackLabel: artist.name,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  artist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 28,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF181A22),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.78)
                                            : const Color(0xFF4A5465),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MetaPill(
                                  icon: CupertinoIcons.person_2_fill,
                                  label: 'Open tracks',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFFECF1F9),
                            ),
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color:
                                  isDark
                                      ? Colors.white.withOpacity(0.85)
                                      : const Color(0xFF4A5465),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 1),
            itemCount: artists.length,
          );
        },
      ),
    );
  }
}

class _TrackMeta {
  final File file;
  final String title;
  final String artist;
  final String album;
  final Uint8List? imageBytes;

  const _TrackMeta({
    required this.file,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageBytes,
  });
}

class _ArtistGroup {
  final String name;
  final String previewText;
  final Uint8List? imageBytes;
  final List<_TrackMeta> tracks;

  const _ArtistGroup({
    required this.name,
    required this.previewText,
    required this.imageBytes,
    required this.tracks,
  });
}

class _RoundArtwork extends StatelessWidget {
  final Uint8List? imageBytes;
  final String fallbackLabel;

  const _RoundArtwork({required this.imageBytes, required this.fallbackLabel});

  @override
  Widget build(BuildContext context) {
    final initial =
        fallbackLabel.trim().isEmpty
            ? '?'
            : fallbackLabel.trim().characters.first.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 96,
        height: 96,
        child:
            imageBytes != null
                ? Image.memory(imageBytes!, fit: BoxFit.cover)
                : Container(
                  color: const Color(0xFF2F79B4),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color:
            isDark ? Colors.white.withOpacity(0.09) : const Color(0xFFEAF0FA),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? Colors.white70 : const Color(0xFF4A5465),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF4A5465),
            ),
          ),
        ],
      ),
    );
  }
}

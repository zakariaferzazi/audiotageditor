import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';

import 'package:mp3tageditor/core/services/audio_editor_service.dart';
import 'package:mp3tageditor/core/widgets/main_app_bar.dart';
import 'package:mp3tageditor/features/home/presentation/library_refresh_provider.dart';
import 'package:mp3tageditor/features/home/presentation/library_provider.dart';

class AudiosScreen extends ConsumerStatefulWidget {
  const AudiosScreen({super.key});

  @override
  ConsumerState<AudiosScreen> createState() => _AudiosScreenState();
}

class _AudiosScreenState extends ConsumerState<AudiosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Map<String, Tag?> _tagCache = {};
  int _lastRefreshTick = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });

    Future.microtask(() async {
      await ref.read(selectedFilesProvider.notifier).ensureLoaded();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMetadata(List<File> files, int refreshTick) async {
    if (_lastRefreshTick == refreshTick && _tagCache.length == files.length) {
      return;
    }

    if (_lastRefreshTick != refreshTick) {
      _lastRefreshTick = refreshTick;
      _tagCache.clear();
    }

    bool needsUpdate = false;
    for (final file in files) {
      if (!_tagCache.containsKey(file.path)) {
        try {
          _tagCache[file.path] = await ref
              .read(audioEditorServiceProvider)
              .readTags(file.path);
        } catch (_) {
          _tagCache[file.path] = null;
        }
        needsUpdate = true;
      }
    }

    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  List<File> _filtered(List<File> files) {
    if (_query.isEmpty) return files;
    return files.where((file) {
      final name = file.path.split(RegExp(r'[\\/]')).last.toLowerCase();
      final tag = _tagCache[file.path];
      final title = tag?.title?.toLowerCase() ?? '';
      final trackArtist = tag?.trackArtist?.toLowerCase() ?? '';
      final albumArtist = tag?.albumArtist?.toLowerCase() ?? '';
      final album = tag?.album?.toLowerCase() ?? '';

      return name.contains(_query) ||
          title.contains(_query) ||
          trackArtist.contains(_query) ||
          albumArtist.contains(_query) ||
          album.contains(_query);
    }).toList();
  }

  Future<void> _openEditor(File file) async {
    final audioService = ref.read(audioEditorServiceProvider);
    final remaining = await audioService.getRemainingFreeEdits();

    if (!mounted) return;
    if (remaining == 0) {
      try {
        await RevenueCatUI.presentPaywallIfNeeded("premium");
        final newInfo = await audioService.purchaseService.getCustomerInfo();
        ref.read(customerInfoProvider.notifier).updateInfo(newInfo);
      } catch (e) {
        if (mounted) {
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
    if (!mounted) return;
    await context.push('/editor', extra: file.path);
    if (mounted) {
      ref.read(libraryRefreshProvider.notifier).markUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(selectedFilesProvider);
    final refreshTick = ref.watch(libraryRefreshProvider);

    _loadMetadata(files, refreshTick);

    final items = _filtered(files);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MainAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search library',
                prefixIcon: const Icon(CupertinoIcons.search),
                filled: true,
                fillColor:
                    isDark
                        ? const Color(0xFF1F1A3B)
                        : Colors.black.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                items.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.music_note_list,
                              size: 62,
                              color: Colors.grey.withOpacity(0.55),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No Audio Files Yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Import tracks to build your library grid.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                    : GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        8,
                        8,
                        MediaQuery.paddingOf(context).bottom + 92,
                      ),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.70,
                          ),
                      itemBuilder: (context, index) {
                        final file = items[index];
                        return _AudioGridCard(
                          refreshTick: refreshTick,
                          file: file,
                          onTap: () => _openEditor(file),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _AudioGridCard extends ConsumerWidget {
  final File file;
  final int refreshTick;
  final VoidCallback onTap;

  const _AudioGridCard({
    required this.file,
    required this.refreshTick,
    required this.onTap,
  });

  Future<Tag?> _readTag(WidgetRef ref) async {
    try {
      return await ref.read(audioEditorServiceProvider).readTags(file.path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Tag?>(
      key: ValueKey('${file.path}-$refreshTick'),
      future: _readTag(ref),
      builder: (context, snapshot) {
        final tag = snapshot.data;
        final fileName = file.path.split(RegExp(r'[\\/]')).last;
        final dot = fileName.lastIndexOf('.');
        final fallbackTitle = dot > 0 ? fileName.substring(0, dot) : fileName;
        final title =
            tag?.title?.trim().isNotEmpty == true
                ? tag!.title!.trim()
                : fallbackTitle;
        final hasArt = tag != null && tag.pictures.isNotEmpty;
        final artist =
            tag?.trackArtist?.trim().isNotEmpty == true
                ? tag!.trackArtist!.trim()
                : 'Unknown';
        final album =
            tag?.album?.trim().isNotEmpty == true
                ? tag!.album!.trim()
                : 'Unknown Album';

        return Material(
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).cardColor,
          elevation: 0.6,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child:
                            hasArt
                                ? Image.memory(
                                  tag.pictures.first.bytes,
                                  fit: BoxFit.cover,
                                )
                                : Container(
                                  color: const Color(0xFF2F79B4),
                                  child: Center(
                                    child: Text(
                                      title.trim().isEmpty
                                          ? '?'
                                          : title.characters.first
                                              .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 64,
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black.withOpacity(0.5),
                          shape: const CircleBorder(),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                onTap();
                              } else if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Delete File'),
                                        content: const Text(
                                          'Are you sure you want to remove this file from your library?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm == true) {
                                  try {
                                    if (await file.exists()) {
                                      await file.delete();
                                    }
                                  } catch (_) {}
                                  ref
                                      .read(selectedFilesProvider.notifier)
                                      .removeFile(file);
                                  ref
                                      .read(libraryRefreshProvider.notifier)
                                      .markUpdated();
                                }
                              } else if (value == 'share') {
                                String sharePath = file.path;
                                if (title.isNotEmpty) {
                                  try {
                                    final originalExt =
                                        file.path
                                            .split(RegExp(r'[\\/]'))
                                            .last
                                            .split('.')
                                            .last;
                                    final safeTitle =
                                        title
                                            .replaceAll(
                                              RegExp(r'[<>:"/\\|?*]'),
                                              '_',
                                            )
                                            .trim();
                                    final newPath =
                                        '${Directory.systemTemp.path}/$safeTitle.$originalExt';
                                    await file.copy(newPath);
                                    sharePath = newPath;
                                  } catch (_) {}
                                }
                                await Share.shareXFiles([
                                  XFile(sharePath),
                                ], text: 'Here is my tagged audio file');
                              } else if (value == 'save') {
                                try {
                                  String finalName =
                                      title.isNotEmpty
                                          ? title
                                          : file.path
                                              .split(RegExp(r'[\\/]'))
                                              .last
                                              .split('.')
                                              .first;
                                  final originalExt =
                                      file.path
                                          .split(RegExp(r'[\\/]'))
                                          .last
                                          .split('.')
                                          .last;
                                  final safeTitle =
                                      finalName
                                          .replaceAll(
                                            RegExp(r'[<>:"/\\|?*]'),
                                            '_',
                                          )
                                          .trim();
                                  final suggestedName =
                                      '$safeTitle.$originalExt';

                                  final bytes = await file.readAsBytes();
                                  final String? outputFile =
                                      await FilePicker.saveFile(
                                        dialogTitle: 'Save Audio File',
                                        fileName: suggestedName,
                                        bytes: bytes,
                                      );

                                  if (outputFile != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'File saved successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to save file: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            itemBuilder:
                                (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'save',
                                    child: Text('Save Audio'),
                                  ),
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Text('Share'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.person_alt_circle,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.music_albums_fill,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                album,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

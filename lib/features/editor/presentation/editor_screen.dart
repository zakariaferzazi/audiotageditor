import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mp3tageditor/core/services/audio_editor_service.dart';
import 'package:mp3tageditor/core/services/shared_prefs_service.dart';
import 'package:mp3tageditor/core/widgets/shared_widgets.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String filePath;

  const EditorScreen({super.key, required this.filePath});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  static const _reviewAttemptsKey = 'review_prompt_attempts';

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _genreController = TextEditingController();
  final _yearController = TextEditingController();
  final _trackController = TextEditingController();

  File? _newArtwork;
  Tag? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(audioEditorServiceProvider);
    final tag = await service.readTags(widget.filePath);
    _existing = tag;
    if (tag != null) {
      _titleController.text = tag.title ?? '';
      _artistController.text = tag.trackArtist ?? '';
      _albumController.text = tag.album ?? '';
      _genreController.text = tag.genre ?? '';
      _yearController.text = tag.year?.toString() ?? '';
      _trackController.text = tag.trackNumber?.toString() ?? '';
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickArtwork() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _newArtwork = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(audioEditorServiceProvider);
    final pictures =
        _newArtwork != null
            ? [
              Picture(
                bytes: await _newArtwork!.readAsBytes(),
                mimeType:
                    _newArtwork!.path.toLowerCase().endsWith('.png')
                        ? MimeType.png
                        : MimeType.jpeg,
                pictureType: PictureType.coverFront,
              ),
            ]
            : (_existing?.pictures.map((p) {
                  // Ensure MimeType is NEVER null so ID3 APIC frames are not corrupted during re-write
                  return Picture(
                    bytes: p.bytes,
                    mimeType:
                        p.mimeType ??
                        (p.bytes.length > 3 && p.bytes[1] == 0x50
                            ? MimeType.png
                            : MimeType.jpeg),
                    pictureType: p.pictureType,
                  );
                }).toList() ??
                []);

    final tag = Tag(
      title:
          _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
      trackArtist:
          _artistController.text.trim().isEmpty
              ? null
              : _artistController.text.trim(),
      album:
          _albumController.text.trim().isEmpty
              ? null
              : _albumController.text.trim(),
      albumArtist: _existing?.albumArtist,
      genre:
          _genreController.text.trim().isEmpty
              ? null
              : _genreController.text.trim(),
      year:
          _yearController.text.trim().isEmpty
              ? null
              : _yearController.text.trim(),
      trackNumber:
          _trackController.text.trim().isEmpty
              ? null
              : int.tryParse(_trackController.text.trim()),
      trackTotal: _existing?.trackTotal,
      discNumber: _existing?.discNumber,
      discTotal: _existing?.discTotal,
      lyrics: _existing?.lyrics,
      duration: _existing?.duration,
      bpm: _existing?.bpm,
      pictures: pictures,
    );

    final ok = await service.writeTags(widget.filePath, tag);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Tags successfully applied.' : 'Failed to save tags.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (ok) {
      await _maybeAskForReviewAfterSuccessfulEdit();
      if (!mounted) return;
      // Clear image cache so the newly saved artwork appears immediately in grid views
      imageCache.clear();
      imageCache.clearLiveImages();

      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Success!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tags saved successfully.\nWhat would you like to do next?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.pop('home'),
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Home'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.pop('save'),
                          icon: const Icon(Icons.file_download),
                          label: const Text('Save File'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.pop('share'),
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      if (action == 'save') {
        await _exportOrShare();
        if (mounted) context.pop(true);
      } else if (action == 'share') {
        await _shareFile();
        if (mounted) context.pop(true);
      } else {
        context.pop(true);
      }
    }
  }

  Future<void> _shareFile() async {
    final title = _titleController.text.trim();
    String sharePath = widget.filePath;
    if (title.isNotEmpty) {
      try {
        final originalExt =
            widget.filePath.split(RegExp(r'[\\/]')).last.split('.').last;
        final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
        final newPath = '${Directory.systemTemp.path}/$safeTitle.$originalExt';
        await File(widget.filePath).copy(newPath);
        sharePath = newPath;
      } catch (_) {}
    }
    await Share.shareXFiles([
      XFile(sharePath),
    ], text: 'Here is my tagged audio file');
  }

  Future<void> _maybeAskForReviewAfterSuccessfulEdit() async {
    final prefs = ref.read(sharedPrefsServiceProvider);
    final attempts = prefs.getInt(_reviewAttemptsKey) ?? 0;
    if (attempts >= 2) return;

    final inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        await prefs.setInt(_reviewAttemptsKey, attempts + 1);
        await inAppReview.requestReview();
      }
    } catch (_) {
      // Silently drop if review prompt fails
    }
  }

  Future<void> _exportOrShare() async {
    final title = _titleController.text.trim();
    final file = File(widget.filePath);

    try {
      String finalName =
          title.isNotEmpty
              ? title
              : widget.filePath.split(RegExp(r'[\\/]')).last.split('.').first;
      final originalExt =
          widget.filePath.split(RegExp(r'[\\/]')).last.split('.').last;
      final safeTitle =
          finalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final suggestedName = '$safeTitle.$originalExt';

      final bytes = await file.readAsBytes();
      final String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Audio File',
        fileName: suggestedName,
        bytes: bytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export file: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(RegExp(r'[\\/]')).last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export / Share',
            onPressed: _exportOrShare,
          ),
        ],
      ),
      body:
          _loading
              ? const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    SkeletonLoader(height: 220),
                    SizedBox(height: 12),
                    SkeletonLoader(height: 48),
                    SizedBox(height: 12),
                    SkeletonLoader(height: 48),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 48,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // File Name Indicator
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.audio_file,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _pickArtwork,
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_newArtwork != null)
                                  Image.file(_newArtwork!, fit: BoxFit.cover)
                                else if (_existing != null &&
                                    (_existing!.pictures.isNotEmpty))
                                  Image.memory(
                                    _existing!.pictures.first.bytes,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  const Center(
                                    child: Icon(Icons.image, size: 64),
                                  ),
                                const Positioned(
                                  right: 12,
                                  top: 12,
                                  child: Icon(Icons.edit),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MetadataField(
                        label: 'Title',
                        controller: _titleController,
                        prefixIcon: Icons.title,
                        maxLength: 60,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Title is required'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      MetadataField(
                        label: 'Artist',
                        controller: _artistController,
                        prefixIcon: Icons.person,
                        maxLength: 50,
                      ),
                      const SizedBox(height: 12),
                      MetadataField(
                        label: 'Album',
                        controller: _albumController,
                        prefixIcon: Icons.album,
                        maxLength: 50,
                      ),
                      const SizedBox(height: 12),
                      MetadataField(
                        label: 'Genre',
                        controller: _genreController,
                        prefixIcon: Icons.music_note,
                        maxLength: 30,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: MetadataField(
                              label: 'Year',
                              controller: _yearController,
                              prefixIcon: Icons.date_range,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetadataField(
                              label: 'Track',
                              controller: _trackController,
                              prefixIcon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon:
                              _saving
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.save),
                          label: Text(_saving ? 'Saving...' : 'Save Changes'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _exportOrShare,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export Edited File'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

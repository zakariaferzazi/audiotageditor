import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mp3tageditor/core/services/shared_prefs_service.dart';

const _libraryPrefsKey = 'imported_audio_library_paths_v1';

class SelectedFilesNotifier extends Notifier<List<File>> {
  bool _loaded = false;

  @override
  List<File> build() {
    if (!_loaded) {
      Future.microtask(ensureLoaded);
    }
    return [];
  }

  Future<Directory> _libraryDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final library = Directory(
      '${docsDir.path}${Platform.pathSeparator}audio_library',
    );
    if (!library.existsSync()) {
      library.createSync(recursive: true);
    }
    return library;
  }

  String _safeFileName(String input) {
    final sanitized = input.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return sanitized.isEmpty ? 'audio' : sanitized;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final stored = prefs.getStringList(_libraryPrefsKey) ?? [];
    final existing =
        stored.map(File.new).where((file) => file.existsSync()).toList();

    state = existing;
    await prefs.setStringList(
      _libraryPrefsKey,
      existing.map((f) => f.path).toList(),
    );
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPrefsServiceProvider);
    await prefs.setStringList(
      _libraryPrefsKey,
      state.map((f) => f.path).toList(),
    );
  }

  Future<List<File>> addFiles(List<File> newFiles) async {
    await ensureLoaded();

    final libraryDir = await _libraryDirectory();
    final existingPaths = state.map((f) => f.path).toSet();
    final copied = <File>[];

    for (final source in newFiles) {
      if (!source.existsSync()) continue;

      final basename = source.path.split(RegExp(r'[\\/]')).last;
      final dot = basename.lastIndexOf('.');
      final rawName = dot > 0 ? basename.substring(0, dot) : basename;
      final ext = dot > 0 ? basename.substring(dot) : '';
      final safeName = _safeFileName(rawName);

      var targetPath =
          '${libraryDir.path}${Platform.pathSeparator}$safeName$ext';
      var suffix = 1;
      while (File(targetPath).existsSync()) {
        targetPath =
            '${libraryDir.path}${Platform.pathSeparator}$safeName ($suffix)$ext';
        suffix++;
      }

      final copiedFile = await source.copy(targetPath);
      if (!existingPaths.contains(copiedFile.path)) {
        copied.add(copiedFile);
        existingPaths.add(copiedFile.path);
      }
    }

    if (copied.isEmpty) return [];

    state = [...state, ...copied];
    await _persist();
    return copied;
  }

  Future<void> removeFile(File file) async {
    await ensureLoaded();
    state = state.where((f) => f.path != file.path).toList();
    await _persist();
  }

  Future<void> clearLibrary() async {
    await ensureLoaded();

    for (final file in state) {
      try {
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (_) {}
    }

    try {
      final libraryDir = await _libraryDirectory();
      if (libraryDir.existsSync()) {
        await libraryDir.delete(recursive: true);
      }
    } catch (_) {}

    state = [];
    await _persist();
  }
}

final selectedFilesProvider =
    NotifierProvider<SelectedFilesNotifier, List<File>>(() {
      return SelectedFilesNotifier();
    });

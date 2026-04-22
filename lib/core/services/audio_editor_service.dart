import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/core/services/shared_prefs_service.dart';

final audioEditorServiceProvider = Provider<AudioEditorService>((ref) {
  return AudioEditorService(ref);
});

class AudioFileState {
  final File file;
  final Tag? tag;

  AudioFileState({required this.file, this.tag});
}

class AudioEditorService {
  final Ref ref;

  AudioEditorService(this.ref);

  Future<void> consumeFreeUse() async {
    final hasPremium = await purchaseService.hasPremium();
    if (hasPremium) return;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final edits = prefs.getInt('free_edits_done') ?? 0;
    await prefs.setInt('free_edits_done', edits + 1);
  }

  Future<Tag?> readTags(String filePath) async {
    try {
      return await AudioTags.read(filePath);
    } catch (e) {
      print('Error reading tags: $e');
    }
    return null;
  }

  Future<bool> writeTags(String filePath, Tag newTag) async {
    try {
      await AudioTags.write(filePath, newTag);

      await consumeFreeUse();

      return true;
    } catch (e) {
      print('Error writing tags: $e');
      return false;
    }
  }

  PurchaseService get purchaseService => ref.read(purchaseServiceProvider);

  Future<int> getRemainingFreeEdits() async {
    final hasPremium = await purchaseService.hasPremium();
    if (hasPremium) return -1;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final editsDone = prefs.getInt('free_edits_done') ?? 0;
    final remaining = 1 - editsDone;
    return remaining > 0 ? remaining : 0;
  }
}

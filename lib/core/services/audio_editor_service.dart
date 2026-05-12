import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_audio_tagger/flutter_audio_tagger.dart';
import 'package:flutter_audio_tagger/tag.dart' as fat_tag;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/core/services/shared_prefs_service.dart';

// Mock types to maintain UI compatibility with old audiotags package
enum PictureType { coverFront, other }

enum MimeType { png, jpeg, none }

class Picture {
  final Uint8List bytes;
  final PictureType? pictureType;
  final MimeType? mimeType;

  Picture({
    required this.bytes,
    this.pictureType = PictureType.other,
    this.mimeType = MimeType.none,
  });
}

class Tag {
  String? title;
  String? trackArtist;
  String? albumArtist;
  String? album;
  int? trackNumber;
  int? trackTotal;
  int? discNumber;
  int? discTotal;
  String? year;
  String? genre;
  String? lyrics;
  int? duration;
  int? bpm;
  List<Picture> pictures;

  Tag({
    this.title,
    this.trackArtist,
    this.albumArtist,
    this.album,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.year,
    this.genre,
    this.lyrics,
    this.duration,
    this.bpm,
    this.pictures = const [],
  });
}

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
  final FlutterAudioTagger _tagger = FlutterAudioTagger();
  static const int _maxFreeEdits = 3;
  static const int _maxFreeCreations = 3;

  AudioEditorService(this.ref);

  // Increments the free edit counter (writing tags).
  Future<void> consumeFreeUse() async {
    final hasPremium = await purchaseService.hasPremium();
    if (hasPremium) return;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final edits = prefs.getInt('free_edits_done') ?? 0;
    await prefs.setInt('free_edits_done', edits + 1);
  }

  // Increments the free creation/import counter.
  Future<void> consumeFreeCreation() async {
    final hasPremium = await purchaseService.hasPremium();
    if (hasPremium) return;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final creations = prefs.getInt('free_creations_done') ?? 0;
    await prefs.setInt('free_creations_done', creations + 1);
  }

  Future<Tag?> readTags(String filePath) async {
    try {
      final fatTag = await _tagger.getAllTags(filePath);
      if (fatTag == null) return null;

      List<Picture> pics = [];
      if (fatTag.artwork != null && fatTag.artwork!.isNotEmpty) {
        pics = [Picture(bytes: fatTag.artwork!)];
      }

      int? trackNum;

      return Tag(
        title: fatTag.title,
        trackArtist: fatTag.artist,
        albumArtist: fatTag.artist, // map fallback
        album: fatTag.album,
        year: fatTag.year,
        genre: fatTag.genre,
        trackNumber: trackNum,
        pictures: pics,
      );
    } catch (e) {
      print('Error reading tags: $e');
    }
    return null;
  }

  Future<bool> writeTags(String filePath, Tag newTag) async {
    try {
      Uint8List? artwork;
      if (newTag.pictures.isNotEmpty) {
        artwork = newTag.pictures.first.bytes;
      }

      final fatTag = fat_tag.Tag(
        title: newTag.title,
        artist: newTag.trackArtist ?? newTag.albumArtist,
        album: newTag.album,
        year: newTag.year,
        genre: newTag.genre,
        artwork: artwork,
      );

      final fileData = await _tagger.editTagsAndArtwork(fatTag, filePath);

      // flutter_audio_tagger native plugin returns the entire edited file bytes.
      // We overwrite the original file with the new tagged bytes.
      final file = File(filePath);
      await file.writeAsBytes(fileData.musicData);

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
    final remaining = _maxFreeEdits - editsDone;
    return remaining > 0 ? remaining : 0;
  }

  Future<int> getRemainingFreeCreations() async {
    final hasPremium = await purchaseService.hasPremium();
    if (hasPremium) return -1;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final creationsDone = prefs.getInt('free_creations_done') ?? 0;
    final remaining = _maxFreeCreations - creationsDone;
    return remaining > 0 ? remaining : 0;
  }
}

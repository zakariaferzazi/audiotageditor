import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'package:mp3tageditor/core/services/audio_editor_service.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/features/home/presentation/library_refresh_provider.dart';
import 'package:mp3tageditor/features/home/presentation/library_provider.dart';

class MainAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onActionTap;
  final IconData actionIcon;

  const MainAppBar({
    super.key,
    this.onActionTap,
    this.actionIcon = Icons.add_circle_outline,
  });

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final audioService = ref.read(audioEditorServiceProvider);
    final remaining = await audioService.getRemainingFreeEdits();
    if (remaining == 0) {
      if (context.mounted) {
        try {
          await RevenueCatUI.presentPaywallIfNeeded("premium");
          final newInfo = await audioService.purchaseService.getCustomerInfo();
          ref.read(customerInfoProvider.notifier).updateInfo(newInfo);
        } catch (e) {
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
      } else {
        return;
      }
    }

    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result == null || result.paths.isEmpty) return;

    final sourceFiles = result.paths.whereType<String>().map(File.new).toList();
    final imported = await ref
        .read(selectedFilesProvider.notifier)
        .addFiles(sourceFiles);

    if (imported.isNotEmpty) {
      await audioService.consumeFreeUse();
    }

    if (!context.mounted || imported.isEmpty) return;

    await context.push('/editor', extra: imported.first.path);
    if (!context.mounted) return;

    ref.read(libraryRefreshProvider.notifier).markUpdated();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor =
        isDark ? Colors.white10 : Colors.black.withOpacity(0.05);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Logo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.music_note,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),

            // Center: Text
            const Text(
              'Audio Tagger',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            // Right: Screen action icon
            GestureDetector(
              onTap: onActionTap ?? () => _importFiles(context, ref),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  actionIcon,
                  color: isDark ? Colors.white : Colors.black,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

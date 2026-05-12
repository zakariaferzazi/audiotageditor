import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'package:mp3tageditor/core/services/audio_editor_service.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/features/home/presentation/library_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(selectedFilesProvider);
    final audioService = ref.read(audioEditorServiceProvider);

    Future<void> requirePaidAccessForEdit() async {
      final remaining = await audioService.getRemainingFreeEdits();
      if (remaining != 0) return;

      if (!context.mounted) return;
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
      if (updatedRemaining == 0 && context.mounted) {
        return;
      }
    }

    Future<void> requirePaidAccessForCreation() async {
      final remaining = await audioService.getRemainingFreeCreations();
      if (remaining != 0) return;

      if (!context.mounted) return;
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

      final updatedRemaining = await audioService.getRemainingFreeCreations();
      if (updatedRemaining == 0 && context.mounted) {
        return;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Tag Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium),
            onPressed: () async {
              await RevenueCatUI.presentPaywallIfNeeded('premium');
              final newInfo =
                  await audioService.purchaseService.getCustomerInfo();
              ref.read(customerInfoProvider.notifier).updateInfo(newInfo);
            },
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body:
          files.isEmpty
              ? const Center(
                child: Text(
                  'No audio files imported.\nTap the button below to start.',
                  textAlign: TextAlign.center,
                ),
              )
              : ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.audio_file)),
                    title: Text(file.path.split('/').last),
                    subtitle: const Text('Tap to edit tags'),
                    onTap: () async {
                      await requirePaidAccessForEdit();
                      if (!context.mounted) return;
                      final remaining =
                          await audioService.getRemainingFreeEdits();
                      if (remaining == 0) return;
                      await context.push('/editor', extra: file.path);
                      if (context.mounted) {
                        // ignore: unused_result
                        ref.refresh(selectedFilesProvider);
                      }
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await requirePaidAccessForCreation();
          if (!context.mounted) return;
          if (await audioService.getRemainingFreeCreations() == 0) return;

          final result = await FilePicker.pickFiles(
            type: FileType.audio,
            allowMultiple: true,
          );

          if (result == null || result.paths.isEmpty) return;

          final newFiles =
              result.paths.whereType<String>().map((p) => File(p)).toList();
          final imported = await ref
              .read(selectedFilesProvider.notifier)
              .addFiles(newFiles);
          if (imported.isNotEmpty) {
            await audioService.consumeFreeCreation();
          }
        },
        label: const Text('Import Audio'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'package:mp3tageditor/core/services/audio_editor_service.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/features/home/presentation/albums_screen.dart';
import 'package:mp3tageditor/features/home/presentation/artists_screen.dart';
import 'package:mp3tageditor/features/home/presentation/audios_screen.dart';
import 'package:mp3tageditor/features/home/presentation/library_refresh_provider.dart';
import 'package:mp3tageditor/features/home/presentation/library_provider.dart';
import 'package:mp3tageditor/features/settings/presentation/settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AudiosScreen(),
    AlbumsScreen(),
    ArtistsScreen(),
    SettingsScreen(),
  ];

  Future<void> _importFromCenterButton() async {
    final audioService = ref.read(audioEditorServiceProvider);
    final remaining = await audioService.getRemainingFreeEdits();
    if (remaining == 0) {
      if (mounted) {
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

    if (!mounted || imported.isEmpty) return;

    setState(() {
      _currentIndex = 0;
    });

    await context.push('/editor', extra: imported.first.path);
    if (!mounted) return;

    ref.read(libraryRefreshProvider.notifier).markUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarColor =
        isDark ? const Color(0xFF1A1C29) : const Color(0xFFDCE4EF);

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _importFromCenterButton,
        backgroundColor: Color(0xFF6C4DDA),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      bottomNavigationBar: BottomAppBar(
        color: navBarColor,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          CircleBorder(),
        ),
        notchMargin: 8.0,
        height: 70,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavTab(
              icon: CupertinoIcons.music_note,
              activeIcon: CupertinoIcons.music_note_list,
              label: 'Audios',
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavTab(
              icon: CupertinoIcons.music_albums,
              activeIcon: CupertinoIcons.music_albums_fill,
              label: 'Albums',
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(width: 48), // Space for the FAB
            _NavTab(
              icon: CupertinoIcons.person_3,
              activeIcon: CupertinoIcons.person_3_fill,
              label: 'Artists',
              selected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavTab(
              icon: CupertinoIcons.settings,
              activeIcon: CupertinoIcons.settings_solid,
              label: 'Settings',
              selected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color:
                  selected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).unselectedWidgetColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    selected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).unselectedWidgetColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

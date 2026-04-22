import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mp3tageditor/core/theme/theme_provider.dart';
import 'package:mp3tageditor/core/services/purchase_service.dart';
import 'package:mp3tageditor/core/widgets/main_app_bar.dart';
import 'package:mp3tageditor/features/home/presentation/library_provider.dart';

const _supportEmail = 'zakariaferzazi24.04.2000@gmail.com';
const _androidPackageId = 'com.apps.audio.tag.editor';
const _iosStoreId = '0000000000';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openUri(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this action right now.')),
      );
    }
  }

  Future<void> _requestRateApp(BuildContext context) async {
    final inAppReview = InAppReview.instance;

    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return;
      }

      if (Platform.isAndroid) {
        await inAppReview.openStoreListing();
        return;
      }

      if (Platform.isIOS) {
        await inAppReview.openStoreListing(appStoreId: _iosStoreId);
        return;
      }
    } catch (_) {
      // Fall back to URL launch below.
    }

    final fallbackUri =
        Platform.isAndroid
            ? Uri.parse(
              'https://play.google.com/store/apps/details?id=$_androidPackageId',
            )
            : Uri.parse('https://apps.apple.com/app/id$_iosStoreId');
    if (!context.mounted) return;
    await _openUri(context, fallbackUri);
  }

  Future<void> _resetAppData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset App Data'),
          content: const Text(
            'This will remove all imported audio files from the app library only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await ref.read(selectedFilesProvider.notifier).clearLibrary();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App data has been reset.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final customerInfo = ref.watch(customerInfoProvider);
    final isPremium =
        customerInfo?.entitlements.all['premium']?.isActive ?? false;

    return Scaffold(
      appBar: const MainAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(mode == ThemeMode.dark ? 'Enabled' : 'Disabled'),
              value: mode == ThemeMode.dark,
              onChanged: (value) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child:
                isPremium
                    ? ListTile(
                      leading: const Icon(
                        Icons.workspace_premium,
                        color: Color.fromARGB(255, 202, 115, 0),
                      ),
                      title: const Text('Pro Activated'),
                      subtitle: const Text(
                        'You have full access to all features',
                      ),
                    )
                    : ListTile(
                      leading: const Icon(
                        Icons.workspace_premium,
                        color: Color.fromARGB(255, 202, 115, 0),
                      ),
                      title: const Text('Go Premium'),
                      subtitle: const Text('Unlock full editing features'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await RevenueCatUI.presentPaywallIfNeeded("premium");
                      },
                    ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Reset App Data'),
                  subtitle: const Text(
                    'Clear all imported audios from the app',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _resetAppData(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.star_rate),
                  title: const Text('Rate App'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _requestRateApp(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Contact Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: _supportEmail,
                      queryParameters: {'subject': 'MP3TagEditor Support'},
                    );
                    _openUri(context, uri);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Report Bug'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: _supportEmail,
                      queryParameters: {'subject': 'MP3TagEditor Bug Report'},
                    );
                    _openUri(context, uri);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

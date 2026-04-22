import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/shared_prefs_service.dart';
import 'core/services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPrefsService = SharedPrefsService();
  await sharedPrefsService.init();

  final purchaseService = PurchaseService();
  await purchaseService.init();
  final initialCustomerInfo = await purchaseService.getCustomerInfo();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsServiceProvider.overrideWithValue(sharedPrefsService),
        purchaseServiceProvider.overrideWithValue(purchaseService),
        customerInfoProvider.overrideWith(() {
          final notifier = CustomerInfoNotifier();
          Future.microtask(() => notifier.updateInfo(initialCustomerInfo));
          return notifier;
        }),
      ],
      child: const MP3TagEditorApp(),
    ),
  );
}

class MP3TagEditorApp extends ConsumerWidget {
  const MP3TagEditorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Mp3 Tag Editor',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/storage/session_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await Future.wait([
    SessionStore.instance.load(),
    ThemeController.instance.load(),
  ]);
  runApp(const GsmartApp());
}

class GsmartApp extends StatelessWidget {
  const GsmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => MaterialApp.router(
        title: 'Smart24',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeController.instance.mode,
        routerConfig: AppRouter.router,
      ),
    );
  }
}

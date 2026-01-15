import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/config/app_config.dart';
import 'package:prescription_scanner/presentation/theme/theme.dart';
import 'package:prescription_scanner/presentation/pages/home/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prescription_scanner/config/env.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/config/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        supabaseProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const PrescriptionScannerApp(),
    ),
  );
}

class PrescriptionScannerApp extends ConsumerWidget {
  const PrescriptionScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

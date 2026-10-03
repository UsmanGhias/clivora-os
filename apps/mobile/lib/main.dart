import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  if (!kSupabaseConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(
    url: kSupabaseUrl,
    publishableKey: kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const ProviderScope(child: ClivoraApp()));
}

/// Shown when the app was built without a backend, instead of crashing on start.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CLIVORA needs a backend', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 12),
                Text(
                  'This build has no Supabase URL or anon key. Start a local stack with '
                  '`supabase start`, copy env/local.example.json to env/local.json, fill in '
                  'the values it prints, then run:\n\n'
                  'flutter run --dart-define-from-file=env/local.json\n\n'
                  'Full steps are in docs/self-hosting.md.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

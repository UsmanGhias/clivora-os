/// Supabase connection for this CLIVORA build.
///
/// Values are supplied at build time, for example:
///   flutter run --dart-define-from-file=env/local.json
/// See env/local.example.json and docs/self-hosting.md. Nothing here points at
/// a hosted project, so a fresh checkout can only talk to a backend you run.
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');

/// Public anon (or publishable) key of your Supabase project.
const kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Optional newer-style publishable key.
const kSupabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Project reference, used to build storage and function URLs.
const kSupabaseProjectRef = String.fromEnvironment('SUPABASE_PROJECT_REF', defaultValue: 'local');

/// True when the build was given a backend to connect to.
bool get kSupabaseConfigured => kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

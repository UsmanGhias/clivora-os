/// Deployment settings for this CLIVORA build, supplied with --dart-define.
///
/// The Community edition ships without the in-app admin console, so no account
/// is granted elevated rights by email.
const kAdminEmails = <String>{};

/// Only this account could grant admin rights. Empty in the Community edition.
const kSuperAdminEmail = '';

/// Support address shown in the app.
const kOfficialEmail = String.fromEnvironment('CLIVORA_SUPPORT_EMAIL', defaultValue: 'support@example.com');

/// Base URL of your CLIVORA web deployment (public invoice links, password reset, reviews).
const kClivoraWebBaseUrl = String.fromEnvironment('CLIVORA_WEB_URL', defaultValue: 'http://localhost:3000');

/// Supabase password-reset emails redirect here. Add it under
/// Supabase Auth, URL Configuration, Redirect URLs.
const kPasswordResetRedirectUrl = '$kClivoraWebBaseUrl/auth/reset-password';

/// Android application id of this build. Change it before publishing your own fork.
const kAppPackageId = String.fromEnvironment('CLIVORA_APP_ID', defaultValue: 'org.codcrafters.clivora.community');

/// Store listing for your build, if you publish one. Leave empty for self-built apps.
const kAppStoreUrl = String.fromEnvironment('CLIVORA_APP_STORE_URL');

/// Source repository, used for "share" and "rate" when no store listing is set.
const kProjectUrl = String.fromEnvironment('CLIVORA_PROJECT_URL', defaultValue: 'https://github.com/UsmanGhias/clivora-os');

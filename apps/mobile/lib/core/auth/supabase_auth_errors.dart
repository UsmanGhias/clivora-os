import 'package:supabase_flutter/supabase_flutter.dart';

/// User-friendly messages for Supabase Auth errors.
String supabaseAuthErrorMessage(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
    return 'Incorrect email or password. If you signed up with Google, use Continue with Google.';
  }
  if (msg.contains('already registered') || msg.contains('already exists')) {
    return 'An account with this email already exists. Sign in instead.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Please confirm your email, or disable email confirmation in Supabase for testing.';
  }
  if (msg.contains('password')) {
    return 'Password must be at least 6 characters.';
  }
  if (msg.contains('rate limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  return e.message;
}

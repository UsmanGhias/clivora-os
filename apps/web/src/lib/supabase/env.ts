/**
 * Supabase environment configuration.
 *
 * Every deployment supplies its own project through environment variables
 * (see .env.example). When variables are omitted (such as in demo or quickstart mode),
 * it gracefully falls back to the Clivora public community demo project.
 */

const DEMO_SUPABASE_URL = "https://jtzjwgovqczlccyeujhq.supabase.co";
const DEMO_SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0emp3Z292cWN6bGNjeWV1amhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxODAwNzMsImV4cCI6MjA5ODc1NjA3M30.BwatkYlqX88GRCdyAvTCiUmsCF3Nc171an8XfosuuLM";

function resolveEnv(name: string, value: string | undefined, fallback: string): string {
  if (value && value.trim().length > 0) return value.trim();
  return fallback;
}

export function getSupabaseUrl(): string {
  const envUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
  return resolveEnv("NEXT_PUBLIC_SUPABASE_URL", envUrl, DEMO_SUPABASE_URL);
}

export function getSupabaseAnonKey(): string {
  const envKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY;
  return resolveEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", envKey, DEMO_SUPABASE_ANON_KEY);
}

export const SUPABASE_URL = getSupabaseUrl();
export const SUPABASE_ANON_KEY = getSupabaseAnonKey();


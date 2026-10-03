/**
 * Supabase environment configuration.
 *
 * Every deployment supplies its own project through environment variables
 * (see .env.example). There is deliberately no fallback to a hosted project:
 * a missing value should fail loudly rather than connect somewhere unexpected.
 */
function required(name: string, value: string | undefined): string {
  if (value) return value;
  if (process.env.NODE_ENV === "production" && !process.env.NEXT_PHASE) {
    throw new Error(`${name} is not set. Copy .env.example to .env.local and fill it in.`);
  }
  // Local development and builds without a backend: point at a local Supabase stack.
  return name.endsWith("_URL") ? "http://127.0.0.1:54321" : "";
}

export function getSupabaseUrl(): string {
  return required("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL);
}

export function getSupabaseAnonKey(): string {
  return required(
    "NEXT_PUBLIC_SUPABASE_ANON_KEY",
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY,
  );
}

export const SUPABASE_URL = getSupabaseUrl();
export const SUPABASE_ANON_KEY = getSupabaseAnonKey();

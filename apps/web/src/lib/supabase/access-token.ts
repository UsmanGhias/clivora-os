import { createClient } from "@/lib/supabase/client";

/**
 * Confirm the browser user with the Auth server (not cookie storage alone).
 */
export async function assertClientUser() {
  const supabase = createClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();
  if (error || !user) {
    throw new Error("Sign in again.");
  }
  return user;
}

/**
 * Access token for admin API Bearer fallback.
 * Always verifies with getUser() first; never uses session.user.
 */
export async function getVerifiedAccessToken(): Promise<string | null> {
  await assertClientUser();
  const supabase = createClient();
  const { data } = await supabase.auth.getSession();
  return data.session?.access_token ?? null;
}

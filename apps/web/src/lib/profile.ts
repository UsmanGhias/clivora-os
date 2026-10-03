import { createClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/profile-types";
import { earlyAccessPlanForSignup } from "@/lib/early-access";

export type { Profile, AccountType } from "@/lib/profile-types";
export {
  isClientAccount,
  isPro,
  isProPlus,
  planLabel,
} from "@/lib/plan";

export async function getSessionUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export async function getProfile(): Promise<Profile | null> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  // profiles has updated_at but no created_at - selecting created_at 400s and used to
  // fall through to a fake Free row (never demote paid plans on query failure).
  const { data, error } = await supabase
    .from("profiles")
    .select(
      "id, email, name, account_type, subscription_plan, role, is_blocked, is_restricted, block_reason, avatar_url, updated_at",
    )
    .eq("id", user.id)
    .maybeSingle();

  if (error) {
    console.error("getProfile select failed", error.message);
    // Keep the session; never invent Free on a query failure (that demoted Pro users).
    const metaPlan = user.user_metadata?.subscription_plan as string | undefined;
    return {
      id: user.id,
      email: user.email ?? null,
      name: (user.user_metadata?.name as string | undefined) ?? null,
      account_type: (user.user_metadata?.account_type as string | undefined) ?? "freelancer",
      subscription_plan: metaPlan ?? null,
      is_blocked: false,
      is_restricted: false,
    };
  }
  if (data) return data as Profile;

  // Only invent a row shape when no profile exists yet - never demote paid plans.
  return {
    id: user.id,
    email: user.email ?? null,
    name: (user.user_metadata?.name as string | undefined) ?? null,
    account_type: (user.user_metadata?.account_type as string | undefined) ?? "freelancer",
    subscription_plan: earlyAccessPlanForSignup(),
    is_blocked: false,
    is_restricted: false,
  };
}

export function isBlocked(profile: Profile | null) {
  return profile?.is_blocked === true;
}

export function isRestricted(profile: Profile | null) {
  return profile?.is_restricted === true;
}

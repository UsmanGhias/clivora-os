import type { Profile } from "@/lib/profile-types";

export type { Profile, AccountType } from "@/lib/profile-types";

/**
 * CLIVORA Community has no paid tiers. Every account can use every feature, so
 * the plan checks below always pass. The helpers keep their signatures so the
 * rest of the app (and any fork that adds billing) can rely on them.
 */
export const COMMUNITY_EDITION = true;

export function isClientAccount(profile: Profile | null) {
  return (profile?.account_type ?? "").toLowerCase() === "client";
}

export function hasPaidPro(_profile: Profile | null) {
  return true;
}

export function hasPaidProPlus(_profile: Profile | null) {
  return true;
}

export function paidPlanLabel(_profile: Profile | null) {
  return "Community";
}

export function isProPlus(_profile: Profile | null) {
  return true;
}

export function isPro(_profile: Profile | null) {
  return true;
}

export function planLabel(_profile: Profile | null) {
  return "Community";
}

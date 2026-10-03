export type ConnectProfile = {
  id: string;
  user_id: string;
  display_title: string | null;
  headline: string | null;
  bio?: string | null;
  skills: string[] | string | null;
  rate_band: string | null;
  availability?: string | null;
  location_label?: string | null;
  is_listed: boolean | null;
  is_verified: boolean | null;
  moderation_status: string | null;
  account_type: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  avg_rating?: number | null;
  review_count?: number | null;
  completion_rate?: number | null;
  reputation_score?: number | null;
  profile_completeness?: number | null;
  /** Joined from profiles.avatar_url for talent cards */
  avatar_url?: string | null;
};

export type ConnectNeed = {
  id: string;
  client_user_id: string;
  title: string | null;
  summary: string | null;
  skills: string[] | string | null;
  budget_band: string | null;
  is_open: boolean | null;
  moderation_status: string | null;
  created_at: string | null;
  company_name?: string | null;
  company_email?: string | null;
  job_id?: string | null;
  seo_slug?: string | null;
  location?: string | null;
  is_direct_client?: boolean | null;
};

export type ConnectRequestRow = {
  id: string;
  from_user_id: string;
  to_user_id: string;
  target_profile_id: string | null;
  target_need_id: string | null;
  message: string;
  status: string;
  revealed_at: string | null;
  created_at: string;
  from_email?: string | null;
  to_email?: string | null;
  from_name?: string | null;
  to_name?: string | null;
};

export function skillsList(skills: string[] | string | null | undefined): string[] {
  if (!skills) return [];
  if (Array.isArray(skills)) return skills.map(String);
  try {
    const parsed = JSON.parse(skills);
    if (Array.isArray(parsed)) return parsed.map(String);
  } catch {
    /* ignore */
  }
  return skills
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

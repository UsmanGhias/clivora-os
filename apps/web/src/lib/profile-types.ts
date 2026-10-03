export type AccountType = "freelancer" | "client" | "admin";

export type Profile = {
  id: string;
  email: string | null;
  name: string | null;
  account_type: string | null;
  subscription_plan: string | null;
  role?: string | null;
  is_blocked?: boolean | null;
  is_restricted?: boolean | null;
  block_reason?: string | null;
  avatar_url?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

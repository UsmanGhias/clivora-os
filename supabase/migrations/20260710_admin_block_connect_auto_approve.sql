-- Admin moderation: block/restrict users + Connect auto-approve setting
-- Applied via Supabase MCP on 2026-07-10

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_restricted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS block_reason text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS blocked_at timestamptz,
  ADD COLUMN IF NOT EXISTS blocked_by uuid;

CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_read ON public.app_settings;
CREATE POLICY app_settings_read ON public.app_settings
  FOR SELECT TO authenticated
  USING (true);

INSERT INTO public.app_settings (key, value)
VALUES
  ('connect_auto_approve', '{"enabled": true}'::jsonb),
  ('connect_auto_approve_profiles', '{"enabled": true}'::jsonb),
  ('connect_auto_approve_needs', '{"enabled": true}'::jsonb)
ON CONFLICT (key) DO NOTHING;

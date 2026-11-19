-- Migration: 20261119_performance_indexes.sql
-- Description: Composite performance indexes for dashboard queries and high-volume lookups.
-- Conforms to Ponytail performance optimizations.

-- 1. Proposals: Filter by client (to_user_id) or freelancer (from_user_id) sorted by created_at DESC
CREATE INDEX IF NOT EXISTS idx_connect_proposals_to_user_created
  ON public.connect_proposals(to_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_connect_proposals_from_user_created
  ON public.connect_proposals(from_user_id, created_at DESC);

-- 2. Milestones: Filter by client or freelancer scoped by status and created_at DESC
CREATE INDEX IF NOT EXISTS idx_connect_milestones_client_status
  ON public.connect_milestones(client_user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_connect_milestones_freelancer_status
  ON public.connect_milestones(freelancer_user_id, status, created_at DESC);

-- 3. Events: System event auditing and chronologically sorted telemetry
CREATE INDEX IF NOT EXISTS idx_clivora_events_created_at
  ON public.clivora_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clivora_events_type_created
  ON public.clivora_events(event_type, created_at DESC);

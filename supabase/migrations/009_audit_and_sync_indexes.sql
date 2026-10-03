-- Audit event indexing and platform feature support (v2.4.0)

CREATE INDEX IF NOT EXISTS idx_clivora_events_audit
  ON public.clivora_events (event_type, created_at DESC)
  WHERE event_type LIKE 'audit_%';

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_uid, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_invoice_shares_freelancer_updated
  ON public.invoice_shares (freelancer_uid, updated_at DESC);

COMMENT ON TABLE public.clivora_events IS 'Analytics and audit trail mirrored from mobile app and web admin sync';

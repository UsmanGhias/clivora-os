-- Relocate pg_trgm extension from public to extensions schema for Supabase security compliance
ALTER EXTENSION pg_trgm SET SCHEMA extensions;

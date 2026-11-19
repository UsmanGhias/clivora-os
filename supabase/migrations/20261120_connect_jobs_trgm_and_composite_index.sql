-- Migration: 20261120_connect_jobs_trgm_and_composite_index.sql
-- Enable pg_trgm for sub-millisecond trigram ILIKE search and add composite status/created_at index

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN trigram index for multi-column ILIKE search across job titles and descriptions
CREATE INDEX IF NOT EXISTS idx_jobs_search_trgm 
  ON public.connect_jobs USING gin (title gin_trgm_ops, description gin_trgm_ops);

-- Composite B-Tree index for marketplace feed ordering and status filtering
CREATE INDEX IF NOT EXISTS idx_jobs_status_created_at 
  ON public.connect_jobs (status, created_at DESC);

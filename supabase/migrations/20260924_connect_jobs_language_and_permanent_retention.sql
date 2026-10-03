-- CLIVORA Connect Jobs — Language Partitioning & Permanent Retention
-- Migration: 20260924_connect_jobs_language_and_permanent_retention.sql

begin;

-- Add language column (en, de, fr, es) with default 'en'
alter table public.connect_jobs
  add column if not exists language text not null default 'en';

-- Create performance index on language for filtered job board queries
create index if not exists connect_jobs_language_idx
  on public.connect_jobs (language) where is_public = true and status = 'published';

-- Backfill detected language based on content tokens
update public.connect_jobs
set language = case 
    when (title || ' ' || left(description, 1000)) ~* '\y(der|die|das|und|von|mit|sich|f[üu]r|eine|einer|einem|unser|ihre|aufgaben|wir suchen|[üu]ber uns|standort)\y' then 'de'
    when (title || ' ' || left(description, 1000)) ~* '\y(le|la|les|des|du|dans|pour|avec|vous|nous|missions|[ée]quipe|entreprise|gestionnaire|poste|notre)\y' then 'fr'
    when (title || ' ' || left(description, 1000)) ~* '\y(el|los|las|para|con|por|requisitos|empresa|nuestro|equipo|experiencia)\y' then 'es'
    else 'en'
end
where language = 'en';

commit;

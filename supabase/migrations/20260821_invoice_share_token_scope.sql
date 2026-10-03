-- Close the invoice_shares guest-link data exposure (Sprint 3 audit).
--
-- THE BUG
-- -------
-- The guest invoice page (/i/[token]) read the table straight from the browser
-- with the anon key:
--
--     supabase.from("invoice_shares").select(...).eq("public_token", token)
--
-- and the anon read was authorised by:
--
--     policy invoice_shares_public_token_read
--       for select to public
--       using (public_token is not null)
--
-- RLS is applied before the .eq() filter, and the filter is just a query
-- parameter the caller controls. So the policy granted every anonymous caller
-- read access to every shared invoice, and dropping the filter dumped the whole
-- table. Verified against production before this migration:
--
--     curl "$URL/rest/v1/invoice_shares?select=*&public_token=not.is.null" \
--          -H "apikey: <anon>"
--
-- returned other people's invoice numbers, totals, client_email,
-- freelancer_email and — worst — their public_token values, which are the
-- bearer credentials for the guest links themselves. The anon key is public by
-- design (it ships inside the web bundle and the APK), so this needed no
-- credentials at all.
--
-- THE FIX
-- -------
-- A row-level policy cannot express "only the row whose token the caller
-- presented", because RLS never sees the token. So the token check moves into a
-- SECURITY DEFINER function that takes it as an argument -- the same pattern
-- already used for vault_lookup_share_by_token -- and the blanket policy is
-- dropped. The function returns only the columns a guest needs, so the emails,
-- the owner uids and the token itself stop being reachable.

begin;

drop policy if exists invoice_shares_public_token_read on public.invoice_shares;

create or replace function public.invoice_share_by_token(p_token text)
returns table (
  invoice_number text,
  total numeric,
  currency text,
  status text,
  due_date date,
  payment_method text
)
language sql
stable
security definer
set search_path = 'public'
as $fn$
  select s.invoice_number, s.total, s.currency, s.status, s.due_date, s.payment_method
  from public.invoice_shares s
  where s.public_token is not null
    and s.public_token = p_token
  limit 1;
$fn$;

comment on function public.invoice_share_by_token(text) is
  'Guest lookup for a public invoice link. Returns display columns only for the single row matching the presented token. Replaces the invoice_shares_public_token_read policy, which exposed every shared invoice to anon.';

revoke all on function public.invoice_share_by_token(text) from public;
grant execute on function public.invoice_share_by_token(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tidy up chat_blocks: five overlapping policies doing the work of four
-- ---------------------------------------------------------------------------
-- chat_blocks_own was FOR ALL TO public, so it also granted SELECT, which
-- overlapped chat_blocks_read_blocked and chat_blocks_select_own (the latter
-- being an exact duplicate of read_blocked). Replace the catch-all with
-- explicit per-command policies. Net effect on access is nil: the blocker still
-- has full control of its own rows, and the blocked user can still see that it
-- was blocked.

drop policy if exists chat_blocks_own on public.chat_blocks;
drop policy if exists chat_blocks_select_own on public.chat_blocks;
drop policy if exists chat_blocks_insert_own on public.chat_blocks;
drop policy if exists chat_blocks_delete_own on public.chat_blocks;
drop policy if exists chat_blocks_read_blocked on public.chat_blocks;

create policy chat_blocks_select_participant on public.chat_blocks
  for select to authenticated
  using (blocker_uid = (select auth.uid()) or blocked_uid = (select auth.uid()));

create policy chat_blocks_insert_own on public.chat_blocks
  for insert to authenticated
  with check (blocker_uid = (select auth.uid()));

create policy chat_blocks_update_own on public.chat_blocks
  for update to authenticated
  using (blocker_uid = (select auth.uid()))
  with check (blocker_uid = (select auth.uid()));

create policy chat_blocks_delete_own on public.chat_blocks
  for delete to authenticated
  using (blocker_uid = (select auth.uid()));

commit;

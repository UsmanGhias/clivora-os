-- Migration: 20261120_clivora_events_payload_guard.sql
-- Harden record_product_event to ensure payloads are never stored as empty JSON objects

CREATE OR REPLACE FUNCTION public.record_product_event(p_name text, p_properties jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
begin
  if auth.uid() is null or p_name is null or length(trim(p_name)) = 0 then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;
  insert into public.clivora_events (event_type, user_email, user_name, plan, payload, source)
    select 
      left(trim(p_name), 80), 
      coalesce(u.email, ''), 
      coalesce(p.name, ''),
      coalesce(p.subscription_plan, 'free'),
      case 
        when p_properties is null or p_properties = '{}'::jsonb or p_properties = 'null'::jsonb
        then jsonb_build_object('event', p_name, 'timestamp', now(), 'source', 'web')
        else p_properties
      end,
      'web'
    from auth.users u 
    left join public.profiles p on p.id = u.id 
    where u.id = auth.uid();
end;
$$;

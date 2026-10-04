-- Restrict the privileged winner-reset RPC to authenticated users only.
-- The earlier migration revoked PUBLIC, but an explicit legacy anon grant can
-- survive that revoke. Remove both PUBLIC and anon execution explicitly.

revoke execute on function public.reset_pemenang(text) from public;
revoke execute on function public.reset_pemenang(text) from anon;
grant execute on function public.reset_pemenang(text) to authenticated;

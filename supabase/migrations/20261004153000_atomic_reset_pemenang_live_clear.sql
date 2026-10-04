-- Atomic winner reset: keep winner/payment/expense cleanup and public live-draw state
-- in the same transaction. This migration intentionally does not mutate
-- existing production winner rows.

create or replace function public.reset_pemenang(p_pemenang_id text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_pemenang public.pemenang%rowtype;
  v_payment public.pembayaran_pemenang%rowtype;
  v_reversed numeric := 0;
  v_deleted_payment boolean := false;
  v_deleted_expense boolean := false;
  v_live_cleared boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Login diperlukan untuk mereset pemenang';
  end if;

  select * into v_pemenang
  from public.pemenang
  where id=p_pemenang_id
  for update;

  if not found then
    raise exception 'Pemenang tidak ditemukan: %', p_pemenang_id;
  end if;

  select * into v_payment
  from public.pembayaran_pemenang
  where pemenang_id=p_pemenang_id
  for update;

  if found then
    v_reversed := coalesce(v_payment.nominal,0);

    if v_payment.pengeluaran_id is not null then
      delete from public.pengeluaran
      where id=v_payment.pengeluaran_id;
      v_deleted_expense := found;
    end if;

    delete from public.pembayaran_pemenang
    where id=v_payment.id;
    v_deleted_payment := found;
  end if;

  delete from public.pemenang
  where id=p_pemenang_id;

  update public.undian_live
  set periode_id='',
      periode_nama='',
      status='idle',
      current_name='',
      current_index=0,
      winner_id=null,
      winner_nama=null,
      updated_at=now()
  where id='live-1'
    and (
      status is distinct from 'idle'
      or coalesce(periode_id,'') <> ''
      or coalesce(periode_nama,'') <> ''
      or coalesce(current_name,'') <> ''
      or coalesce(current_index,0) <> 0
      or winner_id is not null
      or winner_nama is not null
    );

  v_live_cleared := found;

  return jsonb_build_object(
    'ok',true,
    'pemenang_id',p_pemenang_id,
    'periode_id',v_pemenang.periode_id,
    'reversed_amount',v_reversed,
    'payment_deleted',v_deleted_payment,
    'expense_deleted',v_deleted_expense,
    'live_cleared',v_live_cleared
  );
end;
$$;

revoke all on function public.reset_pemenang(text) from public;
grant execute on function public.reset_pemenang(text) to authenticated;

-- ArisanPro: atomic winner reset + public live-draw cleanup
-- Apply once to the LIVE Supabase database.
-- Safe for existing data: CREATE OR REPLACE FUNCTION only.

create or replace function public.reset_pemenang(
  p_pemenang_id text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_pemenang public.pemenang%rowtype;
  v_payment public.pembayaran_pemenang%rowtype;
  v_live public.undian_live%rowtype;
  v_reversed numeric := 0;
  v_deleted_payment boolean := false;
  v_deleted_expense boolean := false;
  v_live_cleared boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Login diperlukan untuk mereset pemenang';
  end if;

  select * into v_live
  from public.undian_live
  where id='live-1'
  for update;

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

  if v_live.id is not null
     and v_live.winner_id = p_pemenang_id then
    update public.undian_live
    set status='idle',
        current_name='',
        current_index=null,
        winner_id=null,
        winner_nama=null,
        periode_id='',
        periode_nama='',
        updated_at=now()
    where id='live-1';

    v_live_cleared := true;
  end if;

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

grant execute on function public.reset_pemenang(text) to authenticated;

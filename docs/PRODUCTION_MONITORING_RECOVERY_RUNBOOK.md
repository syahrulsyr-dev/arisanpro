# ArisanPro — Production Monitoring & Recovery Runbook

**Status:** Post-freeze operational readiness  
**Production baseline:** `main` / `index.html` blob `aa00831f9266f52aaebc57c21cd10ef72d8caffd`  
**Prepared:** 2026-10-05  
**Supabase project:** Arisan Pro (`yjqnkdcnvthpkxwvxqxz`)

## 1. Scope

Runbook ini menetapkan pemeriksaan minimum setelah ArisanPro masuk production freeze. Tujuannya mendeteksi kegagalan aplikasi, RPC/financial mutation, Auth/Realtime, dan menyiapkan recovery tanpa menjadikan LIVE sebagai tempat eksperimen.

## 2. Monitoring baseline

### Application / API

Pantau:
- HTTP/API failures pada PostgREST dan Edge Functions.
- Error pada RPC financial.
- Lonjakan error setelah deployment.
- Auth failures dan realtime disconnect/error.

Supabase unified logs menyediakan source seperti:
- `edge_logs`
- `postgrest_logs`
- `postgres_logs`
- `realtime_logs`
- `auth_logs`
- `auth_audit_logs`

Audit 2026-10-05 menemukan aktivitas log normal pada semua source utama. Query error agregat 24 jam tidak menghasilkan finding.

### Database health

Minimum:
- Supabase project status harus `ACTIVE_HEALTHY`.
- Security Advisor diperiksa setelah perubahan database.
- Performance Advisor diperiksa berkala.
- Migration history dicatat sebelum dan sesudah perubahan.

## 3. Financial mutation monitoring

Critical mutation paths yang sudah diamankan mencakup:
- `aw_record_payment`
- `aw_edit_payment`
- `aw_delete_payment`
- `aw_record_refund`
- `aw_edit_refund`
- `aw_edit_credit`
- `aw_use_credit`
- `bayar_pemenang`
- `reset_pemenang`
- `aw_reconcile_period_lifecycle`

Pola keamanan yang saat ini digunakan:
1. RPC wrapper berjalan sebagai `SECURITY DEFINER`.
2. Wrapper memanggil `private.aw_is_operator()`.
3. Non-operator harus ditolak dengan `OPERATOR_REQUIRED`.
4. Wrapper meneruskan operasi ke internal implementation.
5. Jangan menghapus `SECURITY DEFINER` hanya untuk membuat Advisor warning hilang; validasi operator dan search_path harus diaudit terlebih dahulu.

Audit langsung 2026-10-05 mengonfirmasi wrapper-wrapper tersebut memiliki `SECURITY DEFINER`, `search_path = public, private`, dan eksekusi `authenticated` aktif sementara `anon` tidak memiliki EXECUTE. Advisor warning pada fungsi-fungsi ini karena authenticated dapat memanggil endpoint RPC; ini bukan bukti bahwa operator guard dapat dilewati.

## 4. Supabase Advisor findings

### Expected / intentional

Advisor melaporkan SECURITY DEFINER executable by authenticated pada RPC financial. Ini expected karena frontend authenticated memang menggunakan RPC tersebut. Kontrol sebenarnya berada pada `private.aw_is_operator()`.

### Separate hardening item

Advisor juga melaporkan:
- `private.aw_operator_roles` RLS enabled without policy.
- Leaked Password Protection pada Supabase Auth masih disabled.

Keduanya harus diperlakukan sebagai backlog security hardening terpisah dan tidak dicampur dengan perubahan financial RPC tanpa pengujian.

### Performance backlog

Advisor melaporkan tujuh foreign key tanpa covering index dan empat index yang belum pernah digunakan. Jangan langsung menambah/menghapus index berdasarkan lint saja. Validasi query workload dan execution plan terlebih dahulu.

## 5. Backup & recovery policy

Prinsip utama:
- Backup production bukan pengganti testing.
- Jangan menggunakan LIVE data sebagai fixture recovery test.
- Jangan melakukan restore/rollback production hanya untuk simulasi.
- PITR, bila tersedia dan telah diaktifkan sebelumnya, menjadi mekanisme disaster recovery production.
- Recovery production dapat menyebabkan kehilangan data setelah target waktu recovery; gunakan hanya saat benar-benar diperlukan.

Supabase juga menyediakan development branches yang tidak membawa production data. Gunakan branch untuk rehearsal perubahan database dan recovery procedure yang aman.

## 6. Recovery decision tree

### A. UI-only regression

1. Stop rollout.
2. Identifikasi commit terakhir yang known-good.
3. Revert/rollback deployment code.
4. Pastikan GitHub Pages kembali ke baseline.
5. Jalankan smoke + authenticated E2E.

### B. Financial mutation regression

1. Stop further financial mutation testing.
2. Jangan mencoba memperbaiki ledger dengan direct SQL ad hoc.
3. Preserve evidence: error, RPC name, timestamp, affected record.
4. Audit transaction/ledger consistency.
5. Revert code only if database state remains consistent.
6. Jika data integrity sudah terdampak, lakukan recovery database berdasarkan prosedur backup/PITR yang telah diverifikasi.

### C. Database corruption / destructive migration

1. Freeze application writes if feasible.
2. Determine last known-good recovery point.
3. Preserve incident evidence.
4. Restore only through documented Supabase recovery procedure.
5. Reconcile all legitimate transactions created after the recovery point from external records/audit evidence.
6. Re-run integrity and financial reconciliation before reopening writes.

## 7. Recovery rehearsal — safe mode

Recovery rehearsal harus dilakukan pada development/temporary environment:
- schema/migrations berasal dari production baseline;
- gunakan synthetic seed data;
- jangan copy production personal data;
- jalankan financial mutation tests;
- jalankan concurrency tests;
- verifikasi ledger balance, winner/payment/refund relationships, RLS, dan realtime state;
- destroy/recreate the rehearsal environment after the test when appropriate.

## 8. Release gate

Tidak boleh merge perubahan production yang menyentuh database/financial path jika:
- security advisor memiliki regression baru yang belum dijelaskan;
- RPC behavior belum diuji;
- concurrency path belum diuji ketika relevan;
- ada perubahan LIVE data yang tidak disengaja;
- rollback/recovery impact belum dipahami.

## 9. Incident evidence checklist

Simpan:
- deployment commit SHA;
- `index.html` blob SHA bila UI baseline terkait;
- timestamp UTC;
- affected route/tab;
- authenticated/public mode;
- RPC/function name;
- database record identifiers yang diperlukan untuk audit;
- error message;
- relevant Supabase log excerpt;
- migration version;
- before/after integrity result.

Jangan menyimpan secret key, password, JWT, atau service-role credential di issue/commit/log.

## 10. Current readiness snapshot — 2026-10-05

- Project status: ACTIVE_HEALTHY
- Postgres: 17.x
- Recent 24h unified log sources: present for Edge, PostgREST, Postgres, Realtime, Auth, Auth Audit, Storage, PgBouncer, and Supavisor.
- Aggregated 24h error query: no findings using the current log fields.
- Financial RPC wrappers: operator guard present.
- Anonymous EXECUTE on audited financial wrappers: disabled.
- Authenticated EXECUTE: enabled as required for frontend RPC access.
- Security Advisor: warnings documented above; no new critical finding observed.
- Performance Advisor: informational backlog documented above.

## 11. Change discipline

`main` remains frozen. This runbook is documentation/operational guidance and must not be treated as permission to modify production schema or application code directly.

Any future implementation:
`branch -> test -> review -> PR -> regression -> merge`.

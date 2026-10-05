# ArisanPro — Production Baseline

**Status:** PRODUCTION BASELINE / RELEASE FREEZE  
**Baseline branch:** `main`  
**Baseline index.html blob SHA:** `aa00831f9266f52aaebc57c21cd10ef72d8caffd`  
**Baseline main commit at documentation freeze:** `5b236dccff4d76d96f2080205faa9dc02f9d340b`  
**Freeze date:** 2026-10-05

## 1. Purpose

Dokumen ini menetapkan kondisi `main` yang telah melewati rangkaian audit sebagai baseline produksi. Perubahan setelah freeze harus diperlakukan sebagai feature/bug-fix baru melalui branch dan Pull Request.

## 2. Release evidence

| Area | Status |
|---|---|
| DB integrity | PASS |
| Security / RLS | PASS |
| Concurrency hardening | PASS |
| Public realtime | PASS |
| Playwright desktop/mobile | PASS |
| Authenticated admin E2E | PASS |
| GitHub Pages deployment | PASS |
| CI Node 24 | PASS |
| Source review | PASS |
| Live-data mutation during E2E | NONE OBSERVED |

## 3. Source review findings

- `TODO` / `FIXME`: 0
- `debugger`: 0
- `service_role` exposed in frontend: 0
- Duplicate `<script id>`: 0
- SQL Pembayaran UI operasional: hidden
- Legacy Ledger schema UI: hidden
- Legacy Concurrency Test UI: hidden

Legacy Schema Ledger / Concurrency Harness code remains embedded but is not part of the operational Finance workspace. It is intentionally retained as diagnostic/harness material.

Input Pemenang Manual is an active feature. Its nominal is processed by the financial engine before persistence.

## 4. Database / mutation policy

Direct client operations may still exist for non-critical domains such as member/period/public-live state and selected financial-adjacent records. Their presence alone is not considered a defect.

Critical financial mutations are protected by the audited RLS/operator controls and RPC/locking paths established during the database hardening work.

Do not perform a broad refactor merely to eliminate every direct client write.

## 5. Freeze rules

1. Do not edit `main` directly for new work.
2. Create a dedicated branch from the current production baseline.
3. Keep each change narrowly scoped.
4. Open a Pull Request.
5. Required regression checks must pass before merge.
6. If a change fails regression, revert/fix the PR rather than patching production ad hoc.
7. Any database migration must be reviewed separately from UI-only changes.
8. Never use production data as a disposable E2E test fixture.

## 6. Minimum regression gate for future PRs

### UI-only change
- Playwright smoke
- desktop regression
- mobile regression
- authenticated admin E2E when affected

### Database / financial change
All UI-only checks above, plus:
- DB integrity checks
- RLS/security checks
- RPC behavior
- concurrency/locking checks when the mutation path is affected
- confirmation that no unintended LIVE data was changed

### Public/realtime change
All relevant checks above, plus:
- public warga-link load
- realtime state propagation
- winner/live-draw state consistency

## 7. Rollback principle

The production baseline is the known-good reference point. When a new change causes regression, rollback to the last known-good commit/merge rather than accumulating emergency patches on `main`.

## 8. Important distinction: blob SHA vs commit SHA

The SHA above for `index.html` is the **Git blob SHA** of the file, not the commit SHA. It is useful for proving that the file content is identical. The commit currently anchoring `main` at documentation freeze is recorded separately above.

## 9. Next phase

Post-freeze work should focus on one of:

- production monitoring and error visibility;
- backup/recovery readiness;
- regression-suite expansion;
- documentation/runbook improvements;
- new product features.

The audit itself is considered closed unless new evidence indicates a regression or security/data-integrity issue.

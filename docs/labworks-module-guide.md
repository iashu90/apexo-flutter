# Labworks Module Guide

## 1. Purpose
Labworks screen tracks all lab cases from in-lab to ready to delivered, including payment due tracking, bulk settlement workflow, and lab-specific filtering.

## 2. Primary files
- `lib/features/labwork/labworks_screen.dart`
- `lib/features/labwork/open_labwork_dialog.dart`
- `lib/features/labwork/labworks_store.dart`
- `lib/common_widgets/lab_bulk_update_dialog.dart`

## 3. Route activation and sync
When route `labworks` is selected:
- `doctors.synchronize()`
- `patients.synchronize()`
- `labworks.synchronize()`

## 4. Header actions and behavior
Header buttons:
- CSV/PDF export for current filtered list
- `Lab Bulk Update` (password-protected)
- `New Labwork` (opens create/edit dialog)

## 5. Board columns and state model
Filtered items are split into three sections:
- `In Lab`: `!deliveredToDoctor`
- `Ready`: `deliveredToDoctor && !deliveredToPatient`
- `Delivered`: `deliveredToPatient`

Each section has collapse/expand toggles.

## 6. Filters and search
Controls include:
- search (patient/phone/teeth/doctor text)
- month navigator when range is monthly
- lab selector (`all`, `unassigned`, known labs)
- date range selector (`all`, monthly, today, week, last_month, custom)
- payment filter (`all`, `paid`, `due`, `no_due`)
- clear filters action

Custom range opens nested date range picker modal.

## 7. Row actions
Each labwork card/row supports:
- `History`: opens patient history modal in labs-only mode
- `Open`: opens labwork edit dialog
- `Delete`: confirmation dialog then delete

## 8. New/Edit Labwork dialog (nested modal)
`openLabworkDialog` includes:
- date/time
- patient picker
- doctor picker
- laboratory selector
- type of work selector
- shade selector
- teeth picker
- unit count and price logic
- delivery state toggles (`in_lab`, `ready`, `delivery`)
- notes

Save action writes to `labworks` store.

## 9. Lab Bulk Update dialog (nested modal)
`showLabBulkUpdateDialog` flow:
1. password guard dialog (`runPasswordProtectedAction`)
2. bulk update dialog opens
3. choose month + lab filter + optional name text filter
4. `Find Due Records` computes matching unpaid labworks
5. `Mark All Paid` sets all matched rows to paid
6. creates one summarized expense entry for settlement

This flow cross-writes into both `labworks` and `expenses` stores.

## 10. Labworks store behavior and caching
`labworks_store.dart` provides:
- `allLabs`: hardcoded defaults + settings-saved labs + existing records
- `predefinedLabs`: default + settings labs only
- phone helpers for labs (`allPhones`, `getPhoneNumber`)

This supports dropdown suggestions and data consistency without repeated API calls.

## 11. Export behavior
- CSV/PDF export current filtered rows only.
- Includes status conversion (`In Lab`, `Ready`, `Delivered`).
- Disabled while export is running or when no rows exist.

## 12. API and persistence path
Labworks follows standard Store path:
1. local observable update (`labworks.set`)
2. local Hive write
3. remote upsert when online
4. deferred queue when offline
5. background sync/realtime convergence

## 13. Fresher operational checklist
1. Create new labwork and verify board placement in `In Lab`.
2. Move delivery state to `Ready` then `Delivered` and verify section movement.
3. Apply search + date + lab + payment filters together.
4. Open `History` from row and validate labs-only history scope.
5. Run `Lab Bulk Update` with due items and verify:
   - rows marked paid
   - generated summarized expense entry
6. Export CSV/PDF and validate output schema.

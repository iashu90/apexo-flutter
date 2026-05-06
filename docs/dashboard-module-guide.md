# Dashboard Module Guide

## 1. Purpose
The Dashboard screen is the day-control cockpit for appointments. It gives a quick operational and financial snapshot, then lets staff open patient/treatment workflows directly from rows and cards.

## 2. Primary files
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/dashboard/dashboard_controller.dart`
- `lib/features/dashboard/outstanding_balance_modal.dart`
- `lib/features/dashboard/overall_due_helper.dart`
- `lib/features/dashboard/dashboard_insight_cards.dart`

## 3. Stores and data dependencies
- `appointments` store: primary source for counts, status splits, financial totals, and table rows.
- `patients` store: patient names/details, outstanding computation joins.
- `doctors` store: doctor labels and doctor filter options.
- `labworks` store: used when creating labwork drafts from dashboard row actions.

## 4. Route activation and sync
When route `dashboard` is selected:
- `chartsCtrl.resetSelected()` is called.
- `patients.synchronize()` is called.
- `appointments.synchronize()` is called.

This means dashboard opens with a remote pull attempt and then works from the local store map.

## 5. Startup behavior and loading
Dashboard has a bootstrap sequence:
- Waits for `appointments.loaded`, `patients.loaded`, `doctors.loaded`.
- Performs initial sync settle logic (`_awaitInitialAppointmentsSync`) with timeout/soft warning behavior.
- If remote is slow, UI still renders using local cache and a warning banner.

## 6. Core filters and query model
Dashboard rows are filtered/sorted in this order:
1. Date scope (selected date).
2. Doctor filter (`all`, specific doctor, `unassigned`).
3. Treatment filter (`all` or exact treatment).
4. Status filter (normalized by `normalizeCheckinStage`).
5. Search query (patient name/phone).
6. Sort key and direction.

Sort columns include:
- Time
- Patient
- Doctor
- Treatment
- Status
- Payment mode
- Payment amount

## 7. Header and top actions
Main action pathways:
- `Check-in` button opens patient lookup/check-in dialog.
- Date navigator changes active day and recomputes metrics/tables.
- Filter chips/toggles for status doctor treatment.

### Check-in action details
`_openAddAppointmentFromDashboard()`:
- opens `showPatientCheckinLookupDialog`
- supports adding new patient via `openAddPatientPopup`
- supports opening existing appointment via `openAppointmentJourneyDialog`
- supports checking in selected patient and immediately opening journey

## 8. Insight cards and KPI behavior
Dashboard shows many computed cards (today and comparative values), including:
- appointment counts
- payment collections
- new patient deltas
- outstanding summary

Some cards are clickable:
- outstanding cards open `showOutstandingBalanceModal`
- new patient card opens detailed new-patient dialog for selected date

## 9. New Patients dialog (nested modal)
`_openNewPatientsDialog` opens a `ContentDialog` with:
- list of first-time appointments for the selected date
- patient details preview (name, age, phone, address)
- quick actions to open/edit patient where applicable

## 10. Appointment table actions (row-level)
Typical row actions include:
- open patient history dialog
- open edit-treatment modal
- open patient editor popup
- open/create labwork for patient
- delete appointment (confirmation dialog)

### Edit treatment flow from Dashboard
`_openEditTreatmentModal()` calls `CheckinStageModalRouter.openForStage(...)` and routes to:
- treatment modal
- billing modal
- completion modal
via `openAppointmentJourneyDialog`.

This makes Dashboard an entry point to the exact same check-in lifecycle used in Check-in screen.

## 11. Outstanding Balance modal details
`showOutstandingBalanceModal`:
- computes outstanding per patient by aggregating appointments
- provides filters (overdue, due today, amount thresholds, payment mode, partial/unpaid)
- supports search, pagination-like visible count growth, and select rows
- supports CSV/PDF export for filtered data
- supports direct call/WhatsApp style follow-up actions where available

## 12. Caching and performance behavior
Dashboard uses both static and reactive cache layers:
- `dashboardCtrl` keeps memoized values (`_todayAppointments`, `_thisMonthAppointments`, `_totalDueAmount`) and invalidates them when `appointments` changes.
- Screen-level filtered/sorted lists are recomputed on state changes.
- Initial sync gate avoids rendering stale skeleton forever and intentionally falls back to local data.

## 13. API and persistence path
Dashboard does not call APIs directly. Data path is:
1. UI action modifies store (`appointments.set`, etc.) or opens modal.
2. `Store` writes to local Hive via `SaveLocal`.
3. If online and no deferred backlog, it pushes to PocketBase via `SaveRemote.put`.
4. On sync cycles it fetches remote deltas using `SaveRemote.getSince`.
5. Realtime subscription can re-trigger sync and refresh local map.

## 14. Fresher checklist to test
1. Open dashboard with network ON and OFF, verify fallback banner behavior.
2. Use Check-in action to create/open appointment and verify table refresh.
3. Click outstanding card and validate modal totals and filters.
4. Trigger treatment edit from row and verify stage updates in table.
5. Verify doctor/treatment/status filter combinations.
6. Verify sort toggles by each column.
7. Validate delete confirmation and persistence after restart.

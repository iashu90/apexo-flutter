# Patients Module Guide

## 1. Purpose
The Patients screen is the master directory plus analytics surface for patient lifecycle: list management, high-value behavior flags, history, lab shortcuts, exports, and deletion guardrails.

## 2. Primary files
- `lib/features/patients/patients_screen.dart`
- `lib/features/patients/open_add_patient_popup.dart`
- `lib/features/patients/patients_store.dart`
- `lib/common_widgets/patient_history_modal.dart`

## 3. Stores and data dependencies
- `patients` store: patient records and tags.
- `appointments` store: visit counts, paid/outstanding, last visit, history rows.
- `labworks` store: cross-reference protection and lab shortcuts.

## 4. Route activation and sync
When route `patients` is selected:
- `doctors.synchronize()`
- `patients.synchronize()`
- `appointments.synchronize()`

The screen then renders from local observable maps with sync warning fallback if full convergence is slow.

## 5. Startup and sync settle behavior
Patients screen has the same guarded initial sync pattern as dashboard/checkin:
- await `patients.loaded` and `appointments.loaded`
- run `_awaitInitialAppointmentsSync`
- if remote sync times out, render with local data and warning

## 6. Header actions
Main buttons/actions:
- `Add Patient` / `New Patient`: opens add/edit popup (`openAddPatientPopup`).
- CSV/PDF export buttons: exports currently filtered patient table.
- Search bar: live query updates with pagination reset.

## 7. Filters and sort model
Patients list supports:
- text search
- alphabet filter (A-Z plus All)
- behavior filter (`all` and specialized segments such as high-value/follow-up buckets)
- sortable columns including name/visits/last visit/paid/outstanding
- pagination (`AppPagination`)

## 8. Core table columns and row actions
Each patient row generally includes:
- ID
- patient details
- visits
- last visit
- paid amount
- outstanding amount
- actions

Actions on row:
- `History`: opens `showPatientHistoryDialog`
- `Lab`: opens labwork dialog prefilled for patient
- `Delete`: protected delete path with dependency checks
- Edit (context dependent): opens same add-patient popup in edit mode

## 9. Add/Edit patient popup (nested modal)
`openAddPatientPopup` supports:
- name/age/phone/address
- gender and referral source
- medical/drug/maternal/habits chip groups
- phone normalization and duplicate detection hints
- input validation for required fields

When saved:
- creates or updates patient in `patients` store.
- data persists locally first, then sync pipeline pushes remote.

## 10. Patient History modal (nested modal)
`showPatientHistoryDialog` capabilities:
- full ledger of treatment history with filtering/search/sort
- optional `onEditTreatment(appointmentId)` callback to open appointment journey directly
- CSV/PDF export of visible ledger
- expandable row details and payment/status breakdowns

In Patients screen, history modal integrates with check-in journey so fresher can traverse from patient to procedure state quickly.

## 11. Deletion and integrity safety
Deletion is intentionally guarded in `patients_store.dart`:
- hard delete is blocked if any appointment or labwork references patient ID.
- store logs blocked actions for audit.

Additionally, sparse patient write protection exists:
- if an incoming write has mostly empty critical fields, store merges existing core fields instead of overwriting with blank data.

## 12. Store-level caching and integrity behaviors
`patients` store includes:
- tag aggregators (`allTags`)
- integrity audit over appointments/labworks references
- snapshot-based audit for title/phone core-field loss
- debounced integrity checks on patients/appointments/labworks map changes

## 13. API and persistence flow
Patients module follows shared Store pipeline:
1. `patients.set(...)` writes to observable map.
2. Store `_processChanges` writes to local Hive (`SaveLocal.put`).
3. If online and no deferred queue: `SaveRemote.put` batch upsert to PocketBase.
4. Background synchronize pulls `getSince(version)` deltas.
5. Version/deferred metadata tracked in local meta box.

## 14. Fresher step-by-step walkthrough
1. Open Patients route and verify data appears after bootstrap.
2. Create patient from `New Patient`; check list updates immediately.
3. Edit same patient and validate update persistence after app restart.
4. Open `History`, test search/filter/sort and export CSV/PDF.
5. Use `Lab` action and confirm prefilled patient link in labwork dialog.
6. Try deleting referenced patient and verify block message.
7. Remove references then delete and verify hard-delete behavior.

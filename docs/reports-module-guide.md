# Reports Module Guide

## 1. Purpose
Reports is the analytics surface for appointments/revenue/doctor performance and operational trends. It is read-heavy with chart cards, month navigation, and selective export.

## 2. Primary file
- `lib/features/stats/report_screen.dart`

## 3. Data dependencies
Report screen listens to:
- `appointments.observableMap.stream`
- `expenses.observableMap.stream`
- `patients.observableMap.stream`
via `MStreamBuilder`.

No direct remote API calls from this screen; it computes from synchronized local stores.

## 4. Layout and load strategy
- Responsive wrap-based card grid.
- Heavy chart cards deferred with `_showHeavyCards` toggling to avoid first-frame jank.
- `monthOffset` navigator controls the month scope for many cards.

## 5. Top controls
- month navigator (`_ReportMonthNavigator`) with back/forward
- title area
- per-card controls depending on widget (range dropdowns, expand/collapse, export)

## 6. Main analytic cards available
As implemented, the screen includes cards such as:
- Daily Appointments vs Gross Trend
- Daily Bar Trend
- Monthly Appointments Trend
- Monthly Revenue Trend
- Monthly Expenses Trend
- Monthly Net Revenue Trend
- Traffic by Time
- Traffic by Day
- Age Distribution
- Referral Source Distribution
- Monthly Treatment Distribution
- Gender Distribution
- New vs Returning
- Payment Mode Status
- Appointments Done By Doctor

## 7. Doctor performance card details
`_ReportDoctorAppointmentDoneCard` includes:
- summary tiles: appointments, revenue, doctor fee, net profit, percent
- month selector
- expand/collapse row table
- CSV/PDF export via `ExportButtons`
- row fields: doctor, appointments, revenue, doctor fee, net profit, profit %

## 8. Range and period model
Many cards use common scoped range logic:
- Monthly
- Last Month
- YTD
- Year
- All

Month anchor and offset are central to trend consistency across cards.

## 9. Export behavior
Cards with tabular data expose CSV/PDF export controls.
Export safety:
- disabled while busy
- disabled on empty rows
- uses shared utilities (`CsvExportUtility`, `PdfExportUtility`)

## 10. Interaction model
Reports is mostly read-only:
- no appointment mutations
- no deletion
- no form submissions
Primary interaction is exploration by period/range and exporting snapshots.

## 11. Performance and caching notes
- card rendering is intentionally staged (`_showHeavyCards`) after a short delay.
- all analytics are recomputed from in-memory stores on stream updates.
- no additional cache persistence in this screen, but upstream store caches (versions/deferred/local maps) affect freshness.

## 12. API and sync path
Reports relies on route-level store sync (from navigation hooks) and global store engine:
- local version/deferred tracked in Hive meta
- remote deltas pulled by `SaveRemote.getSince`
- realtime subscriptions can trigger resync

## 13. Fresher test checklist
1. Navigate months back/forward and verify card timelines shift.
2. Compare Revenue vs Expenses vs Net cards for consistency.
3. Validate doctor card totals match appointment data.
4. Export CSV/PDF from doctor card and verify content.
5. Confirm behavior with empty month datasets (graceful no-data states).

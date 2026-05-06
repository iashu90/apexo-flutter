# Expenses Module Guide

## 1. Purpose
Expenses screen is a ledger + analytics board for clinic spending, including one-time and recurring expenses, category/payment/doctor filtering, overview charts, and exports.

## 2. Primary files
- `lib/features/expenses/expenses_screen.dart`
- `lib/features/expenses/expense_model.dart`
- `lib/features/expenses/expenses_store.dart`
- `lib/features/expenses/open_expense_panel.dart` (legacy panel flow still available)

## 3. Route activation and sync
When route `expenses` is selected:
- `doctors.synchronize()`
- `patients.synchronize()`
- `expenses.synchronize()`

## 4. Header actions and button behavior
Top-right actions:
- `New Expense`: opens expense modal for create.
- `Recurring Expenses`: opens recurring management dialog.
- `Export` CSV/PDF: exports current filtered rows.

## 5. Recurring expense engine
At screen init, `_ensureRecurringEntriesUpToDate()` runs:
- identifies recurring monthly root expenses (`recurring:monthly` tags)
- creates generated entries for missing months up to current month
- uses tags like:
  - `recurring:generated`
  - `recurring:series:<id>`
  - `recurring:source:<id>`
- avoids duplicate monthly generation per series/month

This is a key auto-caching/normalization behavior freshers must know.

## 6. Filtering, sorting, pagination
Supported controls:
- search query
- category filter
- payment mode filter (UPI/Cash)
- doctor filter
- recurring-only filter
- month navigation and month anchor
- sort by date/amount/category
- pagination via `AppPagination`

## 7. Overview card and summary strip
Screen includes:
- summary KPI strip (totals and status summaries)
- category distribution pie chart with grouped `Others`
- table card for paged entries

## 8. Expense row interactions
Row/card click opens details side panel/expanded details area (depending layout).
Detail actions include:
- `Edit`: opens expense modal with existing record
- `Delete`: confirmation dialog then hard delete

## 9. Expense modal fields (nested dialog)
`_openExpenseModal` includes:
- date picker
- expense category (preset + custom)
- payment mode (UPI/Cash)
- amount
- note
- doctor mapping
- paid/due semantics

Footer actions:
- `Cancel`
- save/update primary button (context aware create/edit)

## 10. Recurring Expenses dialog (nested dialog)
`_openRecurringExpenseDialog` lists recurring rows with:
- quick edit path
- close action
- month-scoped visibility

## 11. Export behavior
- CSV uses structured columns: Date, Category, Amount, Paid, Doctor, Note.
- PDF renders similar tabular view with currency formatting.
- Export is disabled when dataset empty or another export in progress.

## 12. Store and persistence model
`expenses_store.dart` provides:
- list aggregators (`allIssuers`, `allTags`, `allItems`, `allPhones`)
- issuer->phone helper (`getPhoneNumber`)

Persistence/sync:
1. `expenses.set` writes local observable map.
2. local Hive write through Store.
3. remote batch upsert when online.
4. deferred queue used when offline or sync failure.

## 13. Legacy panel editor
`open_expense_panel.dart` still implements route panel editing with:
- operators picker
- tag input widgets
- call button and autosuggest
- paid toggle
This is useful context if older flows in app still route to panel UI.

## 14. Fresher validation checklist
1. Create one-time expense and verify totals/overview update.
2. Create recurring monthly root, restart app, verify backfill generation behavior.
3. Filter by doctor and payment mode, confirm list and summary coherence.
4. Edit and delete rows from details pane.
5. Export CSV/PDF and verify data columns.
6. Test offline create then reconnect to verify deferred sync push.

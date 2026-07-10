# Project: Rhea (macOS receipt extraction app)

## What it is
A native macOS SwiftUI app that ingests scanned grocery-receipt PDFs, extracts structured
data from each via a local vision model, lets the user review/edit the extraction against the
source image, confirms it, and exports confirmed records to CSV or Postgres for analysis.
(Formerly scaffolded as "ReceiptVault"; the app, bundle, and sources are now "Rhea".)

## Stack & build
- Swift 5 language mode, SwiftUI, macOS 14+.
- **Xcode macOS App project**, generated from `project.yml` by **XcodeGen** (the project is *not*
  committed; `project.yml` is the source of truth).
- Bundle identifier: `net.danieldaum.rhea`. Product/app name: `Rhea`.
- Architecture: MVVM. Views are dumb; state lives in a single `@Observable @MainActor` view model (`ReceiptsViewModel`).
- No third-party SPM/runtime dependencies — Apple frameworks only (SwiftUI, AppKit, PDFKit, Foundation,
  Observation). XcodeGen is a build-time dev tool installed via Homebrew, not an app dependency.
- File layout: `Rhea/{Models,ViewModels,Views,Services}`, plus `Rhea/Assets.xcassets`.

## Build & distribution
- One-time: `brew install xcodegen`.
- Generate / regenerate the project: `xcodegen generate` (writes `Rhea.xcodeproj`).
- Develop: open `Rhea.xcodeproj` in Xcode and Run, or
  `xcodebuild -project Rhea.xcodeproj -scheme Rhea -configuration Debug build`.
- Distribute a `.dmg`: in Xcode, **Product ▸ Archive ▸ Distribute App**. A warning-free download
  requires a paid **Developer ID** signature + **notarization** (`net.danieldaum.rhea`). The project is
  currently set to ad-hoc "sign to run locally" (`CODE_SIGN_IDENTITY = -`); set your team / Developer ID in
  `project.yml` (or the Signing & Capabilities tab) before notarizing.
- Icon: `Rhea/Assets.xcassets/AppIcon.appiconset` (generated from `Packaging/AppIcon.png`, the 1024px
  master). Regenerate sizes with `sips` if the master changes.

## Critical conventions (learned the hard way)
- **Do not put editable line-item controls inside a SwiftUI `Form`.** On macOS, `Form` auto-converts titled
  `TextField`s into labeled rows (placeholder becomes a permanent label) and overrides `.frame(width:)`,
  which breaks column alignment. `ReceiptEditForm` is a plain `ScrollView` + `VStack` of cards with
  fixed-width columns instead.
- **Be lenient when decoding model output.** Vision models emit off-type values (numeric `barcode`/
  `storeNumber`, quoted decimals). `Models/LenientDecoding.swift` coerces String/number/null so one bad
  field never fails the whole receipt.
- `RheaApp.swift` keeps an `NSApplicationDelegateAdaptor` that sets `.regular` activation. As a proper
  `.app` this is redundant (a bundled app is already foreground), but it's harmless and still lets the raw
  binary take keyboard focus if run directly. Keep it.
- Keep the build green (`xcodebuild ... build`) after each change. Swift 5 language mode (`SWIFT_VERSION`)
  is intentional — Swift 6 strict concurrency would flag the `@MainActor`/actor hand-offs.

## File map
- `project.yml` — XcodeGen spec (target, bundle id, signing, icon, deployment target).
- `Rhea/RheaApp.swift` — `@main` app entry; AppDelegate activation; loads vault on launch; saves on background.
- `Rhea/Assets.xcassets/AppIcon.appiconset` — macOS app icon.
- `Rhea/Models/Receipt.swift` — `Receipt`, `ExtractedReceipt`, `LineItem`, `ReceiptStatus` (+ lenient `Codable`).
- `Rhea/Models/ReceiptKeys.swift` — computed `Receipt.publicID`, `Receipt.naturalKey`, `LineItem.stableKey`; `slugComponent`.
- `Rhea/Models/LenientDecoding.swift` — `KeyedDecodingContainer.lenientString/lenientDecimal`.
- `Rhea/Models/AppEnums.swift` — `SidebarItem`, `ReceiptFilter`.
- `Rhea/ViewModels/ReceiptsViewModel.swift` — state, import, sequential processing queue, confirm, delete, export.
- `Rhea/Services/LocalStore.swift` — durable on-disk store (Application Support).
- `Rhea/Services/ExtractionService.swift` — OpenAI-compatible vision call + JSON parsing + prompt.
- `Rhea/Services/PDFService.swift` — renders a PDF's first page to PNG.
- `Rhea/Services/PersistenceStore.swift` — persistence protocol.
- `Rhea/Services/CSVExporter.swift`, `CSVStore.swift` — CSV export.
- `Rhea/Services/PostgresStore.swift`, `PostgresSQLExporter.swift` — Postgres export via `psql` + schema constant.
- `Rhea/Views/` — `ReceiptListView`, `ReceiptDetailView`, `ReceiptEditForm`, `SidebarView`, `SettingsView`, `ResizableSplitView`.
- `Packaging/AppIcon.png` — 1024px icon master.

## Data model
`Receipt`: `id` (UUID), `sourceURL` (URL — points at the in-vault copy), `pageImage` (Data?), `status`
(`queued`/`inProgress`/`done`/`failed`), `extracted` (`ExtractedReceipt?`), `confirmed` (Bool),
`errorMessage` (String?), and processing timestamps `submittedAt`/`startedAt`/`finishedAt` (Date?).
- Computed: `publicID` = `rcpt_<uuid, no dashes>`; `naturalKey` = `chain_storeNumber_date_receiptNumber`
  (slugified, falls back to `publicID` when parts are missing).

`ExtractedReceipt`: `merchant`, `chain?`, `storeNumber?`, `storeAddress?`, `date` (ISO-8601),
`receiptNumber?`, `total` (Decimal), `tax?`, `paymentMethod?`, `lineItems`.

`LineItem`: `name` (receipt-printed), `aiCommonName?` (model's normalized suggestion), `userCommonName?`
(user's own normalized name), `category?`, `barcode?`, `quantity?`, `unitPrice?`, `weightLbs?`,
`pricePerLb?`, `listPrice?`, `pricePaid?`, `lineTotal?`.
- Computed: `stableKey(receiptKey:index:)` = `barcode_<barcode>` when present, else `<receiptKey>_itemNN`.
- The model emits `commonName`; decoding maps that (and legacy saved `commonName`) into `aiCommonName`.

## Persistence (`LocalStore`)
Durable store under `~/Library/Application Support/Rhea/`:
- `Store/<uuid>.json` — receipt record (metadata + extracted + timing; image bytes excluded).
- `Files/<uuid>/<originalName>` — copy of the imported PDF (so nothing depends on the user's file location).
- `Files/<uuid>/page.png` — rendered page image used by the UI and the model.

Atomic writes. The vault is the single source of truth: loaded on launch, saved on every mutation, and
removed (record + files) on delete. There is no seeded sample data; first launch starts empty.
`CSVStore`/`PostgresSQLExporter` are export-only (`load()` returns `[]`).

## Import + sequential processing queue
- Importing one or many PDFs (toolbar ⌘O or drag-and-drop) copies each into the vault, renders its page,
  enqueues it as `queued` with `submittedAt`, and kicks the queue.
- `processQueue()` is reentrancy-guarded and drains `queued` receipts **one at a time** in import order:
  stamps `startedAt` + `inProgress`, calls extraction, then sets `done`/`failed` + `finishedAt`, persisting
  each step.
- Re-process re-enqueues an item (clears extraction/error, unconfirms). Items left `inProgress` by a crash
  are re-queued and resumed on next launch.
- `queuePosition(for:)` and `processingDuration(for:)` drive the list's `N/M` indicator and count-up timer.

## Status flow
`queued` → `inProgress` → `done` (shown as blue **"Processed"**) → user clicks **Confirm** → `confirmed`
(green). Detail fields are editable while unconfirmed and lock once confirmed.

## Extraction (`ExtractionService`)
- OpenAI-compatible chat-completions endpoint with vision (LM Studio / oMLX). Endpoint + model name are
  configurable in Settings.
- Uses `response_format: { type: "text" }` (the server rejects `json_object`); the prompt demands a single
  JSON object and `extractJSON()` strips fences/prose before decoding.

## UI
Three-pane `NavigationSplitView`:
- **LEFT** (`SidebarView`): Receipts / Settings, with a badge counting queued + in-progress.
- **CENTER** (`ReceiptListView`): a `Table` with columns Receipt / Date / Total / Status / Time.
  - Top segmented filter (`ReceiptFilter`): **All / Queued / Processed / Confirmed / Failed**.
  - Status pill: gray "Queued", orange spinner + "Processing" with `N/M` position, blue "Processed",
    green "Confirmed", red "Failed". Time column counts up live while processing, then shows final duration.
  - Right-click context menu: Extract / Re-process, Confirm / Unconfirm, Reveal Source in Finder, and Delete
    (permanent, removes on-disk files, behind a confirmation dialog).
- **RIGHT** (`ReceiptDetailView`):
  - Failed → selectable/copyable error pane (with a Copy button).
  - Extracted → `ResizableHSplit`: source PDF image on the left, `ReceiptEditForm` on the right.
  - Pending → image plus a status banner (queued shows `N/M`; in-progress shows a spinner + elapsed time).

### `ReceiptEditForm` (review/validation surface)
Plain `ScrollView` of cards (no `Form`):
- **Receipt Details** card: read-only, copyable `Receipt ID` + `Key`, then editable receipt fields.
- **Line Items** card, one row per item:
  - Left (identity): item name (primary), "Your common name" (editable), the **AI suggestion** as a distinct
    blue accent (outlined `AI` mark + text, with a one-tap "use" affordance), and tertiary category
    (small color dot + muted text) + barcode in their own aligned columns.
  - Right (pricing): fixed-width columns so values line up across rows — `qty × ea` (or `wt @ /lb`), the
    bold line total, and the struck original price all share one right edge.
- `ResizableHSplit` (`ResizableSplitView.swift`) is a custom divider that shows the resize cursor on hover.

## Export (from Settings)
Only confirmed receipts with extracted data are exported.
- **CSV** (`CSVExporter`) → `~/Documents/Rhea/receipts.csv`, one row per line item. Columns include
  `RECEIPT_ID`, `RECEIPT_KEY`, `ITEM_KEY`, the store/receipt fields, `ITEM`, `AI_COMMON_NAME`,
  `COMMON_NAME` (the user's value), and weight/qty/price columns.
- **Postgres** (`PostgresStore`) → upserts via `psql` into `receipts` + `receipt_line_items`, which now carry
  `receipt_key`, `item_key`, `ai_common_name`, and `common_name` (user). Schema uses
  `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` so older databases upgrade in place. `PostgresSQLExporter`
  holds the schema constant shown in Settings.

## Change log
1. **Filters & statuses:** top filter is now All / Queued / Processed / Confirmed / Failed; the post-extraction
   `done` state is labeled blue **"Processed"**, green only after the user confirms.
2. **Right-click context menu** in the list: Extract / Re-process, Confirm / Unconfirm, Reveal Source in Finder,
   Delete (with confirmation).
3. **Durable local storage** (`LocalStore`) under Application Support — JSON record + copied original PDF +
   rendered PNG per receipt. Removed the old per-launch sample data; the vault is authoritative across
   quits/crashes.
4. **Editable details before confirm**, with read-only `Receipt ID` (`rcpt_…`) and natural `Key` surfaced.
5. **Keyboard input fix:** activation-policy AppDelegate so text fields accept typing.
6. **Extraction 400 fix:** switched `response_format` to `text`.
7. **Robust decoding:** lenient String/number/null coercion for model type drift.
8. **Copyable error pane** for failed receipts.
9. **ID/key system:** prefixed `publicID`, composite `naturalKey`, per-item `stableKey` — all flow into exports.
10. **AI vs. user common name:** split into read-only `aiCommonName` + editable `userCommonName`; both exported.
11. **Bulk upload + sequential auto-processing queue** with spinner, `N/M` position, and count-up timer.
12. **Line-items redesign:** off `Form`, fixed-width aligned pricing columns, clear hierarchy, blue AI accent,
    quiet category dots.
13. **Renamed ReceiptVault → Rhea** across package, sources, app struct, display strings, and storage paths.
14. **Converted to a real Xcode macOS App** (XcodeGen `project.yml`), with a generated app icon and bundle id
    `net.danieldaum.rhea`, so it builds/archives as a distributable `.app`/`.dmg`.
15. **Schema v2 for cross-retailer analysis** (authoritative DDL in `db/schema.sql`; loader in
    `db/load_baseline.sh`): `purchase_date DATE` (was TEXT), UNIQUE `receipt_key` with upserts keyed on it
    (prevents baseline + Rhea double-inserts), line items get `line_no`/`item_code`/`raw_name` (was
    name/item_key/barcode), new `line_type` (`item`/`deposit`/`fee`/`refund`/`discount`/`non_grocery`) to keep
    deposits/fees out of price stats, generated columns `effective_unit` + `effective_unit_price` normalizing
    per-lb vs per-each pricing, a `products` dimension (canonical `common_name` vocabulary), and analysis views
    (`v_prices`, `v_price_comparison`, `v_price_history`, `v_monthly_spend`, `v_receipt_qc`).
    `LineItem` gained `lineType` (lenient-decoded; `effectiveLineType` defaults to "item"); the extraction
    prompt demands weight lines be extracted (never default by-weight items to qty 1) and classifies lineType.
    Both Postgres paths (`PostgresStore`, `PostgresSQLExporter`) now emit ALL columns (the old exporter dropped
    common names/weights). Old prototype databases must be dropped — v2 is not migration-compatible.
16. **Prompt hardening from the 146-receipt baseline run** (`ExtractionService`): weight/qty modifier
    lines can print above OR below their item (attach by weight×rate arithmetic); savings lines are
    attributed by Price/You-Pay arithmetic, not adjacency; multi-buy deals use average unit price;
    voided lines become negative `refund` lines; mandatory self-check that line items (+tax) sum to the
    printed total before answering; `commonName` convention aligned with the DB products vocabulary
    (lowercase, 1-4 words, brand-free, keep organic/fat/boneless qualifiers). Chain examples now include
    GROCERY OUTLET and PIEDMONT GROCERY. The baseline dataset/pipeline lives in `receipts_raw/`
    (extraction spec, per-receipt JSONs, `qc.py`, `assemble.py`, `products_map.csv`) and loads via
    `db/baseline_full.sql` or `db/load_baseline.sh`; analysis queries in `db/analysis_queries.sql`.

## Working agreement
- Keep the build green (`xcodebuild ... build`) after each change; run `xcodegen generate` after editing `project.yml`.
- When unsure about a requirement, ask before inventing scope.
- Preserve the conventions in "Critical conventions" above; they encode bugs already fixed.

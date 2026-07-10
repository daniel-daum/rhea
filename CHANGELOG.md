# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is pre-1.0, so breaking
changes may land in minor releases.

## [0.2.0] - 2026-07-10

### Added
- Tag-triggered release pipeline (`.gitea/workflows/release.yml`): builds a Release
  configuration signed with a real Developer ID Application certificate, notarizes and
  staples the resulting `.dmg`, publishes it as a Gitea release with release notes
  pulled from this changelog, and generates + EdDSA-signs an `appcast.xml` (Sparkle
  isn't wired into the app yet, so this is release-side prep only).

## [0.1.0] - 2026-07-09

Initial release.

### Added
- Import receipt PDFs (single or bulk drag-and-drop); each is copied into a local
  vault, rendered to an image, and queued.
- Local vision-model extraction via an OpenAI-compatible endpoint (LM Studio, oMLX,
  etc.), with lenient decoding to tolerate model type drift.
- Sequential processing queue with live `N/M` position and a count-up timer;
  in-progress items are safely re-queued and resumed after a crash or quit.
- Review/edit surface with the source scan side-by-side, editable receipt and
  line-item fields, a distinct AI-suggested vs. user-confirmed common name per item,
  and per-line + overall AI confidence scores.
- Confirm workflow — fields lock once confirmed; list filters by All / Queued /
  Processed / Confirmed / Failed.
- Durable local persistence (Application Support) that survives quit/crash; no
  seeded sample data.
- CSV export (one row per line item) and Postgres export (upsert via `psql`, with
  an auto-migrating schema).
- Context menu: extract/re-process, confirm/unconfirm, reveal source in Finder,
  delete with confirmation.
- Stable ID scheme (`publicID`, `naturalKey`, per-item `stableKey`) so exports join
  cleanly across receipts and stores.
- Packaged as a proper Xcode app via XcodeGen, with bundle id `net.danieldaum.rhea`
  and a generated app icon.

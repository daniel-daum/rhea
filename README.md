<p align="center">
  <img src="Packaging/screenshots/hero.png" width="800" alt="Rhea — receipt list, source scan, and extracted line items side by side">
</p>

<h1 align="center">Rhea</h1>
<p align="center">Turn a folder of scanned grocery receipts into a clean, queryable dataset.</p>

<p align="center">
  <a href="https://git.ts.danieldaum.net/maliciouspickle/rhea/releases">Releases</a> ·
  macOS 14+ · runs fully local
</p>

---

> **In development.** Rhea is a personal tool under active development and has known
> bugs. Expect rough edges, and don't rely on it as your only copy of receipt data.

Drop in receipt PDFs, review each extraction next to the original scan, confirm it,
and export to CSV or Postgres. Extraction runs against your own local vision model
(LM Studio, oMLX, or anything else that speaks the OpenAI chat-completions API) —
nothing leaves your machine.

## Install

Grab the latest `.dmg` from [Releases](https://git.ts.danieldaum.net/maliciouspickle/rhea/releases),
open it, drag Rhea to Applications.

## Build from source

```sh
brew install xcodegen
xcodegen generate
open Rhea.xcodeproj
```

See [AGENTS.md](AGENTS.md) for architecture and internals.

## Run tests

```sh
xcodegen generate
xcodebuild -project Rhea.xcodeproj -scheme Rhea -destination 'platform=macOS' test
```

This runs both `RheaTests` (unit, Swift Testing) and `RheaUITests` (XCUITest) headlessly.

---

<sub>Built with <a href="https://claude.com/claude-code">Claude Code</a>.</sub>

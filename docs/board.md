# Board conventions

Mirrors the pinned Kaneo ticket "📋 Board conventions — read first" (task #2). Applies to
every ticket and PR for [rhea](https://git.danieldaum.net/daniel-daum/rhea).

## Ticket format

Every ticket has: **Problem** (with `file:line` refs into the repo), **Approach**,
**Acceptance criteria** (checkable), and **Out of scope** when relevant. Epics carry the
`epic` label; children are linked as subtasks of their epic.

## Comment rules

1. Moving a task between columns gets a one-line comment saying **why** (e.g. "starting —
   branch `fix/confidence`").
2. Every commit/PR that touches a ticket is linked by URL in a comment (Gitea webhook is
   wired to this project).
3. Decisions made mid-ticket (approach changes, scope cuts) are recorded as comments, not
   just in the code.
4. UI tickets: before-screenshot attached at creation (or referenced from
   `~/Documents/Rhea/board-screenshots` until S3 upload is configured); the closing comment
   must contain an after-screenshot.

## Definition of done

- Acceptance criteria all met.
- Tests added/updated for the changed behavior (once Epic "Test foundation" lands, no
  ticket closes without them).
- `xcodegen generate && xcodebuild build` clean — no new warnings.
- **Never commit personal receipts or real purchase data to the repo.** Test fixtures are
  synthetic.

## Priorities

`high` = do first (robustness/data-safety), `medium` = app quality, `low` = ideas/backlog.

## Commit convention

Simple single-line commits, `type: description` — lowercase, no scope, no period:

- `feat:` a new feature
- `fix:` a bug fix
- `docs:` documentation only
- `style:` formatting, no logic change
- `perf:` performance improvement
- `test:` adding or fixing tests
- `build:` build system or dependencies
- `ci:` ci pipeline or workflows
- `chore:` maintenance, no src change
- `revert:` undo a previous commit

## Branching

Branch `feat/<slug>` or `fix/<slug>`, cut from `main`. Confirm `main` is up to date before
branching, and don't stack work on an unmerged branch.

## Status transitions

- Starting work: `PUT /api/task/status/{id}` with `{"status":"in-progress"}`, plus a
  one-line comment naming the branch.
- Finishing work: comment what changed with commit links
  (`https://git.danieldaum.net/daniel-daum/rhea/commit/<sha>`), then move status to
  `in-review`.

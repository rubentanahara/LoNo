# Architecture

## Purpose
- What the system does, in one or two sentences: Local-first notes app for macOS. Notes live on the user's machine and work offline; optional AWS sync is planned (PRD phases 5-7).
- Who uses it: A single user on one or more desktop machines.

## Layers And Boundaries
| Layer | Responsibility | May depend on | Must not depend on |
|---|---|---|---|
| `core` (`lono-core`) | Domain types and rules (`Note`, `NoteId`, `Clock`). Defines the storage trait. No IO, no UI. | `time`, `uuid` | `storage`, `app`, any IO or UI crate |
| `storage` (`lono-storage`) | Implements the storage trait. SQLite planned. | `core` | `app` |
| `app` (`lono-app`) | Binary. Wires storage and UI. UI logic in plain view-models. | `storage`, `core` | none planned |

Dependencies point inward: `app → storage → core`. Planned crates: `crypto` (phase 6), `sync-proto` and `server` (phase 5).

## Test Seams
- Main seam (where acceptance criteria are tested): `core` public API, with an injected `Clock` for time. Storage sits behind a trait defined in `core`, so `core` tests need no IO. View-models are tested without rendering.

## Directory Map
- `crates/core/`: domain (`src/note.rs`)
- `crates/storage/`: persistence
- `crates/app/`: binary entry point
- `PRD.md`: requirements and phases
- `scripts/agent/`: agent hook and story scripts
- `.husky/`: git hooks (agent flow); `lefthook.yml`: older human hooks

## Data And State
- Source of truth for each dataset (one owner each): Notes: local SQLite, owned by `storage`. The document tree and its versioned JSON format are owned by `core`.
- Persistence: None yet. SQLite with FTS5 planned. Server (Postgres) holds only ciphertext.

## Conventions
- `core` has no IO and no UI dependency, so domain logic stays testable. Permanent.
- Time comes from an injected `Clock`, never `now()` in `core`, so tests are deterministic. Permanent.
- Pin GPUI and gpui-component versions: both are pre-1.0. Remove at 1.0.
- Shared dependency versions live in the root `[workspace.dependencies]`. Permanent.

## Key Decisions
- Modular Cargo workspace / enforces layer direction at compile time / single crate.
- Storage trait in `core` / `core` stays free of IO / `core` depending on `storage`.
- End-to-end encryption, local-only search / server sees only ciphertext / server-side search.
- Notes as structured document tree, Markdown import and export only / WYSIWYG editing / Markdown as storage format.

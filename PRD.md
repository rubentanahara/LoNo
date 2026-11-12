# LoNo — Product Requirements Document

## 1. Overview

LoNo is a local-first desktop notes app for macOS, built in Rust. Notes live on the user's machine and work fully offline. An optional cloud backend on AWS syncs notes between devices. The project is also a learning vehicle: each phase teaches one part of a production Rust stack.

## 2. Goals and non-goals

### Goals
- Fast, native desktop notes app (GPUI + gpui-component).
- WYSIWYG rich text editor. Notes are stored as a structured document tree, with Markdown import and export.
- Embedded web content (for example link previews and embedded pages) through a native macOS webview.
- Offline-first: every feature works without network.
- Optional multi-device sync via a Rust backend on AWS.
- Test-driven development throughout.
- Production practices: observability, QA gates, security scanning, infrastructure as code.

### Non-goals
- Mobile or web clients.
- Windows or Linux builds (macOS only for now).
- Real-time collaborative editing (CRDT) in v1.
- Multi-user sharing of notes in v1.
- Server-side search. The server holds only ciphertext (end-to-end encryption), so search runs locally on decrypted notes (SQLite FTS5).

## 3. Users and use cases

Single user, one or more desktop machines.
- Create, edit, delete and search notes offline.
- Open the app after a crash with no data loss.
- Sign in and see the same notes on a second machine.

## 4. Tech stack

| Area | Choice |
|---|---|
| Language | Rust (pinned via `rust-toolchain.toml`) |
| UI | GPUI + gpui-component |
| Local storage | SQLite |
| Document model | Structured tree (blocks and inline marks), serialized as versioned JSON; owned by `core` |
| Markdown | `pulldown-cmark` (CommonMark parser) for import; exporter for export |
| Rich text editor | Custom GPUI editor (cursor, selection, IME, undo/redo) over the document model; check gpui-component's editor first |
| Web embeds | Native macOS webview (`wry` or `objc2` + WKWebView) hosted beside GPUI; feasibility unverified |
| Local search | SQLite FTS5 over decrypted plain text |
| Encryption | RustCrypto: `chacha20poly1305` (XChaCha20-Poly1305), `argon2` (Argon2id), `zeroize` |
| Key storage | macOS Keychain via the `keyring` crate |
| Backend | Axum + SQLx + Postgres |
| Cloud | AWS (ECS Fargate, RDS, S3, Cognito, CloudFront) |
| IaC | Terraform, remote state in S3 |
| Errors | Sentry (app and backend) |
| Metrics | Prometheus + Grafana |
| CI | GitHub Actions |

## 5. Architecture principles

- Cargo workspace. Dependencies point inward: `app → storage → core`.
- `core` has no IO and no UI dependency.
- Storage is behind a trait defined in `core`.
- UI logic lives in plain view-models, testable without rendering.
- Pin GPUI and gpui-component versions. Both are pre-1.0.

## 6. Planned repository layout

```
notes-app-rust/
├─ Cargo.toml
├─ rust-toolchain.toml
├─ deny.toml
├─ justfile
├─ crates/
│  ├─ core/
│  ├─ storage/
│  ├─ app/
│  ├─ crypto/          (Phase 6)
│  ├─ sync-proto/      (Phase 5)
│  └─ server/          (Phase 5)
├─ infra/              (Phase 7)
│  ├─ modules/
│  └─ envs/{dev,prod}/
└─ .github/workflows/
```

## 7. Phases

Each phase ends with a runnable, verified result. Do not start a phase until the previous one passes its exit criteria.

### Definition of Done

**Task done** when all of these hold:
- Its *Check* passes, and the check was seen failing first where a test applies (red, then green).
- `cargo fmt --check`, `clippy -D warnings` and `nextest` pass locally (CI once a remote exists).
- No new `unwrap`, `expect` or `todo!` outside tests.
- No plaintext note content in logs, errors, metrics or Sentry events.
- Public API and behavior change are reflected in docs or the ADR.
- Change is committed with a message that names the task.

**Phase done** when all of these hold:
- Every task in the phase is done.
- Every *Phase check* passes.
- Every exit criterion is met and demonstrated, not assumed.
- Coverage did not drop below the threshold set so far.
- Open risks for the phase are updated in §9; spike results are recorded in an ADR.
- The app or crate still builds and runs from a clean checkout.
- Phase is tagged in git (`phase-N`) so rollback is one command.

A task or phase that fails any item is not done. Cut scope before relaxing this list.

### Phase 0 — Foundations
**Goal:** working workspace with CI.
**Work:**
- [x] Install Rust toolchain, `cargo-nextest`, `just`.
  - [x] Install `rustup` and stable toolchain.
  - [x] Add `rustfmt` and `clippy` components.
  - [x] Install `cargo-nextest` and `just`.
  - [x] *Check:* `rustc --version`, `cargo nextest --version`, `just --version` succeed.
- [x] Create workspace with `core`, `storage`, `app` crates.
  - [x] Write root `Cargo.toml` with `[workspace]` and shared dependency versions.
  - [x] Create `core` (lib), `storage` (lib) and `app` (bin).
  - [x] Set dependency direction: `app` to `storage` to `core`.
  - [x] Add one failing test in `core`, then make it pass.
  - [x] *Check:* `cargo metadata` lists three members; `cargo build` passes.
- [x] Add `rust-toolchain.toml`, `justfile` (`test`, `lint`, `run`).
  - [x] Pin toolchain channel and components in `rust-toolchain.toml`.
  - [x] Write `just test`, `just lint`, `just run` recipes.
  - [x] Add `.gitignore` and `rustfmt.toml` if needed.
  - [x] *Check:* `just test` and `just lint` exit 0.
- [x] Add CI: `cargo fmt --check`, `clippy -D warnings`, `nextest`.
  - [x] Write the workflow file in `.github/workflows/ci.yml`.
  - [x] Cache cargo registry and `target`.
  - [x] Run the same commands as `just lint` and `just test`.
  - [x] *Check:* run the same three commands locally; all pass. A deliberate fmt error fails them.

**Phase checks:** `cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo nextest run`. `core` has no dependency on `storage` or `app` (`cargo tree -p core`).
**Exit criteria:** CI is green on an empty workspace with one passing test.
**Definition of done:** global phase DoD, plus `phase-0` tag, README states how to run `just test` and `just lint`.
**Learning:** workspaces, crate boundaries, toolchain pinning.

### Phase 1 — Domain core (TDD)
**Goal:** note rules implemented and tested, with no IO.
**Work:**
- [ ] `Note` type: id, title, body (structured document tree), created_at, updated_at.
  - [ ] Write failing constructor test.
  - [ ] Add `NoteId` newtype (UUID).
  - [ ] Implement `Note` with injected clock for timestamps.
  - [ ] *Check:* constructor tests; failing test seen before code.
- [ ] Document model: blocks (paragraph, heading, list, quote, code, image, embed) and inline marks (bold, italic, link, code). Versioned JSON serialization.
  - [ ] Define `Block` and `Inline` enums with marks.
  - [ ] Add `schema_version` field to the serialized root.
  - [ ] Write serde round-trip test per block type.
  - [ ] Store a version-1 JSON fixture file.
  - [ ] *Check:* serialize/deserialize round-trip per block type; old-version fixture still loads.
- [ ] Document edit operations (insert, delete, split, merge, toggle mark) with undo/redo, test-first.
  - [ ] Define `Position`, `Range` and `Edit` types.
  - [ ] Implement insert and delete, one failing test each first.
  - [ ] Implement split and merge across blocks.
  - [ ] Implement toggle mark over a range.
  - [ ] Return an inverse edit from every op; build undo and redo stacks on it.
  - [ ] *Check:* each op has a test; undo then redo restores the exact tree.
- [ ] Markdown import and export, round-trip tests.
  - [ ] Add `pulldown-cmark` to `core`.
  - [ ] Map events to blocks and marks (import).
  - [ ] Serialize tree to Markdown (export).
  - [ ] Build fixture corpus, including unsupported syntax.
  - [ ] *Check:* fixture corpus round-trips; unsupported syntax degrades without panic.
- [ ] Operations: create, edit, delete, plain-text extraction for search.
  - [ ] Implement `create`, `apply_edit`, `delete` on notes.
  - [ ] Update `updated_at` on every change.
  - [ ] Implement `plain_text()` over the tree.
  - [ ] *Check:* extraction test covers every block and mark type.
- [ ] Error type with `thiserror`.
  - [ ] Define `CoreError` variants.
  - [ ] Replace any panic path with a returned error.
  - [ ] Enable `clippy::unwrap_used` for non-test code.
  - [ ] *Check:* every fallible public fn returns it; no `unwrap` outside tests (`clippy::unwrap_used`).
- [ ] Property tests with `proptest` (edit keeps id; updated_at never goes backward).
  - [ ] Write strategies that generate valid trees and edits.
  - [ ] Property: edit keeps id.
  - [ ] Property: `updated_at` never decreases.
  - [ ] Property: apply then undo returns the original tree.
  - [ ] *Check:* run with 1000+ cases, no shrunk failure.

**Phase checks:** `cargo nextest run -p core`; `cargo llvm-cov -p core --fail-under-lines 90`; `cargo tree -p core` shows no IO or UI crates.
**Exit criteria:** all tests written before the code; core coverage ≥ 90%.
**Definition of done:** global phase DoD, plus git history shows tests committed before or with the code; `core` has zero IO or UI dependencies; JSON schema version documented.
**Learning:** red-green-refactor, ownership, error design.

### Phase 2 — Storage
**Goal:** notes persist locally.
**Work:**
- [ ] `NoteRepository` trait in `core`.
  - [ ] Define methods: create, get, update, delete, list, search.
  - [ ] Define repository error type.
  - [ ] *Check:* `core` still compiles with no IO crates.
- [ ] In-memory implementation.
  - [ ] Implement trait over a `HashMap`.
  - [ ] Implement naive substring search.
  - [ ] *Check:* passes contract suite.
- [ ] SQLite implementation with migrations.
  - [ ] Choose driver and migration tool (check current docs first).
  - [ ] Write `001_init.sql`: notes table with JSON body.
  - [ ] Implement trait on SQLite; open file with WAL mode.
  - [ ] Run migrations on startup.
  - [ ] *Check:* migrate empty DB and previous-schema DB; both reach latest version.
- [ ] One shared contract test suite run against both implementations.
  - [ ] Write suite as generic functions over `impl NoteRepository`.
  - [ ] Cover create, get, update, delete, list order, missing id, search.
  - [ ] Run the suite from both implementation test files.
  - [ ] *Check:* same test source runs twice; a bug injected in one impl fails it.
- [ ] Local full-text search: SQLite FTS5 index of each note's plain text, rebuilt from the documents.
  - [ ] Add FTS5 virtual table in a migration.
  - [ ] Update the index in the same transaction as each write.
  - [ ] Add `rebuild_index()` from stored documents.
  - [ ] Escape user query input for FTS5 syntax.
  - [ ] *Check:* find by body word; deleted note not found; index rebuild gives identical results.

**Phase checks:** `cargo nextest run -p storage`; restart test (write, reopen file, read back).
**Exit criteria:** both implementations pass the same contract tests; data survives app restart; search finds notes by body text.
**Definition of done:** global phase DoD, plus migrations are forward-only and tested; contract suite is the only source of repository behavior tests.
**Learning:** traits, migrations, integration tests.

### Phase 3 — GPUI app
**Goal:** usable offline notes UI.
**Work:**
- [ ] Empty window, then note list, editor and sidebar using gpui-component.
  - [ ] Add `gpui` and `gpui-component` (check current docs first).
  - [ ] Open an empty window.
  - [ ] Add sidebar, list pane and editor pane layout.
  - [ ] Wire `SqliteRepository` at startup.
  - [ ] *Check:* `just run` opens the window; manual smoke.
- [ ] View-models for list, editor and search state.
  - [ ] `ListViewModel`: load, select, delete.
  - [ ] `EditorViewModel`: open note, apply edit, save.
  - [ ] `SearchViewModel`: query, results, clear.
  - [ ] Views only read view-model state.
  - [ ] *Check:* tested without rendering.
- [ ] Keyboard shortcuts (new, save, search, delete) via GPUI actions.
  - [ ] Declare actions for the four commands.
  - [ ] Bind keys (`cmd-n`, `cmd-s`, `cmd-f`, `cmd-backspace`).
  - [ ] Handle each action by calling a view-model method.
  - [ ] *Check:* action dispatch tests; each shortcut works manually.
- [ ] Read-only document renderer: draw the document tree with GPUI elements. Open links only on explicit click.
  - [ ] Render each block type.
  - [ ] Render inline marks (bold, italic, code, link).
  - [ ] Handle link click only; confirm the URL scheme before opening.
  - [ ] *Check:* every block type renders; hover or load never opens a link.
- [ ] Temporary plain-text editing of the note body until Phase 3B.
  - [ ] Use a plain text input bound to the note body.
  - [ ] Convert text to paragraphs on save.
  - [ ] Save on action and on blur.
  - [ ] *Check:* edit persists after restart.
- [ ] View-model tests with `TestAppContext`.
  - [ ] Test list, editor and search view-models with the in-memory repository.
  - [ ] Test each action handler.
  - [ ] Add the app tests to `just test` and CI.
  - [ ] *Check:* run in CI headless.

**Phase checks:** `cargo nextest run -p app`; manual offline run (network off): create, edit, search, delete.
**Exit criteria:** user can create, edit, search and delete notes fully offline; view-model tests pass in CI.
**Definition of done:** global phase DoD, plus manual offline walkthrough recorded; no business logic inside render code.
**Learning:** GPUI entities, contexts, actions, render model.
**Risk:** GPUI docs are thin. Use Zed source and gpui-component examples as reference.

### Phase 3B — Rich text editor
**Goal:** WYSIWYG editing of the document tree.
**Work:**
- [ ] Spike first: evaluate gpui-component Input/Editor against the document model. Record result in an ADR.
  - [ ] List what the component supports: marks, blocks, IME, selection.
  - [ ] Build a throwaway prototype bound to a document.
  - [ ] Write ADR: keep or build custom, with rejected alternatives.
  - [ ] *Check:* ADR states keep or build custom, with reasons.
- [ ] Editor view bound to the document model: caret, selection, mouse and keyboard navigation.
  - [ ] Model caret and selection as document positions.
  - [ ] Map pixel position to document position (hit testing).
  - [ ] Arrow, word, line and block navigation.
  - [ ] Shift-select, mouse drag, double and triple click.
  - [ ] *Check:* caret and selection tests across block boundaries.
- [ ] macOS text input (IME, dead keys, emoji) through GPUI's input handler.
  - [ ] Implement GPUI's `EntityInputHandler`.
  - [ ] Support marked (composing) text and its replacement.
  - [ ] Report caret bounds so the IME window places correctly.
  - [ ] *Check:* manual: Japanese IME, `Option+E` dead key, emoji picker.
- [ ] Formatting toolbar and shortcuts: bold, italic, link, headings, lists, quote, code.
  - [ ] Add one view-model command per format.
  - [ ] Bind `cmd-b`, `cmd-i`, `cmd-k` and others.
  - [ ] Build toolbar showing active state at the caret.
  - [ ] *Check:* one view-model test per command; toggle on then off restores the tree.
- [ ] Markdown shortcuts as you type (for example `# ` makes a heading).
  - [ ] Build rule table: prefix pattern to block type.
  - [ ] Add inline rules (`**bold**`, `` `code` ``).
  - [ ] Make backspace right after a conversion undo it.
  - [ ] *Check:* table-driven tests; undo reverts the conversion in one step.
- [ ] Paste and copy, including plain text and Markdown paste.
  - [ ] Copy selection as plain text and as Markdown.
  - [ ] Paste plain text as paragraphs.
  - [ ] Detect and import Markdown on paste.
  - [ ] Cap paste size.
  - [ ] *Check:* round-trip copy then paste keeps marks; hostile paste (huge, odd Unicode) does not crash.
- [ ] Undo/redo wired to the core operations.
  - [ ] Bind `cmd-z` and `cmd-shift-z`.
  - [ ] Group typing into one undo step per word or pause.
  - [ ] Restore caret and selection on undo.
  - [ ] *Check:* random edit sequences undo to the original.
- [ ] View-model tests for every edit command; render snapshot tests for key blocks.
  - [ ] List every edit command and mark each with its test.
  - [ ] Add snapshots for heading, list, quote, code and marks.
  - [ ] *Check:* snapshots reviewed, not blind-accepted.

**Phase checks:** `cargo nextest run`; manual 10-minute writing session; Markdown export diff against expected.
**Exit criteria:** user writes and formats a note without leaving the editor; every edit is covered by a core test; Markdown export of the note is correct.
**Definition of done:** global phase DoD, plus editor spike ADR written; IME manual test passed; cut scope listed in §9, not silently dropped.
**Learning:** text editing internals, input methods, document models.
**Risk:** highest-effort phase. Text editing in GPUI is custom work, and GPUI accessibility is immature. Cut scope (tables, images, nested lists) before cutting tests.

### Phase 3C — Embedded web content
**Goal:** show web content inside a note.
**Work:**
- [ ] Spike first (timebox 3 days): can a WKWebView child view live inside a GPUI window, with correct sizing, scrolling, focus and z-order? Record the result in an ADR.
  - [ ] Get the native window handle from GPUI.
  - [ ] Attach a `WKWebView` as a child view.
  - [ ] Test sizing, scroll, focus, z-order, resize and note switching.
  - [ ] Record go or no-go and rejected alternatives in an ADR.
  - [ ] *Check:* ADR has go/no-go and a screen recording of sizing, scroll, focus, z-order.
- [ ] Embed block in the document model: URL plus display mode.
  - [ ] Add `Embed { url, mode }` block; bump schema version with migration.
  - [ ] Validate URL scheme on construction.
  - [ ] Add Markdown import and export for embeds.
  - [ ] *Check:* serialization and Markdown round-trip tests; only `http(s)` URLs accepted.
- [ ] Sandboxed webview: JavaScript allowed per embed only, navigation restricted to the embed's origin, no access to app data, no cookies shared between embeds.
  - [ ] Use a non-persistent data store per embed.
  - [ ] Add navigation delegate that denies other origins.
  - [ ] Disable JavaScript unless the embed opts in.
  - [ ] Expose no script message handlers or app bridge.
  - [ ] *Check:* tests: cross-origin navigation blocked; two embeds share no cookies; page cannot read app data.
- [ ] Link cards (title, image, domain) as the fallback when the webview cannot be used.
  - [ ] Render card with domain only (no network).
  - [ ] Fetch title and image only on user action.
  - [ ] Click opens the system browser.
  - [ ] *Check:* renders with metadata and without it.
- [ ] Network access only when the user opens or loads an embed; offline shows the card.
  - [ ] Create the webview only after an explicit "Load" click.
  - [ ] Detect offline and keep the card.
  - [ ] Destroy the webview when the note closes.
  - [ ] *Check:* open a note with embeds while offline or with a network monitor: zero requests before user action.

**Phase checks:** sandbox test suite; manual run with network off.
**Exit criteria:** an embed renders and scrolls inside a note on macOS; sandbox tests confirm blocked cross-origin navigation; offline shows the fallback card.
**Definition of done:** global phase DoD, plus spike ADR records go or no-go; sandbox rules documented; zero network requests before user action.
**Learning:** native view interop, web sandboxing.
**Risk:** GPUI renders with its own GPU surface, so mixing a native webview may fail or flicker. If the spike fails, ship link cards only and record the decision.

### Phase 4 — Quality and security gates
**Goal:** automated checks block bad changes.
**Work:**
- [ ] Coverage: `cargo-llvm-cov`.
  - [ ] Install tool (check current docs first).
  - [ ] Add `just coverage` recipe.
  - [ ] Set thresholds: `core` 90%, others a measured baseline.
  - [ ] Add CI step.
  - [ ] *Check:* CI fails when coverage drops below threshold.
- [ ] Mutation testing: `cargo-mutants` on `core`.
  - [ ] Install and run on `core`.
  - [ ] Triage missed mutants; add tests for real gaps.
  - [ ] Add scheduled or per-PR CI job (changed files only).
  - [ ] *Check:* missed mutants listed; each fixed or justified.
- [ ] Dependency security: `cargo-audit`, `cargo-deny`.
  - [ ] Write `deny.toml`: advisories, licenses, bans, sources.
  - [ ] Add both tools to CI.
  - [ ] Document any ignored advisory with a reason.
  - [ ] *Check:* CI fails on a pinned known-vulnerable crate and on a disallowed license.
- [ ] Secret scanning: `gitleaks`.
  - [ ] Add `.gitleaks.toml` with allowlist for test fixtures.
  - [ ] Add pre-commit hook and CI step.
  - [ ] Scan full git history once.
  - [ ] *Check:* CI fails on a planted fake secret.
- [ ] Sentry in the app for crashes and errors (opt-in).
  - [ ] Add Sentry SDK (check current docs first).
  - [ ] Add opt-in setting, default off.
  - [ ] Add `before_send` scrubber that drops note content and paths.
  - [ ] Capture panics and errors.
  - [ ] *Check:* nothing sent while opt-out; scrub test shows no note content in events.

**Phase checks:** all gates run in CI on a PR; each gate shown red once, then green.
**Exit criteria:** CI fails on a known vulnerable dependency, a leaked test secret and a coverage drop; a deliberate crash appears in Sentry.
**Definition of done:** global phase DoD, plus each gate shown red then green; thresholds and accepted false positives documented.
**Learning:** what each tool catches and its false-positive cost.

### Phase 5 — Backend
**Goal:** a tested API for storing notes.
**Work:**
- [ ] `sync-proto` crate: shared request/response types. Note content is an opaque encrypted blob; the server never sees plaintext.
  - [ ] Define `PushRequest`, `PullResponse`, `EncryptedNote`.
  - [ ] Include id, version, timestamps, size, blob bytes only.
  - [ ] Add protocol version field.
  - [ ] *Check:* type has no plaintext field; serde round-trip tests.
- [ ] `server` crate: Axum, SQLx, Postgres (Docker for local).
  - [ ] Scaffold Axum app with config from environment.
  - [ ] Add `docker-compose.yml` for local Postgres.
  - [ ] Write SQLx migrations: accounts, notes (blob, version, deleted).
  - [ ] Add graceful shutdown and request IDs.
  - [ ] *Check:* migrations apply to empty Postgres; `cargo sqlx prepare --check` passes.
- [ ] Endpoints: health, push changes, pull changes since a version.
  - [ ] `GET /health`.
  - [ ] `POST /v1/push` with version check in one transaction.
  - [ ] `GET /v1/pull?since=` with a page limit.
  - [ ] Auth middleware (stub until Phase 6).
  - [ ] Cap request body size.
  - [ ] *Check:* push then pull returns the change; stale version and malformed body get 4xx; unauthenticated gets 401.
- [ ] Tests with `testcontainers` and `wiremock`.
  - [ ] Start Postgres per test run via `testcontainers`.
  - [ ] Write endpoint integration tests.
  - [ ] Mock external auth with `wiremock`.
  - [ ] *Check:* run in CI with real Postgres.
- [ ] `/metrics` endpoint for Prometheus; Sentry integration.
  - [ ] Add request count, latency and error metrics.
  - [ ] Expose `/metrics` (not public in prod).
  - [ ] Add Sentry with body scrubbing.
  - [ ] *Check:* `curl /metrics` shows request counters; no blob content in logs or Sentry.

**Phase checks:** `cargo nextest run -p server -p sync-proto`; load smoke: 100 concurrent pushes without error.
**Exit criteria:** API integration tests pass in CI against a real Postgres; metrics scrape successfully.
**Definition of done:** global phase DoD, plus API contract documented; server holds no plaintext (schema review); migrations tested on empty and populated DB.
**Learning:** async Rust, HTTP API design, observability basics.

### Phase 6 — End-to-end encryption and sync
**Goal:** notes sync between two machines; only the user's devices can read them.
**Work (encryption, first):**
- [ ] `crypto` crate, test-first, no UI or network dependency.
  - [ ] Create crate; pick audited RustCrypto dependencies (check current docs first).
  - [ ] Define key newtypes with `Zeroize` and no `Debug` output.
  - [ ] *Check:* `cargo tree -p crypto` shows no UI or network crates.
- [ ] Key model: a random 256-bit data key encrypts notes. A key-encryption key derived from the user's passphrase with Argon2id wraps the data key. The wrapped key is uploaded; the passphrase and the plain data key never leave the device.
  - [ ] Generate a 256-bit data key from the OS random source.
  - [ ] Derive the key-encryption key with Argon2id; store salt and parameters with the wrapped key.
  - [ ] Wrap and unwrap the data key with an AEAD.
  - [ ] Write `docs/adr/` entry for the key hierarchy.
  - [ ] *Check:* unwrap with correct passphrase returns the key; wrong passphrase fails.
- [ ] Encrypt title and body per note with XChaCha20-Poly1305. Use a fresh random nonce per encryption. Bind note id and version as associated data so the server cannot swap blobs.
  - [ ] Serialize note to bytes; include the schema version inside the payload.
  - [ ] Build associated data from id and version.
  - [ ] Encrypt with a fresh nonce; prefix nonce to the blob.
  - [ ] Implement decrypt with strict length checks.
  - [ ] *Check:* same plaintext encrypts to different ciphertext; swapped id or version fails to decrypt.
- [ ] Store the unwrapped data key in the macOS Keychain; zeroize key material in memory.
  - [ ] Add Keychain wrapper behind a trait; in-memory fake for tests.
  - [ ] Save, load and delete the key.
  - [ ] Zeroize on drop; avoid copies.
  - [ ] *Check:* key survives restart; key types implement `Zeroize` and have no `Debug` or `Clone` leak.
- [ ] Recovery key: generate a random recovery key at setup and show it once. The passphrase has no reset path, because the server cannot decrypt.
  - [ ] Generate a recovery key and encode it for humans.
  - [ ] Wrap the data key a second time with it.
  - [ ] Setup screen: show once, require confirmation.
  - [ ] Add a data-loss warning text.
  - [ ] *Check:* recovery key unwraps the data key; UI cannot show it a second time.
- [ ] Second device: enter the passphrase, download the wrapped key, unwrap locally.
  - [ ] Add endpoint pair for the wrapped key.
  - [ ] Build unlock flow.
  - [ ] Store the unwrapped key in Keychain.
  - [ ] *Check:* two-device integration test.
- [ ] Known-answer tests, tamper tests (flipped bit fails to decrypt), wrong-passphrase tests.
  - [ ] Add known-answer vectors for the AEAD and Argon2id.
  - [ ] Flip each byte region (nonce, ciphertext, tag) and expect failure.
  - [ ] Test wrong passphrase and wrong recovery key.
  - [ ] *Check:* all pass; Argon2id parameters pinned by test.

**Work (sync):**
- [ ] Per-note version counter and tombstones for deletes.
  - [ ] Add `version` and `deleted` to storage and sync types.
  - [ ] Increment version on every local change.
  - [ ] Keep tombstones; purge policy documented.
  - [ ] *Check:* delete on A reaches B; deleted note does not reappear.
- [ ] Last-write-wins conflict rule (documented).
  - [ ] Write the rule and tie-breaker in an ADR.
  - [ ] Implement the resolver in a pure function.
  - [ ] Keep the losing version recoverable (local history) or document the loss.
  - [ ] *Check:* table-driven conflict tests match the documented rule.
- [ ] Offline change queue with retry and backoff.
  - [ ] Persist queue in SQLite.
  - [ ] Collapse repeated edits to one note.
  - [ ] Retry with exponential backoff and jitter.
  - [ ] Show sync state in the UI.
  - [ ] *Check:* queue survives restart; server down then up drains the queue in order.
- [ ] Authentication with Cognito tokens.
  - [ ] Stand up a dev user pool (or local stub before Phase 7).
  - [ ] Validate JWT signature, issuer, audience and expiry on the server.
  - [ ] Store tokens in Keychain; refresh on expiry.
  - [ ] *Check:* expired token refreshes; invalid token gets 401 and queue holds.
- [ ] Conflict and offline tests.
  - [ ] Build a two-client test harness with a fake network.
  - [ ] Inject failures: drop, delay, duplicate.
  - [ ] Assert both clients converge.
  - [ ] *Check:* two-instance convergence test, including random offline edit order.

**Phase checks:** `cargo nextest run -p crypto -p app`; `grep` Postgres dump and server logs for a known plaintext marker: zero hits.
**Exit criteria:** two app instances converge after offline edits; the server database and logs contain no plaintext note content; tamper and wrong-passphrase tests pass; tests cover conflict and network failure.
**Definition of done:** global phase DoD, plus security review of `crypto` done; LWW rule and data-loss warning documented; passphrase and recovery key never logged.
**Learning:** applied cryptography, key management, the hard parts of local-first software.
**Visible to the server (accepted):** note ids, version numbers, timestamps, blob sizes and the account id. Hiding metadata is out of scope.
**Risk:** forgotten passphrase and lost recovery key mean permanent data loss. Do not design around this; document it in the UI.
**Review:** have a security review of the `crypto` crate before release. Never write custom primitives.

### Phase 7 — AWS and Terraform
**Goal:** backend runs in AWS from code only.
**Work:**
- [ ] Remote state in S3 with locking.
  - [ ] Bootstrap state bucket with versioning and encryption.
  - [ ] Configure the locking mechanism (check current docs first).
  - [ ] Block public access on the bucket.
  - [ ] *Check:* second concurrent `plan` is blocked by the lock.
- [ ] Modules: network, RDS, ECS Fargate, Cognito, S3/CloudFront.
  - [ ] `network`: VPC, private subnets, endpoints.
  - [ ] `rds`: Postgres, private, encrypted, backups.
  - [ ] `ecs`: Fargate service, ALB, health check, log group.
  - [ ] `cognito`: user pool and app client.
  - [ ] `s3-cloudfront`: update bucket with origin access control.
  - [ ] *Check:* `terraform validate` and `terraform plan` per module; RDS not publicly accessible.
- [ ] Environments: dev first, prod later.
  - [ ] Create `envs/dev` composing the modules.
  - [ ] Add budget alarm.
  - [ ] Add `just up` and `just down` wrappers.
  - [ ] *Check:* dev plan shows no prod resources.
- [ ] Scan with `tfsec` and `checkov` in CI.
  - [ ] Add both scanners to CI.
  - [ ] Fix findings or suppress each with a written reason.
  - [ ] *Check:* CI fails on a planted open security group.
- [ ] Least-privilege IAM; secrets in AWS Secrets Manager.
  - [ ] Write task role and execution role with scoped policies.
  - [ ] Store the DB password in Secrets Manager; inject into the task.
  - [ ] Review policies for wildcards.
  - [ ] *Check:* no wildcard `*` actions without justification; no secret in state or repo (`gitleaks`).

**Phase checks:** `terraform fmt -check`, `validate`, scanners; budget alarm exists; deployed `/health` returns 200.
**Exit criteria:** `terraform apply` creates dev from scratch; `destroy` removes it; scanners pass.
**Definition of done:** global phase DoD, plus no console-created resources (drift check shows none); monthly cost estimate written; dev torn down after use.
**Learning:** IaC, IAM, cost control.

### Phase 8 — Release and operate
**Goal:** signed builds and monitored service.
**Work:**
- [ ] Build signed, notarized macOS app in CI.
  - [ ] Bundle the app with `cargo-bundle` or equivalent (check current docs first).
  - [ ] Store certificate and notary credentials as CI secrets.
  - [ ] Sign with hardened runtime; notarize; staple.
  - [ ] *Check:* `codesign --verify --deep --strict` and `spctl --assess` pass; app opens on a clean Mac.
- [ ] Auto-update via S3/CloudFront.
  - [ ] Choose updater (check current docs first).
  - [ ] Sign update manifests with a separate key.
  - [ ] Publish artifact and manifest from CI.
  - [ ] Add in-app update check and prompt.
  - [ ] *Check:* old build updates to new; tampered update package rejected.
- [ ] Grafana dashboards: request rate, error rate, latency.
  - [ ] Stand up Prometheus scrape of `/metrics`.
  - [ ] Build three panels; store dashboard JSON in the repo.
  - [ ] *Check:* panels show live data under load.
- [ ] Alerts on error rate and health check failure.
  - [ ] Define thresholds and notification channel.
  - [ ] Add alert rules as code.
  - [ ] *Check:* induced failure fires an alert within target time.
- [ ] Runbook for common failures.
  - [ ] List failures: DB down, bad deploy, cert expiry, sync backlog.
  - [ ] Write detect, diagnose, fix, rollback steps for each.
  - [ ] *Check:* a second person follows it once for one failure.

**Phase checks:** full release dry run from a tag; rollback to previous build works.
**Exit criteria:** a released build updates itself; an induced backend failure triggers an alert.
**Definition of done:** global phase DoD, plus runbook walked through once; signing keys stored outside the repo; rollback to previous release tested.
**Learning:** packaging, notarization, monitoring.

## 8. Cross-cutting requirements

- **TDD:** tests precede code in every phase.
- **Security:** no secrets in the repo; telemetry is opt-in; data in transit uses TLS.
- **Privacy:** note content never goes to Sentry or Prometheus or logs.
- **Encryption at rest (local):** v1 relies on macOS FileVault for the local SQLite file. Notes are encrypted before upload only. SQLCipher is a later option.
- **Quality bar:** CI must pass before merge.
- **Documentation:** record each architecture decision (context, decision, consequences, rejected alternatives) in `docs/adr/`.

## 9. Risks

| Risk | Mitigation |
|---|---|
| GPUI API breaks between versions | Pin versions; isolate GPUI in `app` crate |
| GPUI accessibility is immature | Accept for v1; document the limit |
| Custom rich text editor is large and bug-prone | Core-first with tests; separate phase (3B); cut features before tests |
| Native webview may not embed in GPUI | Day-one spike; link-card fallback; ADR records the outcome |
| Embedded web pages leak data or run hostile scripts | Per-embed sandbox, origin lock, no shared cookies, user-initiated loads |
| Document tree changes break old notes and encrypted blobs | Versioned JSON schema; migration tests; version stored inside encrypted payload |
| Sync conflicts lose data | Tombstones, LWW rule documented, conflict tests |
| AWS cost surprises | Dev environment only until Phase 8; budget alarm; `destroy` after sessions |
| Scope creep | Phase exit criteria are the only definition of done |

## 10. Open questions

- Does a native webview embed in GPUI? Answer in the Phase 3C spike (timebox: 3 days; fallback: link cards).

Resolved:
- 3B editor: build custom on GPUI primitives. First evaluate gpui-component Input/Editor in a 3B spike.
- SQLCipher: not in v1. E2EE protects server data. Revisit local at-rest encryption after v1.
- Windows/Linux: not in v1. Keep `core` and `storage` platform-neutral.
- Git: local repo only until Phase 4. Push to GitHub then.

Decided: name is LoNo; macOS only for now; full WYSIWYG rich text in v1 (structured document, Markdown import/export via `pulldown-cmark`); native webview embeds in v1 (spike-gated); local-only search; end-to-end encryption required.

## 11. Success criteria

- Every phase's exit criteria are met.
- App works fully offline and syncs two machines.
- Infrastructure is reproducible from Terraform alone.
- CI enforces tests, lint, coverage and security scans.

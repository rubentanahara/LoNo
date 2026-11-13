# AGENTS.md

LoNo: local-first macOS desktop notes app in Rust (stable toolchain pinned in `rust-toolchain.toml`, edition 2024). Cargo workspace: `core`, `storage`, `app`. Spec: `PRD.md`.

## Hard rules
1. Never edit or delete a test to make it pass. Fix the code. Change a test only when the requirement changed, and say so.
2. Never silence analyzers or linters: no ignore pragmas, no disabled rules, no lowered severities.
3. Add dependencies only after asking, and check the current docs of the package first.
4. Commit, push and open pull requests only when asked. Use Conventional Commits (`.husky/commit-msg` enforces it). Work on a feature branch and open a PR to `main` with `gh pr create`. Never push to `main` and never force-push (`.husky/pre-push` refuses both).
5. Never edit `feature_list.json` by hand. Use `scripts/agent/feature.sh`.
6. Never commit secrets. `.husky/pre-commit` runs gitleaks.
7. TDD with two commits per feature. First `test(red): <what>`: tests only, plus stubs so it compiles, and `make test` must fail. Then the implementation commit, and `make check` must pass. A source commit with no `test(red)` commit on the branch is refused. If a change needs no tests, add a `No-Tests: <reason>` line to the commit message. `.husky/commit-msg` enforces this through `scripts/agent/tdd-gate.sh`.

## Commands
- `make setup`: first run. Installs dependencies and points git at `.husky`.
- `make check`: the only definition of green. It prints `OK   <step>` as each step passes, then `CHECK PASSED`, or `CHECK FAILED at <step>` with the failing lines. Each step writes its full output to `.agent/`.
- `make format`: fixes formatting automatically.
- `make test-story FILTER=<filter>`: runs only the tests a story selects.
- `make run`: starts the app.
- Prefer these targets over raw tool commands. `Makefile` wraps `cargo`; `justfile` and `lefthook.yml` are the older human workflow.
- No `unwrap`, `expect` or `todo!` outside tests. No plaintext note content in logs, errors or metrics (`PRD.md` §7).

## Read only what your task needs
| Read | When |
|---|---|
| `ARCHITECTURE.md` | Before you add, move or rename code: layers, boundaries, conventions |
| `GUARDRAILS.md` | A command, hook or permission blocks you, or you change a hook, permission, CI or branch protection |
| `SECURITY.md` | You touch secrets, auth, input handling or agent permissions |
| `session-handoff.md` | A long session ended and the next one needs a compact brief |
| `docs/prd/<feature>.md#FR-<n>` | Only the section a story's `prd` field names |

## One story at a time
- `scripts/agent/feature.sh start <id>` before writing code, `show <id>` to read the story, `status` and `waves` for what is open. Do not read the whole `feature_list.json`.
- Touch only what the active story needs: `feature.sh done` refuses files outside its `owns`. Note unrelated problems in `PROGRESS.md` instead of fixing them.
- `feature.sh block <id> "<reason>"` when something outside the repo stops you.
- Small fixes and questions need no story. The Definition of Done still applies.
- Skills: `prd`, `backlog`, `feature`, `tdd`, `verify`, `ship`, `handoff`, `grilling`, `prompt-rewrite` (in `.claude/skills`).

## Session routine
- Start: the session-start hook injects the `make check` result, the backlog status and `PROGRESS.md`. If that context is missing, read `PROGRESS.md`, run `scripts/agent/feature.sh status`, then `make check` before editing.
- End: walk `clean-state-checklist.md`, update `PROGRESS.md` (state, decisions with their reasons, next steps), run `make check`, and leave no stray files.

## Definition of Done
- `make check` prints `CHECK PASSED`. Quote that line in your final message. "Should work" is not done.
- New behavior has a test that fails without the change.
- Feature work: `scripts/agent/feature.sh done <id>` succeeded.
- `PROGRESS.md` says what changed, why, and what comes next.
- When you finish, a stop hook runs `make check` on any uncommitted change and sends you back with the failing lines if it fails. It also sends you back when files changed during the session but `PROGRESS.md` did not.

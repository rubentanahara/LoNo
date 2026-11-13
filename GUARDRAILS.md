# Guardrails

Read this when a command, hook or permission blocks you, or before you change a hook, a permission, CI or branch protection.
Each guardrail names what enforces it, why it exists, and when it can go.

## What every CLI gets
| Guardrail | Enforced by | Why | Remove when |
|---|---|---|---|
| Session-start context: `make check` result, backlog, `PROGRESS.md` | `.claude/settings.json`, `.codex/hooks.json`, `.github/hooks/session-kickoff.json` | A session starts from the real state, not from memory | never |
| Stop is refused while `make check` fails (3 attempts, then the agent must report the failure) | `scripts/agent/stop-gate.sh` | "Should work" is not done | never |
| Stop is refused while files changed but `PROGRESS.md` did not | `scripts/agent/stop-gate.sh` | The next session needs to know what changed and why | never |
| Conventional Commits, no AI attribution in commit messages | `.husky/commit-msg` | Readable history | never |
| Red commit (`test(red):`, tests fail) before any source commit; source commits need `make check` green, or a `No-Tests:` line | `.husky/commit-msg` via `scripts/agent/tdd-gate.sh` | Every change has a test that failed first | `No-Tests: <reason>` |
| No secrets in commits | `.husky/pre-commit` (gitleaks) | Secrets never reach the remote | never |
| No push to `main`, no push that drops pushed commits | `.husky/pre-push` | `main` changes only through a pull request | never |
| Format, lint, build, tests | `make check`, required by CI on every pull request | One definition of green | never |
| Story stays inside its `owns` | `feature.sh done` | Stories in one wave must not touch the same files | never |
| Independent review cannot change files | `verify` skill, run in a fresh session or subagent | A reviewer that edits grades its own work | never |
| `main` changes only through a reviewed PR with a green `check` | branch protection on GitHub | The last line when every local guardrail is bypassed | never |

## Where the CLIs differ
| Guardrail | Claude Code | Codex | Copilot CLI |
|---|---|---|---|
| Push to `main`, force-push before git runs | `permissions.deny` in `.claude/settings.json` | add rules in `.codex/rules` | nothing in the CLI; `.husky/pre-push` refuses when git runs |
| Editing `feature_list.json` | denied for the Edit tool only; a shell write still works | nothing local | nothing local |
| Reading `.env` | denied | nothing local | nothing local |

## Known gaps
- `git push --no-verify` skips the git hooks, and a clone where `make setup` never ran has no git hooks. Branch protection on GitHub is the backstop.
- Copilot CLI does not apply the deny rules in `.claude/settings.json`, so the git hooks and branch protection are its only push guards.
- A user-level `PreToolUse` hook that rewrites and approves a Bash command can bypass the Claude deny rules.
- Claude Code keeps at most 10,000 characters of a hook's output. `session-start.sh` cuts its context to 9,000.
- Two sessions in one checkout can blame each other in the stop gate. Use separate worktrees.

## Changing a guardrail
- Hook logic lives only in `scripts/agent/`. `.codex/hooks.json` must match the hooks in `.claude/settings.json`: `make check` fails at `hooks` when they differ.
- Never weaken a guardrail to get unblocked: no `--no-verify`, no disabled lint rule. Fix the cause, or `feature.sh block` the story with the reason.
- Update this file in the same pull request.

## Lessons learned
- 2026-11-11: `lefthook.yml`/`justfile` (human flow) and `.husky`/`Makefile` (agent flow) coexist. Use `make check` as the only definition of green; `just` recipes are a subset.

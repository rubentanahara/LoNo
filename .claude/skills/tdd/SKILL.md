---
name: tdd
description: Test-driven development. One acceptance criterion at a time, a failing test at the public boundary first, then the least code that passes it. Use when building a story, fixing a bug test-first, or when asked for red-green-refactor or integration tests.
---

# Test-driven development

The red to green loop. The goal is tests that state behavior, survive refactors, and prove each acceptance criterion.

## Seams: where tests go
A seam is the public boundary where behavior is observed. Test there, never against internals. Find the project's seams in `ARCHITECTURE.md` (for example HTTP endpoint, public function, CLI command).

When working a story, each acceptance criterion gets at least one test at the main seam, in the files the story's `test_filter` selects. Outside a story, agree the seams with the user before writing tests.

## The loop
For each acceptance criterion, in order:
1. **Red.** Write one test for the criterion. Add only the types it needs to compile, so it fails on its assertion, not on the build. Run it alone with `make test-story FILTER=<name>` and read the failure.
   A test that passes before the change proves nothing. Fix the test until it fails for the reason the criterion states.
2. **Green.** Write the least code that makes it pass. Do not build ahead for a later criterion.
3. Run the story's whole filter so earlier criteria stay green. Then take the next criterion.

## Commits (enforced by `.husky/commit-msg`)
- After Red, when the tests fail for the right reason, commit: `test(red): <criterion>`. The hook runs `make test` and refuses the commit if it passes.
- After Green and `make check` passes, commit the implementation (`feat: ...`). The hook refuses it if the branch has no `test(red)` commit or `make check` fails.
- No tests needed (config, docs, rename)? Add `No-Tests: <reason>` to the commit message and say so to the user.
- Commit only when the user asks (`AGENTS.md` rule 4).

After the last criterion: `make format`, then `make check`. Refactoring belongs after `make check` passes, never inside the loop.

## What a good test looks like
- Name: `Action_Condition_Result`, or the language's convention. The name reads as the criterion.
- One behavior per test. Arrange, act and assert are separated by blank lines.
- Expected values come from the criterion or a literal, never recomputed the way the code computes them.

## Anti-patterns
- **Implementation-coupled:** querying storage to check a write, asserting how often a substitute was called, testing private methods. Check through the public boundary instead: create, then read.
- **Tautological:** the expected value is computed the same way as the code, so the test can never disagree with it.
- **Horizontal slicing:** writing every test first and then all the code. Work one criterion at a time; each test responds to what the last cycle taught you.
- **Changing a test to make it pass.** `AGENTS.md` forbids it. Change a test only when the requirement changed, and say so.

## Substitutes
Substitute only boundaries: storage interfaces, time, and external services. Never substitute your own domain code.

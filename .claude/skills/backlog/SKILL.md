---
name: backlog
description: Cut a PRD or a feature request into epics and stories in feature_list.json through feature.sh add, with Given/When/Then criteria, dependencies, owns and test filters, reviewed for coverage before anything is added. Use when asked to plan a backlog, break a PRD into stories, or add several stories at once.
---

# Cut a backlog

Turn requirements into stories the harness can schedule, run in parallel safely and verify.

## 1. Read
- The PRD in full, or the request. Skip any requirement that waits on an open question, and say which.
- `scripts/agent/feature.sh status` for the existing epics, ids and sprints. New ids continue after the highest one: F05 follows F04.
- `ARCHITECTURE.md`. Every story is one vertical slice through its layers.

## 2. Draft the fragment
**Epics:** one per aggregate or feature folder. Stories of different epics then touch different folders and can run in parallel. Give sprints in dependency order. A new epic needs `id`, `title` and `sprint` (a number, or null to park it).

**Stories:** one session of work each. A story is one use case end to end, not a layer and not a whole feature.

| Field | Write |
|---|---|
| `id` | `F` plus a number. Unique. |
| `name` | Two to four words. It becomes the branch and the session name. |
| `title` | "As a <role>, I want <goal> so that <reason>." |
| `acceptance_criteria` | Given/When/Then lines a test can check at the public boundary. One line for each error the story returns. |
| `prd` | `docs/prd/<feature>.md#FR-<n>`, the requirement the story implements. Optional. |
| `depends_on` | Stories whose code this one needs. Test: could this story's tests pass with only its dependencies merged? If not, a dependency is missing. |
| `owns` | The exact repo-relative files the story creates or changes, including its tests. End a directory with `/` only when no other story touches it. No wildcards. Leave out files in the top-level `shared` list. |
| `test_filter` | Selects only this story's tests. It is passed to `make test-story FILTER=<test_filter>`. |
| `priority`, `estimate`, `area` | P0 on the critical path to P3 parked; XS to XL; one word for the area. |

Example fragment:
```json
{"epics": [{"id": "EPIC-NOTES", "title": "Notes", "sprint": 1, "stories": [
  {"id": "F01", "name": "Create note", "area": "backend", "priority": "P0", "estimate": "S",
   "title": "As a user, I want to create a note so that I can keep it.",
   "acceptance_criteria": [
     "Given a valid body, When I POST /notes, Then it returns 201 with the note.",
     "Given an empty title, When I POST /notes, Then it returns 400."],
   "depends_on": [],
   "owns": ["src/notes/create.ts", "tests/notes/create.test.ts"],
   "test_filter": "notes/create"}]}]}
```

A story that needs a person first, such as a new dependency or a secret, is added like any other and then blocked with `feature.sh block <id> "<what needs approval>"`.

## 3. Review before adding
Give the PRD and the draft fragment to a subagent with a fresh context. Ask it to report, each finding with the requirement or story id:
- Requirements with no story, and stories outside the PRD or listed under Out of scope.
- Criteria that are not Given/When/Then or cannot be checked at the public boundary, and errors in the PRD with no criterion.
- Missing dependencies, by the test above, and dependencies on a later sprint.
- `owns` that misses a file the story must change, or claims a directory another story also writes to.

Apply every finding and ask again, until nothing blocking is left.

## 4. Add
1. Run `scripts/agent/feature.sh add < fragment.json`. It validates the whole fragment and adds nothing on an error; fix the fragment and run it again.
2. Show `scripts/agent/feature.sh waves`. It prints on stderr why each story waits.
3. Add a line to `PROGRESS.md` naming the epics added and the first wave.
4. Commit and open a pull request with the `ship` skill only when the user asks.

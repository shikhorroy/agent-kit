---
name: verify
allowed-tools: Read, Grep, Glob, Bash
description: >-
  Manual only - trigger ONLY when the user invokes it by name (e.g. /sdd:verify); never auto-fire. Read-only review of
  the uncommitted changes of one rule against the spec and the project rules, before the commit.
argument-hint: "[spec file path]"
---

# Verify one rule before the commit

## Overview

The last check before the commit, after `/sdd:tdd` made the rule green and the user ran the full test suite. It finds
what passing tests do not show: spec drift, invented rules, changed tests, weak assertions, broken architecture rules.

**The one principle:** report, never change. You judge by the spec and the project's own rules, not by general best
practice.

**Violating the letter of these steps is violating their spirit.** "In a hurry" or "fix the small things" changes
nothing.

## Showing output

- **Before you check**, say in one line what you review: the rule, and how many files changed.
- **Verdict first.** The first line of the report is the verdict and the issue counts.
- **Number every issue** (`#1`, `#2`), so the user can answer "fix 1 and 3".
- **One issue, one row.** The `Issue` cell names the problem in a few words. Its bullet under the table says what is
  wrong in one or two short sentences, and the user decision.
- **Labels on their own line.** Markdown joins lines that follow each other into one paragraph. Make each labelled line
  a list item, or put a blank line between them.
- **Never a prose summary** in place of the report template.
- **In short** under the verdict: 1 or 2 plain sentences that say what is wrong and what you must decide. The user reads
  every report to keep the knowledge of the change, so it must be easy to read. Readability never removes a fact.
- **Short table cells.** A cell holds a few words. The full issue and its decision go in a bullet under the table, with
  the same number. Long cells break the table in the terminal.

## Steps

1. **Scope.** The uncommitted changes: `git status`, `git diff HEAD`, and the untracked files
   (`git ls-files --others --exclude-standard`). No changes: say so and **stop**. Use git only to read.
2. **Context.** Root `CLAUDE.md` and the `CLAUDE.md` of each changed module, the spec, its rule tagged `[in progress]`,
   the feature's acceptance test file, and the API contract if the project has one.
3. **Check** every item of "Checks" below. Read the code. Never run a test or a build: the user runs them.
4. **Report** with the template. A decision that belongs to the user (the spec says 21, the code says 14) is an issue
   that names both values. Never pick one. Take every `file:line` from `grep -n` or a read of the file, never from a
   diff hunk header.
5. **Stop.** End with "Tell me which issues to fix, by number." Change nothing.

## Checks

| Check                | What to look for                                                                                                                                                   | Usual severity |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|
| Spec coverage        | Every example and counter-example of the `[in progress]` rule has a test method in its nested class, with the same values. Check the whole rule, not only the diff | critical       |
| Spec drift           | The same fact with two values in the spec, `CLAUDE.md`, the API contract, the code or a test                                                                       | critical       |
| Invented rules       | Behaviour in the changed code that no rule or example asks for                                                                                                     | critical       |
| Test integrity       | An existing test with a changed assertion or expected value, a deleted or disabled test, an edited acceptance test                                                 | critical       |
| TDD trace            | A changed production class with logic and no unit test that covers the change                                                                                      | warning        |
| Test quality         | Exact business values, no "not null" where a value is known, names that say one behaviour, no rule numbers                                                         | warning        |
| Architecture         | The project's rules: layers, delegation, dependency direction, no cycles                                                                                           | critical       |
| Naming and placement | Names that match the spec terms, classes in the right package                                                                                                      | info           |
| Implementation       | Dead code, `TODO`, swallowed exceptions, long methods, magic values                                                                                                | warning        |

Raise or lower a severity only with a reason in the issue text.

| Severity | Meaning                                                              |
|----------|----------------------------------------------------------------------|
| critical | breaks the spec, a project rule or test integrity, or hides an error |
| warning  | works now, but costs later                                           |
| info     | a note, no action needed                                             |

| Verdict            | When                        |
|--------------------|-----------------------------|
| Request changes    | at least one critical issue |
| Approve with notes | warnings, no critical issue |
| Approve            | info only, or nothing       |

## Report template

```markdown
**Verdict: Request changes** - 2 critical, 1 warning

**In short:** the loan lasts 14 days, but the spec says 21, so you must choose which one is right. The API also refuses
a blank member, which no rule asks for.

**Scope:** Rule 01, Must lend an available book to a member for 21 days - 4 files changed (2 production, 2 test)

**Issues**

| # | Severity | Where | Issue | Rule broken |
|---|---|---|---|---|
| 1 | critical | `Loan.kt:9` | 14 days, spec says 21 | Spec drift |
| 2 | critical | `LibraryApi.kt:12` | refuses a blank member | Invented rule, Architecture |
| 3 | warning | `BookServiceTest.kt:24` | only `isNotNull()` | Test quality |

- **#1** - The loan lasts 14 days. The spec says 21 (Rule 01). Your decision: change the spec or the code.
- **#2** - `borrow` refuses a blank member with `NO_MEMBER`. No rule asks for it, and the API layer holds logic.
- **#3** - The test asserts only `isNotNull()`, so a wrong due date still passes.

**Spec coverage**

| Spec example | Test | Status |
|---|---|---|
| The one where member `m-1` borrows book `b-42` | `the one where member m-1 borrows book b-42 on 2026-10-01` | covered |
| The one where book `b-99` was never added | none | missing |

**Changes**

- `LoanService` - modified: refuses unknown books
- `BookRepository` - new: the service needs book lookups

**Passed:** naming and placement, dependency direction.

Tell me which issues to fix, by number.
```

- No issues: leave out the `Issues` table and say "No issues found." under the verdict.

## Red flags - stop and go back

| Thought                                                               | Reality                                                         |
|-----------------------------------------------------------------------|-----------------------------------------------------------------|
| "It is a small fix, I will just do it"                                | Report it. Change nothing                                       |
| "The user said to fix the small things"                               | Not in `/sdd:verify`. The user picks the fixes after the report |
| "I will delete this weak test"                                        | Deleting a test is a change. Report it                          |
| "Running the tests is faster than reading"                            | Never run tests or builds. Read the code                        |
| "14 days looks like the newer decision"                               | Name both values. The user decides                              |
| "This old file outside the change looks bad too"                      | Only the changes and the rule in progress                       |
| "This is not best practice"                                           | Judge by the spec and the project rules only                    |
| "The diff has no test for that example, but it was committed earlier" | Spec coverage covers the whole rule                             |

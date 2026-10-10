---
name: regression
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent, AskUserQuestion
description: >-
  Manual only - trigger ONLY when the user invokes it by name (e.g. /sdd:regression); never auto-fire. Whole-branch
  check after every rule is done: nothing of the feature left, no existing feature broken.
argument-hint: "<spec file path> [base branch or commit]"
---

# Regression check for a finished feature

## Overview

The last step of the SDD flow, after every rule is `[done]` and committed. `/sdd:verify` checks one rule's diff. This
skill checks the **whole branch**: the work of all rules together, other tickets merged into the branch, shared code,
config and docs.

**The one principle:** report first, and change nothing before the picker. After the picker, write only the spec changes
the user picked. Never change code, tests or docs: `/sdd:accept` and `/sdd:tdd` do the fixes.

The spec is the only memory between sessions, so each picked fix becomes a `[rework]` tag and a **Rework:** item, by
`${CLAUDE_PLUGIN_ROOT}/example-mapping/spec-format.md`. Read that file at the start.

**Violating the letter of these steps is violating their spirit.** "In a hurry" or "fix the small things" changes
nothing.

## Showing output

The reply renders as Markdown. The picker (`AskUserQuestion`) shows plain text only, so a table or a diff in a question
breaks.

- **Verdict first,** with the item counts. The **Base:** line comes next, also on a reuse run.
- **In short** under the base: 1 or 2 plain sentences that say what is wrong and what you must decide. The user reads
  every report to keep the knowledge of the change. Readability never removes a fact.
- **Number every item** (`#1`, `#2`), so the user can answer "fix 1 and 3".
- **Short table cells.** A cell holds a few words. The full item, its scenario, its flow and its spec text go in a
  bullet under the table, with the same number.
- **Labels on their own line.** Markdown joins lines that follow each other into one paragraph. Make each labelled line
  a list item, or put a blank line between them.
- **Never a prose summary** in place of the report template.
- **No picker without context.** A hook denies the base picker without the **Base:** and recommendation lines, and the
  fixes picker also without the verdict. On a denial, print the context and call the picker again. Never switch to a
  numbered text menu, and never tell the user the hook is wrong.

## Steps

1. **Status check.** Read the spec from disk and run `bash ${CLAUDE_PLUGIN_ROOT}/example-mapping/check-spec.sh <spec>`.
   It must print nothing. A rule that is not `[done]` means the feature is not finished: name it in one line, say
   "Finish it with /sdd:accept first.", and **stop**.
2. **Base branch.** Pick the branch this work is compared with, by reasoning about the repo: where the branch came from,
   and where it will merge. Run `git fetch` first. It is the only git command here that writes, and it writes only
   remote refs.
    - Print the **Base:** line (base, merge-base commit, commit count) and the recommendation line. Ask with the picker,
      `header` "Base": the chosen base "(Recommended)", and "Another branch or commit".
    - Uncommitted changes exist: add a second question to the same call, `header` "Uncommitted": "Leave them out
      (Recommended)" / "Include them".
    - Ask both once per session. A later run reuses both answers. Ask the uncommitted question again only when new
      uncommitted files appear.
3. **Scope.** What this branch adds on top of the base: `git diff <base>...HEAD` and `git log <base>..HEAD`. Group the
   changed files by module.
    - Commits that came in from the base (a sync merge) are not in scope.
    - Merge commits: review only their conflict fixes, with `git show --remerge-diff <merge>` (git 2.36 or newer). With
      an older git, compare the merge with both parents, and say so.
    - Commits of another ticket that is not in the base are in scope: they ship with this PR. Name each ticket.
4. **Review.** Do every check in "Checks". Read the code. Prove each finding with a `file:line` from a read or a
   `grep -n`, never from a diff hunk header.
    - For a large branch, split the checks over parallel read-only reviewers (`Agent`, type `Explore`), one per area.
      Check every serious claim of a reviewer in the code yourself before you report it.
5. **Run the tests that reach the changed code.** Find them with grep: every unit test of each changed module, and every
   integration test that calls a changed method, endpoint, config or shared class.
    - Run them in as few calls as possible. Report the counts, and read `failed` and `skipped` in every result. Never
      call a run green without its counts.
    - A test that cannot run here (no Docker, a service that cannot start) is "not run", never "passed". Give the
      command that prints only the summary, for the user to run.
    - The full suite is the user's or CI's job. Name every test class you did not run, and every check you could not do,
      with the reason.
6. **Report** with the template. Give each item its flow from "Fix flow", and the exact spec text it would add.
7. **Recommend and ask.** End the report with **My recommendation:** which items to fix now, and why, in one sentence.
   Then ask with the picker, `header` "Fixes", question "Which items should I fix?".
    - Options, one short sentence of description each: the items you recommend ("Fix #1 and #3 (Recommended)"), "Fix all
      critical and warning items", "Fix none, I accept the risks". The picker adds "Other" for a custom answer.
    - No critical or warning items: skip the picker. End with "No items to fix." and the verdict.
8. **Write the rework.** The picker answer is the user's OK for the spec text each picked item showed. Ask nothing more.
   Apply each picked item by "Fix flow", run the check script, and print the applied change as one diff, for the record.
   An item the user did not pick changes nothing.
9. **Next, then stop.** End with a **Next:** list in this order:
    - Direct fixes, by item number. This skill does not make them, and they are not in the spec. After it stops, the
      user asks for them in this session, or the next run finds them again.
    - Each `[rework]` rule in spec order: `/sdd:accept <spec> NN`. A rule with a new question gets
      `/sdd:resolve <spec> NN` first.
    - Last: "/sdd:regression again after the fixes. It reuses the confirmed base."

## Checks

### A. Existing behaviour (direct)

For each changed production file:

| Look for                                  | Example                                                                                  |
|-------------------------------------------|------------------------------------------------------------------------------------------|
| Changed public contract                   | endpoint path, request or response fields, status codes, permissions                     |
| Changed method signature or default value | a new parameter, a changed default, a removed overload                                   |
| Changed order of work                     | save before delete, publish before commit, a changed filter of which records are handled |
| New failure paths                         | a forced null unwrap, a new exception, a new required value                              |
| Changed data shape                        | new or changed fields in stored documents or rows, enum values, JSON output              |

### B. Existing behaviour (indirect)

| Look for                  | Example                                                                                                              |
|---------------------------|----------------------------------------------------------------------------------------------------------------------|
| Shared modules            | a change in a library module that other services also load                                                           |
| New components and config | a new injected component that other services also pick up, a property that overrides a default                       |
| Enum and type additions   | an exhaustive switch elsewhere, a client that maps every value, a rollback that cannot read new values               |
| Threads and transactions  | work moved to another thread, a call inside or outside a transaction, a security context read off the request thread |
| Performance and load      | extra queries, lazy loads inside loops, extra log lines per record, a blocking call on a request thread              |
| Outages                   | the behaviour of existing requests when a new dependency (broker, database, service) is down or slow                 |
| Other tickets in scope    | behaviour changed by another ticket's commits (not in the base) that the user may not expect in this PR              |
| Merge conflict fixes      | a hand-solved conflict that drops or changes code from either side                                                   |
| Test fixtures             | a change in a shared test base class or container setup that every integration test uses                             |

Classify each finding of check A and B:

| Class              | Meaning                                                         | Goes to                                       |
|--------------------|-----------------------------------------------------------------|-----------------------------------------------|
| no change          | existing behaviour is the same                                  | nowhere (counts only)                         |
| intended           | a rule or ticket in scope asks for it; name it                  | "Existing behaviour" table                    |
| needs confirmation | intended by a ticket, but the user may not expect it in this PR | "Existing behaviour" and "Needs confirmation" |
| risk               | not asked for; give the scenario                                | an item                                       |

Every finding of check C, D and E is an item. So is a failing test, or a skipped test that should have run.

### C. Feature completeness

| Look for                               | Example                                                                                            |
|----------------------------------------|----------------------------------------------------------------------------------------------------|
| Every rule has its acceptance tests    | one nested class per rule, display name equal to the rule text, one test per example and table row |
| Every rule is built on every code path | every action that should send an event, not only the actions in the examples                       |
| Every table row is built               | every key, label, language and config flag the spec lists                                          |
| Error paths work by design             | a bad input is handled on purpose, not only by timing or luck in the tests                         |
| Spec and code agree                    | the same fact with two values in the spec, the code, a test or a doc                               |

### D. Test integrity

| Look for                  | Example                                                      |
|---------------------------|--------------------------------------------------------------|
| Weakened assertions       | an exact value replaced by `any()`, a check removed          |
| Deleted or disabled tests | a disabled or skipped test, a removed test, a suite left out |
| Edited acceptance tests   | a fixture or display name changed after `/sdd:accept`        |
| Tests that pass by luck   | timing, test order, a shared state between tests             |

### E. Leftovers

| Look for                 | Example                                                                                              |
|--------------------------|------------------------------------------------------------------------------------------------------|
| Unfinished code          | `TODO`, `FIXME`, commented-out code, debug logging                                                   |
| Files that do not belong | untracked files, lock-file changes, temporary files                                                  |
| Docs                     | module docs, design docs or `CLAUDE.md` files that now say something false or miss the new behaviour |
| Project rules            | comment rules, ticket keys in comments, commit message rules                                         |

### Severity and verdict

| Severity | Meaning                                                | Verdict when it is the worst item |
|----------|--------------------------------------------------------|-----------------------------------|
| critical | breaks an existing feature, the spec or test integrity | Not ready                         |
| warning  | works now, but costs later or needs a user decision    | Ready with notes                  |
| info     | a note, no action needed                               | Ready (also with no items)        |

## Fix flow

Decide each item's flow from its scenario. Step 8 writes the spec column for each picked item.

| Scenario                                                  | Flow              | Spec change in step 8                                                                       |
|-----------------------------------------------------------|-------------------|---------------------------------------------------------------------------------------------|
| The spec is silent, or the item needs a business decision | spec change first | a **Questions:** item, the tag `[rework]`, and a Rework item "Answer the question about..." |
| The spec defines the behaviour, but the code misses it    | reopen            | a new **Example:** item, the tag `[rework]`, and a Rework item "New example: ..."           |
| A test is weak, wrong, or passes by luck                  | test fix          | the tag `[rework]`, and a Rework item "Fix test `<name>`: ..."                              |
| Not behaviour: docs, comments, leftovers, project rules   | direct fix        | nothing                                                                                     |

- A case that a test covers only by luck counts as not covered. It gets a new example (reopen), not a test fix.
- When a scenario is unclear, choose the stricter flow: a spec change before a reopen, a reopen before a direct fix.
- Each item belongs to the rule it breaks. Two items on one rule share one tag and one **Rework:** bullet.
- No rule fits, for example a risk from another ticket's code: write nothing in the spec. The item goes in **Next** for
  the user to decide.

## Report template

````markdown
**Verdict: Not ready** - 1 critical, 2 warnings

**Base:** `origin/main` (merge-base `a1b2c3d`, 24 commits in scope, tickets LIB-12 and LIB-15, 1 merge commit with
conflict fixes)

**In short:** no existing endpoint changed. One bad loan stops the reminder job for every member, and a renewal sends no
reminder.

**Existing behaviour**

| Area | Change | Class |
|---|---|---|
| Loans API | extra `dueDate` field | intended |
| Overdue fee | counted from midnight, not from the loan time (LIB-15) | needs confirmation |

**Items**

| # | Severity | Where | Item | Check |
|---|---|---|---|---|
| 1 | critical | `ReminderJob.kt:23` | one bad loan stops the batch | C. error paths |
| 2 | warning | `LoanService.kt:48` | renewal sends no reminder | C. code paths |
| 3 | warning | `docs/loans.md:40` | no `dueDate` field in the doc | E. docs |

- **#1** - A loan with no member makes the job skip the whole batch, so no member gets a reminder. Flow: reopen Rule 04.
  Adds: "The one where a loan with no member sits between two good loans."
- **#2** - The spec does not say whether a renewal sends a reminder. Flow: spec change first, on Rule 06. Adds the
  question: "Must a renewal send a new reminder?"
- **#3** - The loans doc misses the new `dueDate` field. Flow: direct fix.

**Tests run**

- `ReminderJobTest` - 12 run, 0 failed, 0 skipped
- not run: `LoansIT` - needs Docker. Run it with the command from the project's `CLAUDE.md`, filtered to the summary.

**Needs confirmation:** the overdue fee now counts from midnight (LIB-15). Accept it for this PR, or move it out.

**My recommendation:** fix #1 and #3 now - #1 stops every reminder; #2 needs your decision first.
````

Leave out a section with nothing in it. With no items, say "No items found." under the In short line.

## Red flags - stop and go back

| Thought                                                 | Reality                                                             |
|---------------------------------------------------------|---------------------------------------------------------------------|
| "It is a small fix, I will just do it"                  | Report it. Only the spec changes here, and only after the picker    |
| "The user picked #1, I will fix the code now"           | Write the rework into the spec. `/sdd:accept` and `/sdd:tdd` fix it |
| "I will ask again before I write the spec"              | The picker answer is the OK. Write it, then show the diff           |
| "Rule 14 is still `[rework]`, but I can check the rest" | Stop at step 1. The feature is not finished                         |
| "The reviewer said it is a bug"                         | Check the claim in the code yourself first                          |
| "This old file outside the branch looks bad too"        | Only the scope from step 3                                          |

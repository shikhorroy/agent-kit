---
name: accept
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, AskUserQuestion
description: >-
  Manual only - trigger ONLY when the user invokes it by name (e.g. /sdd:accept); never auto-fire. Writes the failing
  acceptance tests for one rule of an Example Mapping spec, after it suggests which rule to take next.
argument-hint: "<spec file path> [rule number, e.g. 03]"
---

# Accept one rule

## Overview

The outer loop of ATDD: one run, one rule of a `/sdd:discover` spec, one failing acceptance test per example. `/sdd:tdd`
then makes the tests green.

**The one principle:** the spec says **what** is tested. You decide only **how**: entry point, ids, dates, field names.
Every scenario and every expected value comes from the spec, word for word. Read
`${CLAUDE_PLUGIN_ROOT}/example-mapping/spec-format.md` at the start. It defines the rule format and the status tags
`[in progress]` and `[done]`, the only memory between sessions.

**Violating the letter of these steps is violating their spirit.** "In a hurry" or "just get it done" changes nothing.

## Showing output

The reply renders as Markdown. The picker (`AskUserQuestion`) shows plain text only, so a table or a diff in a question
breaks.

- **Step line.** Start each step's message with `**Step N/8 - <step name>.** <what I do now or found, one sentence>.`
- **Before every picker**, print the context in the reply: the table, the diff or the proposal. Then one line, for
  example: **My recommendation:** Rule 01 - it builds the whole flow first. Then call the picker.
- **The picker question** is one short sentence: no table, no diff, no line break. Each option description is one short
  sentence. Use `preview` only for code or an ASCII layout that the user compares.
- **A diff** always goes in the reply, in a ` ```diff ` fenced block, so the `+` and `-` lines get color.
- **Labels on their own line.** Markdown joins lines that follow each other into one paragraph. Make each labelled line
  a list item, or put a blank line between them.
- **Never a prose summary** in place of the report template.

## Loop

```
read spec → status check → choose rule → read context → confirm entry point → find spec gaps
    → write tests → run + classify failures → tag [in progress] → report → STOP
```

1. **Status check.** Read the spec from disk and run the check script. If a rule is `[in progress]`, find the nested
   test class whose display name matches the rule text, run it, and check `git status`. If no class matches, say so and
   ask.
    - A spec example of the rule has no test (`/sdd:tdd` added it): write its test (steps 4 to 8), and do not offer
      `[done]` yet.
    - All green and committed: ask "Tag Rule NN as done (Recommended)" / "Not yet". On yes, make the spec change.
    - Else: list the failing tests or uncommitted files, say "Finish Rule NN with /sdd:tdd first.", and **stop**.
2. **Choose the rule.** A rule named in the arguments must pass the "Not ready" list. Else rank the ready rules and show
   the top 3 in a compact table in the reply, one column per criterion, then your recommendation. Ask with the picker,
   the best first with "(Recommended)".
3. **Read the context.** Root `CLAUDE.md`, the `CLAUDE.md` of each module the rule touches, the test rules, the
   feature's acceptance test file if it exists, and the code the rule touches today. Read only.
4. **Confirm the entry point** with the picker before you write.
    - Show the proposal as a table in the reply. Its rows: module, entry point (HTTP endpoint, message queue, scheduled
      job, CLI), test file and class, base class, containers, run command, and what the test cannot reach.
    - Options: your proposal "(Recommended)", one real alternative, and "Split the rule per module side" if the rule
      crosses modules.
    - An entry point below the module's public edge is a unit test. Offer it only as a named option, with the reason.
5. **Find spec gaps before you write.** A gap is a **business** fact the tests need and the spec does not give: a value,
   a format, a name that users or other systems see. A technical detail (a test id, a date, a field name inside the
   test) is yours to choose. List the details you chose in the report. For a gap, ask with the picker:
    - "Update the spec (Recommended)": make the spec change, then go on.
    - "Leave it open": add it to the rule's **Questions:** as a spec change, and **stop**. The rule is not ready.
6. **Write the tests.** One acceptance test file per feature. One nested class per rule. Its display name is the rule
   text only, its class name the rule's meaning (`LendsAvailableBookFor21Days`). Never the rule number: `/sdd:resolve`
   renumbers.
    - One test method per example, counter-example and table row. Use one parameterized test only when every row runs
      the same code with only the values changed.
    - Assert the exact spec values. Never `isNotNull()` where the spec gives a value.
    - Run only this rule's nested class with the project's test command.
7. **Classify each result** by the table below. Then ask to tag the rule `[in progress]` as a spec change. If every test
   passed at once, offer `[done]` instead.
8. **Report, then stop.** Use the template below. End with "Next: /sdd:tdd <first failing test>." If a test was not run,
   end with "Next: run <command> and confirm the red reason, then /sdd:tdd."

## Test results

| Result  | Reason                                                                                | Action                                             |
|---------|---------------------------------------------------------------------------------------|----------------------------------------------------|
| fails   | the behaviour is missing: compile error on a new class, 404, missing row, wrong value | right reason, keep                                 |
| fails   | setup: a container does not start, a bad fixture, a wrong assertion                   | fix the **test**, run again                        |
| passes  | earlier code already does it                                                          | keep it as a regression test, say so in the report |
| not run | the environment cannot run it (no Docker, a service that cannot start here)           | say "not verified", never "fails"                  |

## Choosing a rule

**Not ready.** Never offer a rule when:

- it has a **Questions:** item. Run `/sdd:resolve` first.
- it already has a status tag.
- its test cannot even be set up before another rule is `[done]`. Example: it reads rows that another rule creates.

**Rank the ready rules:**

| Criterion                 | Prefer                                                 | Why                                                |
|---------------------------|--------------------------------------------------------|----------------------------------------------------|
| Whole flow                | the rule goes in at the edge and comes out at the edge | the first rule builds the skeleton                 |
| Few examples              | 1 to 3                                                 | a failure is easy to locate                        |
| Simple logic              | yes / no, no calculation                               | failures are skeleton problems, not logic problems |
| Builds on done rules      | uses the entry point that done rules built             | needs little new code                              |
| Happy path first          | the normal case before the failure and error rules     | the error path needs the flow to exist             |
| Data-driven later         | a table of same-shape rows comes after the skeleton    | a red row has too many possible causes before that |
| Unchanged behaviour later | "old data still reads" rules come after the first rule | they usually pass at once: cheap regression tests  |
| Can run here              | the test runs in this environment                      | a test that cannot run cannot be red               |

## Spec change

Never change the spec without the user's OK. Write the old and new text to two files in the scratchpad, run
`git diff --no-index --no-prefix old.md new.md`, and paste the diff in the reply in a ` ```diff ` block. Drop its
`diff --git` and `index` header lines. Ask "Accept (Recommended)" / "Discard". After each apply, run the check script.
It must print nothing. Fix every hit, then run it again.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/example-mapping/check-spec.sh <spec>
```

## Report template

```markdown
**Rule 01:** Must lend an available book to a member for 21 days - tagged `[in progress]`

**Tests** - `LoansIT` › `LendsAvailableBookFor21Days`

| # | Test | Spec example | Result | Why |
|---|---|---|---|---|
| 1 | `the one where member m-1 borrows book b-42 on 2026-10-01` | Example | red | compile error, no `LibraryApi` |
| 2 | `the one where book b-42 is already lent to member m-2` | Counter-example | not verified | needs MongoDB, no Docker here |

**Details I chose**

- Entry point: `LibraryApi.borrow(memberId, bookId, on)`
- Member `m-1`, book `b-42`, date 2026-10-01

**Files**

- new: `src/test/.../LoansIT.kt`
- changed: `build.gradle.kts` - test dependency only

**Suggested spec examples:** a member borrows the same book again after returning it.

**Next:** /sdd:tdd the one where member m-1 borrows book b-42 on 2026-10-01.
```

- `Result` is one word: `red`, `green` or `not verified`. `Why` is the short reason, for a red the missing behaviour.
- Leave out a section with nothing in it. Keep `Next` the last line.

## Red flags - stop and go back

| Thought                                                  | Reality                                                   |
|----------------------------------------------------------|-----------------------------------------------------------|
| "This extra test guards against a bug"                   | No test beyond the spec. Suggest it as a spec example     |
| "Rules 03 and 04 are one small step"                     | One rule per run. Never start a second rule               |
| "Integration tests are slow here, a unit test is enough" | The entry point is the user's call (step 4)               |
| "I will guess the name and note it"                      | A business fact is a spec gap (step 5). Stop and ask      |
| "A small stub makes it compile"                          | No production code at all. A compile error is a valid red |
| "I need another branch for this"                         | Never change the branch, stash or reset. Read only        |
| "The user is in a hurry, so I pick the rule"             | Show the top 3 and ask                                    |
| "It fails, so it is red"                                 | Check the reason. A setup error is not red                |
| "This test belongs next to the other rule's tests"       | Never touch the nested class of another rule              |

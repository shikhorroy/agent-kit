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
`[in progress]`, `[done]` and `[rework]`, the only memory between sessions.

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
- **The report starts with the In short line**: 1 or 2 plain sentences that say what was written and what it means.
  Example: **In short:** the 2 tests for Rule 05 are written. Both fail because the backend does not know the new event
  types yet, which is the right reason.
    - The user reads every report to keep the knowledge of what was tested and why. So it must be easy to read.
    - Readability never removes a fact. Every fact stays in the report, said once.
- **Short table cells.** A cell holds a few words. A long test name or a long reason goes in a bullet under the table.
  Long cells break the table in the terminal.
- **No picker without context.** Every reply that ends in a picker starts with the Step line and ends with the
  recommendation line. A hook checks this.
    - It holds for every step, also step 1 ("Tag Rule NN as done") and step 7 (the tag).
    - A denied picker means this reply had no context: print it, then call the picker again.
    - Never answer a denial with a numbered text menu, and never tell the user the hook is wrong.
- **File references.** Name the nested class and every changed file as a repo-relative `path:line`, so the user can
  click it. Shorten the middle of a long path with `...`, never the file name.
- **ASCII only** in a rule tree: the words `green`, `RED` and `not verified`, never a check mark, a cross or another
  symbol. A wide symbol leaves ghost text in the terminal when it scrolls.
- **Say a fact once.** A file left out of a commit, or a known old warning, goes in one report only. Never repeat it.

## Loop

```
read spec → status check → choose rule → read context → confirm entry point → find spec gaps
    → write tests → run + classify failures → tag [in progress] → report → STOP
```

1. **Status check.** Read the spec from disk and run the check script. If a rule is `[in progress]`, find the nested
   test class whose display name matches the rule text, run it, and check `git status`. If no class matches, say so and
   ask.
    - A spec example of the rule has no test (`/sdd:tdd` or `/sdd:regression` added it): write its test (steps 4 to
      8), and do not offer `[done]` yet.
    - A **Rework:** item names an acceptance test to fix: fix only that test, as the item says, and run the class. A
      unit test item is for `/sdd:tdd`.
    - Before you offer `[done]`, check each Rework item in the code: the named test is fixed, the new example has its
      test. An item not done yet: name it with the skill that does it, and do not offer `[done]`.
    - All green and committed: ask "Tag Rule NN as done (Recommended)" / "Not yet". On yes, make the spec change. It
      also removes the rule's **Rework:** bullet.
    - All green, but not committed: list the uncommitted files of the rule in a compact table. Ask "Commit Rule NN's
      files now (Recommended)" / "Stop here". On commit: commit only those files, by the project's commit convention,
      never push. Then ask to tag the rule `[done]` as above. Never stop with only "commit, then run me again".
    - A test fails: list the failing tests, say "Finish Rule NN with /sdd:tdd first.", and **stop**.
2. **Choose the rule.** A rule named in the arguments must pass the "Not ready" list. Else rank the ready rules and show
   the top 3 in a compact table in the reply, one column per criterion, then your recommendation. Ask with the picker,
   the best first with "(Recommended)".
    - A ready `[rework]` rule comes before every untagged rule, and needs no picker. Take the first one in spec order,
      or the one named in the arguments. The user already picked it in `/sdd:regression`.
    - Tag it `[in progress]` at once and keep its **Rework:** bullet. Say the change in one line, with no diff and no
      picker. Then go to step 3.
    - For a `[rework]` rule, step 4 reuses the nested class and entry point it has. Steps 5 to 8 cover only the
      examples with no test and the Rework items.
    - Work of the last rule is still uncommitted: add a second question to the same picker call, "Commit the Rule NN
      work first (Recommended)" / "Go on without a commit".
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
   passed at once, offer `[done]` instead, after the Rework check of step 1. A `[rework]` rule is already
   `[in progress]` from step 2, so skip the tag question.
8. **Report, then stop.** Use the template below. End with "Next: /sdd:tdd <first failing test>." If a test was not run,
   end with "Next: run <command> and confirm the red reason, then /sdd:tdd." For a test the user runs:
    - Give a command that prints only the summary and the names of the failing tests, for example
      `npx ng test --include='**/loan.spec.ts' --watch=false 2>&1 | grep -E "FAILED|Executed .* of"`.
    - Say to run the whole test file, not one block of it, and say the counts you expect: "Expect 9 specs, 9 failures."

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
- it has `[in progress]` or `[done]`. A `[rework]` rule is ready.
- its test cannot even be set up before another rule is `[done]`. Example: it reads rows that another rule creates.

No rule is ready: name each open rule and why in one line, for example "Rule 06 has a question: run /sdd:resolve
first.", and **stop**. Every rule is `[done]`: say "Next: /sdd:regression <spec>.", and **stop**.

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

Never change the spec without the user's OK. One exception: step 2 tags a `[rework]` rule `[in progress]` with no
question, because the user already picked it in `/sdd:regression`.

Write the old and new text to two files in the scratchpad, run `git diff --no-index --no-prefix old.md new.md`, and
paste the diff in the reply in a ` ```diff ` block. Drop its `diff --git` and `index` header lines. Ask "Accept
(Recommended)" / "Discard". After each apply, run the check script. It must print nothing. Fix every hit, then run it
again.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/example-mapping/check-spec.sh <spec>
```

## Report template

````markdown
**In short:** the 2 tests for Rule 01 are written. Test 1 fails because there is no lending API yet, which is the right
reason. Test 2 needs MongoDB, so it did not run here.

**Rule 01:** Must lend an available book to a member for 21 days - tagged `[in progress]`

**Tests** - `LoansIT` › `LendsAvailableBookFor21Days` - `src/test/.../loans/LoansIT.kt:42`

| # | Test | Spec | Result |
|---|---|---|---|
| 1 | m-1 borrows b-42 | Example | RED |
| 2 | b-42 already lent | Counter-example | not verified |

- **Test 1** - `the one where member m-1 borrows book b-42 on 2026-10-01`. RED: compile error, no `LibraryApi`.
- **Test 2** - `the one where book b-42 is already lent to member m-2`. Not verified: it needs MongoDB, and Docker does
  not run here.

**Details I chose**

- Entry point: `LibraryApi.borrow(memberId, bookId, on)`. Why: it is the module's public edge, and Rule 02 will use the
  same call.
- Member `m-1`, book `b-42`, date 2026-10-01

**Files**

- new: `src/test/.../loans/LoansIT.kt` - the nested class at line 42
- changed: `build.gradle.kts:31` - test dependency only

**Suggested spec examples:** a member borrows the same book again after returning it.

**Next:** /sdd:tdd the one where member m-1 borrows book b-42 on 2026-10-01.
````

- `Test` in the table is a short name of the example, under 30 characters. The full test name goes in its bullet.
- `Result` is one word or two: `RED`, `green` or `not verified`. The bullet gives the reason: for a RED test the missing
  behaviour, for a green test why it already passes, for a test not run why it could not run.
- Every chosen detail that the user did not pick has a **Why** in its bullet.
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
| "The rule is green, the user can commit and call me"     | Offer the commit in the picker, then tag the rule         |
| "The context is clear, I can just ask"                   | Print the Step line and the context first, then ask       |
| "I will ask before I reopen the `[rework]` rule"         | The user picked it in `/sdd:regression`. Tag it, go on    |
| "The rule is done, the Rework bullet can stay"           | The `[done]` spec change removes the **Rework:** bullet   |

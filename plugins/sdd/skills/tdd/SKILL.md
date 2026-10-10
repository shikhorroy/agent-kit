---
name: tdd
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, AskUserQuestion
description: >-
  Manual only - trigger ONLY when the user invokes it by name (e.g. /sdd:tdd); never auto-fire. Runs TDD cycles against
  one failing acceptance test written by /sdd:accept, one unit test per cycle, until that test is green.
argument-hint: "[spec file path] [acceptance test name]"
---

# TDD against one acceptance test

## Overview

The inner loop of ATDD. The **target** is one failing acceptance test from `/sdd:accept`. Each cycle writes **one** unit
test and the minimum code to pass it. The target turns green by itself once enough pieces exist. The user decides after
every cycle.

**The one principle:** no production code without a unit test you saw fail. The only exception is the compile step.

**Violating the letter of these steps is violating their spirit.** "In a hurry" or "just get it done" changes nothing.

## Showing output

The reply renders as Markdown. The picker (`AskUserQuestion`) shows plain text only, so a table or a diff in a question
breaks.

- **Before work starts**, say in one line what you do next, for example: **Now:** Red for piece 2, `LoanService`.
  A **Now** line names one action. It holds no test status, no finding and no plan: those go in a report.
- **Before every picker**, print the context in the reply: the report, the table or the diff. Then one line, for
  example: **My recommendation:** Proceed with piece 3, `LoansController` - one reason. Then call the picker.
- **The picker question** is one short sentence: no table, no diff, no line break. Each option description is one short
  sentence. Use `preview` only for code or an ASCII layout that the user compares.
- **A design choice** before the picker: a compact table, one row per option, with what it means and its cost.
- **A diff** always goes in the reply, in a ` ```diff ` fenced block, so the `+` and `-` lines get color.
- **Every report starts with the In short line**: 1 or 2 plain sentences that say what works now and what is still
  missing. Example: **In short:** the service can now lend a book. The HTTP endpoint is still missing, so the
  acceptance test fails.
    - Plain words. A class name only when it helps.
    - The user reads every report to keep the knowledge of what was built and why. So it must be easy to read.
    - Readability never removes a fact. Every fact stays in the report, said once.
- **Then the Where line**: the rule, the target's place among the rule's tests, the cycle out of the planned cycles,
  and the state of the acceptance test. For example: **Where:** Rule 07 | test 1 of 3 | cycle 2 of 3 | acceptance test:
  RED. It says `GREEN` once that test passes. The user must never guess which rule or which test a report is about.
    - `cycle N of M`: M is the number of pieces in the plan. When the plan grows, M grows. Cycle 0 is the start report.
    - A target that covers several tests (a parameterized test) gives the real range: `tests 1-8 of 10`.
- **Under the Where line, the Target line** names the acceptance test and its repo-relative `path:line`, for example
  **Target:** `the one where member m-1 borrows book b-42` - `src/test/.../LoanAcceptanceTest.kt:48`.
- **File references.** Each piece in the start plan, every Red and every Green names its file as a repo-relative
  `path:line`, so the user can click it. Shorten the middle of a long path with `...`, never the file name. A piece not
  written yet has its planned file without a line.
- **ASCII only** in the Where line, the progress block and the rule tree. Emoji and symbols such as a check mark, a
  cross, a pointer triangle or an arrow glyph have an unclear width. The terminal then leaves ghost text when it
  scrolls. Use `|` between Where parts, the words `done`, `next` and `to do` for pieces, the words `green`, `RED` and
  `not verified` for tests, and `*` for a note.
- **Each cycle step is its own bullet** with a bold name: **Red**, **Green**, **Refactor**, **Challenge**, **Tests
  run**. Markdown joins lines that follow each other into one paragraph, so never write them as plain lines.
- **Test statuses of the rule always go in the rule tree** (see "Report templates"), never in a sentence such as
  "Tests 1 and 3 are green".
- **Keep the Tests run bullet readable.** One sub-bullet per test run, with the counts. Never a wide table: long cells
  break the table in the terminal. Drop no fact: every run, every skip with its reason, and what was not run and why.
- **Never a prose summary** in place of a template. After an interruption, print the last report again in full.
- **A request for a short status** (for example "say in a few words what you are doing") gets a **Now** line only. It
  never replaces a report, and the next picker still needs its report.
- **Every picker comes right after its report, in the same reply.** The reply starts with the In short line and the
  Where line, and ends with the recommendation line. The first picker of a run, and the picker after a target turns
  green, also need the rule tree. A hook checks this.
    - A denied picker means this reply had no report. Print the full report, then call the picker again.
    - Never answer a denial with a numbered text menu, and never tell the user the hook is wrong.
- **The recommendation is concrete**: the next piece, its file, and the unit test the next Red writes. For example:
  **My recommendation:** Proceed with piece 3, `LoansController` in `src/main/.../LoansController.kt`. The next Red is
  `posts a loan to the service` in `LoansControllerTest.kt`. It is the last missing piece.
- **Say a fact once.** A file left out of a commit, or a known old warning, goes in one report only. Never repeat it.

## Start of a run

1. **Read the context.** Root `CLAUDE.md` and the `CLAUDE.md` of each module you will touch: the architecture rules, the
   test rules and the test commands. Then the spec, the rule tagged `[in progress]`, and its nested acceptance test
   class: the one whose display name matches the rule text.
    - A **Rework:** item of the rule names a unit test to fix (`/sdd:regression` wrote it): fix only that test, as the
      item says, before the first cycle. Run it. It passes: name it in the start report. It fails: that failure is the
      first Red, and the plan starts with the piece that makes it pass.
2. **Find the target.** The test named in the arguments. Else the first failing test of that nested class. No rule is
   `[in progress]`: say "Run /sdd:accept first." and **stop**. Every test of the class passes: go to "Rule finished".
    - **Resume.** Uncommitted changes from an earlier run (`git status`) never mean "continue that cycle". Every run
      starts here, at step 1. Name the changed files in the start report, under **Found from an earlier run**.
3. **Run the nested class once** (see "Target run"), then **print the rule tree at once**, before any other step. Read
   where the target fails.
    - It fails for a setup reason in the acceptance test (a wrong fixture, a wrong mock), not for missing behaviour: see
      "Acceptance test setup error".
4. **Compile step**, only when the target does not compile. Tests in the same source set cannot run either, so this
   comes first.
    - Add only the declarations the target names: types, fields, constructors, function signatures.
    - Every body is the language's "not implemented" (`TODO()`, `throw new UnsupportedOperationException()`). No logic.
    - Run the target. It must compile and fail with "not implemented". Report the step.
5. **Plan the pieces.** List the missing pieces on the path the failure shows, innermost first: domain, then service,
   then adapter, then the entry point. List only what **this** target needs. A piece for a later test waits for that
   test. Even a one-piece plan is a plan.
6. **Print the start report** with the start template (see "Report templates"): the Where line, the target, the rule
   tree, the status and the plan. No picker before this report. Then ask for the first piece with the picker.

## Cycle

```
Red → Green → Refactor → Challenge → Stop (picker) → next cycle
                                       target green → next target, or "Rule finished"
```

1. **Red.** Write **one** unit test for the chosen piece, in the unit test class of the production class it drives.
    - Name it after one behaviour of that class: `opens a loan due 21 days later`. Never a rule number, an example text,
      or the acceptance test's name.
    - Name the architecture rules this piece touches, from `CLAUDE.md`, in one line.
    - Run only this test. Read the message. A missing class or method is a valid red. To reach an assertion red, a new
      body may return an empty or wrong value.
    - Fails for another reason (a typo, a bad setup): fix the **test**, run again.
    - Passes at once: this is not a cycle. Write no code. Report it, and ask "Delete it (Recommended)" / "Keep it as a
      regression test".
2. **Green.** Write the minimum code to pass **this** unit test.
    - Minimum: no extra method, parameter, field, class or interface. A hard-coded value is fine if it passes.
    - A design choice the test does not force (a type, a package, a new interface, a name others will use): ask with the
      picker before you write it.
    - Run this test, then all unit tests. A red elsewhere: fix the production code. Never change what an existing test
      asserts, except a test that a **Rework:** item names. A setup line that a new signature breaks (a constructor
      call) may change.
3. **Refactor.** Every cycle. Check production and test code for duplication, unclear names, long methods, nested
   conditionals, magic values and code in the wrong layer. Change only what you find. Run all unit tests and the target.
   Report what changed, or "none" with the reason for each check.
4. **Challenge.** Propose at least one edge case for the class this cycle tested: empty or zero, not found, boundary,
   duplicate, null, negative, invalid state, rounding. Classify each by "Edge cases" below. Write no test for it.
5. **Stop.** Run the target. Report with the cycle template, then your recommendation line. Then ask with the picker,
   with the options in "Stop options". The picker adds "Other" by itself, for the user's own answer.
    - The picker question names the rule and the test number, for example "Start test 2 of 3 in Rule 07 as the new
      target?". Never a vague question such as "How do you want to handle the overdue test?".
    - Target green: say it plainly. The cycle is done, the target is done, and the next failing test of the same rule
      becomes the new target. The rule stays `[in progress]` until every test of it passes.
    - Offer "Harden" only for an edge case marked "Harden now" or "Ask the user" in "Edge cases". Else leave it out.
    - Put "Harden" first, with "(Recommended)", when the spec or a real business risk needs that edge case now.
    - "Proceed": the next Red drives the next piece. This is a progress cycle.
    - "Harden": the next Red is that edge case, in the **same** test class. This is a hardening cycle.
    - A business decision in "Other" (for example "a duplicate gives an error"): it becomes the next Red, and a spec
      change. Show the diff and apply it only on "Accept", as `/sdd:accept` does.
    - A different piece in "Other": follow it.

## Stop options

| Target                       | Options                                                                                                           |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|
| still red                    | "Proceed: piece `<n>`, `<Class>` (Recommended)", "Harden: `<edge case>`", "Stop here"                             |
| green                        | "Next target: test `<n>` of `<total>`, `<next failing test>` (Recommended)", "Harden: `<edge case>`", "Stop here" |
| green, last test of the rule | "Finish the rule (Recommended)", "Harden: `<edge case>`", "Stop here"                                             |

## Target run

Run only the target, with the project's command. At the start of a run, and when a target turns green, run the whole
nested class instead, to fill the rule tree. When it cannot run here (no Docker, a browser test runner that cannot
start):

- Ask with the picker: "Run `<command>` and paste the result in Other." Options: "Skip the target check this cycle",
  "Stop here".
- Give a command that prints only the summary and the names of the failing tests, so the user pastes a few lines. For
  example `npx ng test --include='**/loan.spec.ts' --watch=false 2>&1 | grep -E "FAILED|Executed .* of"`.
- Say what to run: the whole test file, not one block of it, so the new unit tests and the target both run.
- Say the result you expect, as counts: "Expect 24 specs, 17 failures: 8 new unit tests and 9 acceptance tests."
- Never guess the target status. Without a run, report it as "not verified".
- Still print the rule tree. Each test that did not run shows `not verified` in place of its status.

## Acceptance test setup error

`/sdd:tdd` never edits an acceptance test on its own. When the target fails for a setup reason:

1. Find the cause in the code, not by guessing.
2. Check the fix first: copy the test file to a temporary file next to it, apply the fix there, run it, and delete the
   copy.
3. Show the fix as a diff, with the result of that run: "Checked in a temporary copy: 2/2 green, skipped=0."
4. Ask "Accept the fix (Recommended)" / "Stop here". Apply it only on "Accept".

Never propose a fix that you have not run.

## Edge cases

| Situation                                          | Recommend                                             |
|----------------------------------------------------|-------------------------------------------------------|
| The spec defines it                                | Harden now                                            |
| The spec is silent, but it is a real business risk | Ask the user: decide, add it to the spec, then harden |
| It belongs to another rule                         | Defer to that rule. Name the rule text                |
| The test would pass at once                        | Skip: it drives no code                               |
| Unlikely, or not needed now                        | Proceed                                               |

## Rule finished

When every test of the nested class passes, run all tests of the module. Print the cycle report with the rule tree.
The Tests run bullet says "not run: the full suite - your run". List the uncommitted files of this rule in a compact
table. Then one recommendation line, and the picker "Rule NN is green. What next?":

- "Commit the rule's files (Recommended)": commit only the files of this rule, by the project's commit convention. Never
  push. Then say "Next: /sdd:accept tags Rule NN `[done]`." and **stop**.
- "Run /sdd:verify first": **stop**, and say "Run /sdd:verify, then commit."
- "Stop here": **stop**. Commit nothing.

Never write the next steps as a numbered list in place of the picker, and never repeat the report as a summary.

If this run added an example to the spec, it has no acceptance test yet. Name it, and say "`/sdd:accept` adds its test
first."

## Report templates

**Start of a run** - step 6:

````markdown
**In short:** nothing lends a book yet, so `POST /loans` gives 404. The plan builds 3 pieces, from the loan itself up to
the endpoint.

**Where:** Rule 03 | test 1 of 2 | cycle 0 of 3 | acceptance test: RED

**Target:** `the one where member m-1 borrows book b-42 on 2026-10-01` - `src/test/.../loans/LoanAcceptanceTest.kt:48`

```text
Rule 03 src/test/kotlin/com/example/loans/LoanAcceptanceTest.kt:42 (in progress)
 |- test 1  member m-1 borrows book b-42      RED    * target
 `- test 2  member m-1 borrows a second book  RED
```

**Status:** RED - `404 on POST /loans` (run just now). Compile step: not needed.

**Found from an earlier run:** none. Else the changed files, one per line, such as `LoanService.kt` (uncommitted).

**Plan** - missing pieces, innermost first

| # | Piece | File | What it does |
|---|---|---|---|
| 1 | `Loan` | `src/main/.../loans/Loan.kt` (new) | opens a loan with a due date |
| 2 | `LoanService` | `src/main/.../loans/LoanService.kt` (new) | lends a book that is free |
| 3 | `LoansController` | `src/main/.../loans/LoansController.kt:12` | `POST /loans` calls the service |

Left for later rules: refusing a book that is already lent.

**My recommendation:** Start with piece 1, `Loan` in `src/main/.../loans/Loan.kt` - it has no dependencies. The first
Red is `opens a loan due 21 days later` in `LoanTest.kt`.
````

**Each cycle** - at the Stop step:

````markdown
**In short:** the service can now lend a book that is free. The HTTP endpoint is still missing, so the acceptance test
still fails.

**Where:** Rule 03 | test 1 of 2 | cycle 2 of 3 | acceptance test: RED

**Target:** `the one where member m-1 borrows book b-42 on 2026-10-01` - `src/test/.../loans/LoanAcceptanceTest.kt:48`

```text
piece 1  Loan              done   cycle 1
piece 2  LoanService       done   cycle 2  * this report
piece 3  LoansController   next   cycle 3
```

### Cycle 2 - piece 2 `LoanService` - done

**Built:** `LoanService` lends a book that is free.

**Why:** the controller needs a service to call before it can answer `POST /loans`, and the lending rule belongs in the
service layer.

| Step | State | Result |
|---|---|---|
| Red | done | failed as expected |
| Green | done | test passes |
| Refactor | done | 1 constant named |
| Challenge | done | 1 edge case, ask you |
| Acceptance test | ran | still RED |

- **Red** - wrote `lends a book that is free` in `src/test/.../loans/LoanServiceTest.kt:22`. Failed as expected:
  `Unresolved reference 'borrow'`. Rules touched: logic lives in services, constructor injection.
- **Green** - added `borrow` in `src/main/.../loans/LoanService.kt:14`, which returns `Loan.open(...)`. 1 file changed.
- **Refactor** - named the 21 days `LOAN_PERIOD` in `Loan.kt:5`. Checked: duplication, names, method length, layers -
  none found.
- **Challenge** - a book that does not exist: the spec is silent, real risk. Ask the user.
- **Tests run**
  - unit tests: 7 run, 0 failed
  - acceptance test: RED, `404 on POST /loans`

**My recommendation:** Proceed with piece 3, `LoansController` in `src/main/.../loans/LoansController.kt`. The next Red
is `posts a loan to the service` in `LoansControllerTest.kt`. It is the last missing piece.
````

**Each cycle, acceptance test green** - the cycle that turns the acceptance test green:

````markdown
**In short:** a member can now borrow a free book through `POST /loans`, so the acceptance test passes. Test 2, a
second book, is next.

**Where:** Rule 03 | test 1 of 2 | cycle 3 of 3 | acceptance test: GREEN

**Target:** `the one where member m-1 borrows book b-42 on 2026-10-01` - `src/test/.../loans/LoanAcceptanceTest.kt:48`

```text
piece 1  Loan              done   cycle 1
piece 2  LoanService       done   cycle 2
piece 3  LoansController   done   cycle 3  * this report
```

### Cycle 3 - piece 3 `LoansController` - done

**Built:** `LoansController` sends `POST /loans` to the service.

**Why:** this is the entry point the acceptance test calls. It was the last missing piece on the path.

| Step | State | Result |
|---|---|---|
| Red | done | failed as expected |
| Green | done | test passes |
| Refactor | done | no change |
| Challenge | done | 1 edge case, deferred |
| Acceptance test | ran | GREEN |

- **Red** - wrote `posts a loan to the service` in `src/test/.../loans/LoansControllerTest.kt:30`. Failed as expected:
  `404 on POST /loans`.
- **Green** - added `borrow` in `src/main/.../loans/LoansController.kt:12`, which calls `LoanService.borrow`. 1 file
  changed.
- **Refactor** - none. Checked: duplication, names, method length, layers - none found.
- **Challenge** - a missing member id: belongs to Rule 05. Defer.
- **Tests run**
  - unit tests: 9 run, 0 failed
  - acceptance test: GREEN
  - not run: the full suite - your run

<the rule tree, as shown below>

**Next:** test 2 becomes the new target. Rule 03 stays `[in progress]`.

**My recommendation:** Next target: test 2, `the one where member m-1 borrows a second book` - it is the only red test
left in Rule 03.
````

The rule tree in that report, in its own ` ```text ` block:

```text
Rule 03 src/test/kotlin/com/example/loans/LoanAcceptanceTest.kt:42 (in progress)
 |- test 1  member m-1 borrows book b-42      green  * target, done
 `- test 2  member m-1 borrows a second book  RED    * next target: 409 on POST /loans
```

**Layout rules for every report:**

| Rule                                                                                                            | Why                                                            |
|-----------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| One blank line between every block: Where, Target, progress block, heading, Built, table, steps, recommendation | Markdown joins lines that follow each other into one paragraph |
| Never two lists in a row. A heading, a paragraph, a table or a code block goes between them                     | two lists merge into one                                       |
| A blank line before and after every table and every code block                                                  | else the table shows as raw text                               |
| No blank line inside the step bullets. Sub-bullets are indented by 2 spaces                                     | else the list gets big gaps, or a sub-bullet loses its place   |

- **Progress block:** one line per planned piece, in a ` ```text ` block: `piece <n>`, the name, the state, the cycle.
  The states are `done`, `next` and `to do`. `* this report` marks the piece of this cycle. No file paths: the block
  must never wrap. A piece added during the run goes in at its place.
- **Cycle heading:** `### Cycle <n> - piece <n> <name> - done`. The Where line already says when the acceptance test
  turned green. A hardening cycle says `- hardening: <edge case>` in place of the piece.
- **Built:** one plain sentence about the behaviour this cycle added. **Why:** in its own paragraph, why this piece was
  needed at this point: what depends on it, or which rule of `CLAUDE.md` puts it here.
- **Step table:** one row per step with a short state (`done`, `ran`, `skipped`) and a result of 2 to 4 words. It only
  shows that each step ran. Each fact is said once, in the bullets under it: the test name, the file, the message and
  the counts.
- **Red:** the test name, its file as `path:line`, and the exact failure message. **Green:** the code change, its file
  as `path:line`, and the file count. **Refactor:** what changed, or each check with "none". **Challenge:** each edge
  case with its "Edge cases" label. **Tests run:** one sub-bullet per run with the counts, the acceptance test with its
  message, and what was not run and why.
- Add a bullet only when it happens: **Compile step**, **Red elsewhere** (which tests broke, and the fix), **Untested
  code** (a branch that no test drives, and why it exists).
- More than one edge case: put them as sub-bullets under **Challenge**.
- The **rule tree** lists every test of the nested class, in file order, in a ` ```text ` block. Show it at the start of
  a run and when a target turns green. In other cycles the Where line is enough.
    - First line: the rule, then the nested class as a repo-relative `path:line` of its declaration, then the rule tag.
      A full path lets the user click it in the terminal. A package path alone does not open.
    - One line per test: `|-`, or `` `- `` for the last one, `test <n>`, a short name of the example, then `green`,
      `RED` or `not verified`. Drop "the one where" and keep the name under 45 characters.
    - ASCII only, see "Showing output". Pad the name and the status to one width, so every status and every `*` note
      sits in one column.
    - A `*` note marks only the target and the next target. A red next target ends with its failure message.

## Red flags - stop and go back

| Thought                                               | Reality                                                            |
|-------------------------------------------------------|--------------------------------------------------------------------|
| "The target needs this, I will just write it"         | Unit test first. The target is never the test you code against     |
| "It only delegates, it needs no unit test"            | It is a piece. Test it with a mocked collaborator                  |
| "I am in a hurry, I will do the next cycle too"       | Stop after every cycle and ask                                     |
| "Two tests at once are faster"                        | One unit test per cycle                                            |
| "Refactor: nothing to do"                             | Run the checklist. Give the reason for each "none"                 |
| "This old test is wrong, I will adjust it"            | Only a test that a Rework item names. Else stop and ask            |
| "The acceptance test is awkward"                      | Never edit it here. Say why, and ask                               |
| "This setup fix for the acceptance test is obvious"   | Run it in a temporary copy first. Show the result with the diff    |
| "String or enum, I will just pick one"                | A design choice. Ask with the picker                               |
| "The next test will need this method anyway"          | No code for a future test                                          |
| "All tests pass"                                      | Run them. Show the counts                                          |
| "This edge case is for another rule, but it is quick" | Defer it to that rule                                              |
| "Green, so I will commit"                             | Commit only when the user picks it in "Rule finished"              |
| "A previous run did this, I will continue"            | Every run starts at step 1 and prints the start report             |
| "I will just say which tests pass"                    | Print the rule tree. Never a sentence                              |
| "I told the user my plan in one line, so I can ask"   | Print the full report first. Then call the picker                  |
| "The hook denied a report that is there"              | It reads only this reply. Print the report in this reply, then ask |
| "A check mark looks nicer than the word green"        | ASCII only. A wide symbol breaks the terminal when it scrolls      |

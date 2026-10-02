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
- **Before every picker**, print the context in the reply: the report, the table or the diff. Then one line, for
  example: **My recommendation:** Proceed with `LoansController` - one reason. Then call the picker.
- **The picker question** is one short sentence: no table, no diff, no line break. Each option description is one short
  sentence. Use `preview` only for code or an ASCII layout that the user compares.
- **A design choice** before the picker: a compact table, one row per option, with what it means and its cost.
- **A diff** always goes in the reply, in a ` ```diff ` fenced block, so the `+` and `-` lines get color.
- **Each cycle step is its own bullet** with a bold name: **Red**, **Green**, **Refactor**, **Challenge**, **Stop**.
  Markdown joins lines that follow each other into one paragraph, so never write them as plain lines.
- **Never a prose summary** in place of a template. After an interruption, print the last report again in full.

## Start of a run

1. **Read the context.** Root `CLAUDE.md` and the `CLAUDE.md` of each module you will touch: the architecture rules, the
   test rules and the test commands. Then the spec, the rule tagged `[in progress]`, and its nested acceptance test
   class: the one whose display name matches the rule text.
2. **Find the target.** The test named in the arguments. Else the first failing test of that nested class. No rule is
   `[in progress]`: say "Run /sdd:accept first." and **stop**. Every test of the class passes: go to "Rule finished".
3. **Run the target** (see "Target run") and read where it fails.
4. **Compile step**, only when the target does not compile. Tests in the same source set cannot run either, so this
   comes first.
    - Add only the declarations the target names: types, fields, constructors, function signatures.
    - Every body is the language's "not implemented" (`TODO()`, `throw new UnsupportedOperationException()`). No logic.
    - Run the target. It must compile and fail with "not implemented". Report the step.
5. **Plan the pieces.** List the missing pieces on the path the failure shows, innermost first: domain, then service,
   then adapter, then the entry point. List only what **this** target needs. A piece for a later test waits for that
   test. Show the plan with the start template (see "Report templates"). Ask for the first piece with the picker.

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
      asserts. A setup line that a new signature breaks (a constructor call) may change.
3. **Refactor.** Every cycle. Check production and test code for duplication, unclear names, long methods, nested
   conditionals, magic values and code in the wrong layer. Change only what you find. Run all unit tests and the target.
   Report what changed, or "none" with the reason for each check.
4. **Challenge.** Propose at least one edge case for the class this cycle tested: empty or zero, not found, boundary,
   duplicate, null, negative, invalid state, rounding. Classify each by "Edge cases" below. Write no test for it.
5. **Stop.** Run the target. Report with the cycle template, then your recommendation line. Then ask with the picker,
   with the options in "Stop options". The picker adds "Other" by itself, for the user's own answer.
    - Offer "Harden" only for an edge case marked "Harden now" or "Ask the user" in "Edge cases". Else leave it out.
    - Put "Harden" first, with "(Recommended)", when the spec or a real business risk needs that edge case now.
    - "Proceed": the next Red drives the next piece. This is a progress cycle.
    - "Harden": the next Red is that edge case, in the **same** test class. This is a hardening cycle.
    - A business decision in "Other" (for example "a duplicate gives an error"): it becomes the next Red, and a spec
      change. Show the diff and apply it only on "Accept", as `/sdd:accept` does.
    - A different piece in "Other": follow it.

## Stop options

| Target    | Options                                                                                  |
|-----------|------------------------------------------------------------------------------------------|
| still red | "Proceed: next piece = `<Class>` (Recommended)", "Harden: `<edge case>`", "Stop here"    |
| green     | "Next target: `<next failing test>` (Recommended)", "Harden: `<edge case>`", "Stop here" |

## Target run

Run only the target, with the project's command. When it cannot run here (no Docker, a service that cannot start):

- Ask with the picker: "Run `<command>` and paste the result in Other." Options: "Skip the target check this cycle",
  "Stop here".
- Never guess the target status. Without a run, report it as "not verified".

## Edge cases

| Situation                                          | Recommend                                             |
|----------------------------------------------------|-------------------------------------------------------|
| The spec defines it                                | Harden now                                            |
| The spec is silent, but it is a real business risk | Ask the user: decide, add it to the spec, then harden |
| It belongs to another rule                         | Defer to that rule. Name the rule text                |
| The test would pass at once                        | Skip: it drives no code                               |
| Unlikely, or not needed now                        | Proceed                                               |

## Rule finished

When every test of the nested class passes, run all tests of the module. Then say: "Rule done. Next: run the full test
suite yourself, then `/sdd:verify`, then commit. Then `/sdd:accept` tags the rule `[done]`." Never commit. **Stop.**

If this run added an example to the spec, it has no acceptance test yet. Name it, and say "`/sdd:accept` adds its test
first."

## Report templates

**Start of a run** - after steps 1 to 5:

```markdown
**Target:** `the one where member m-1 borrows book b-42 on 2026-10-01`

**Status:** red - `404 on POST /loans` (run just now). Compile step: not needed.

**Plan** - missing pieces, innermost first

| # | Piece | What it does |
|---|---|---|
| 1 | `Loan` | opens a loan with a due date |
| 2 | `LoanService` | lends a book that is free |
| 3 | `LoansController` | `POST /loans` calls the service |

Left for later rules: refusing a book that is already lent.

**My recommendation:** start with piece 1, `Loan` - it has no dependencies.
```

**Each cycle** - at the Stop step:

```markdown
**Cycle 2 (progress)** - piece `LoanService`

**Target:** `the one where member m-1 borrows book b-42 on 2026-10-01`

**Pieces:** ✅ `Loan` 🠆 ✅ `LoanService` 🠆 ⬜ `LoansController`

- **Red** - wrote `LoanServiceTest`: `lends a book that is free`. Failed as expected: `Unresolved reference 'borrow'`.
  Rules touched: logic lives in services, constructor injection.
- **Green** - added `LoanService.borrow`, which returns `Loan.open(...)`. 1 file changed.
- **Refactor** - named the 21 days `LOAN_PERIOD`. Checked: duplication, names, method length, layers - none found.
- **Challenge** - a book that does not exist: the spec is silent, real risk. Ask the user.
- **Stop** - unit tests 7/7 green. Target still red: `404 on POST /loans`.

**My recommendation:** Proceed with `LoansController` - it is the last missing piece.
```

- Each bullet says what you did and the result. One or two short sentences.
- **Red:** the test name and the exact failure message. **Green:** the code change and the file count. **Refactor:**
  what changed, or each check with "none". **Challenge:** each edge case with its "Edge cases" label. **Stop:** the unit
  test counts and the target status with its message, or "not verified".
- Add a bullet only when it happens: **Compile step**, **Red elsewhere** (which tests broke, and the fix), **Untested
  code** (a branch that no test drives, and why it exists).
- More than one edge case: put them as sub-bullets under **Challenge**.
- The progress line uses ✅ done and ⬜ to do. A piece added during the run goes in at its place.

## Red flags - stop and go back

| Thought                                               | Reality                                                        |
|-------------------------------------------------------|----------------------------------------------------------------|
| "The target needs this, I will just write it"         | Unit test first. The target is never the test you code against |
| "It only delegates, it needs no unit test"            | It is a piece. Test it with a mocked collaborator              |
| "I am in a hurry, I will do the next cycle too"       | Stop after every cycle and ask                                 |
| "Two tests at once are faster"                        | One unit test per cycle                                        |
| "Refactor: nothing to do"                             | Run the checklist. Give the reason for each "none"             |
| "This old test is wrong, I will adjust it"            | Never change an existing test to pass. Stop and ask            |
| "The acceptance test is awkward"                      | Never edit it here. Say why, and ask                           |
| "String or enum, I will just pick one"                | A design choice. Ask with the picker                           |
| "The next test will need this method anyway"          | No code for a future test                                      |
| "All tests pass"                                      | Run them. Show the counts                                      |
| "This edge case is for another rule, but it is quick" | Defer it to that rule                                          |
| "Green, so I will commit"                             | Never commit. The user commits                                 |

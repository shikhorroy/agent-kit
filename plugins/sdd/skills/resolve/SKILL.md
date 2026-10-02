---
name: resolve
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, AskUserQuestion
description: >-
  Manual only - trigger ONLY when the user invokes it by name (e.g. /sdd:resolve); never auto-fire. Walks
  through the open questions of an Example Mapping spec, one rule at a time, then rewrites the whole spec.
argument-hint: "<spec file path> [start rule, e.g. 04]"
---

# Resolve open questions

## Overview

An Example Mapping spec (made by `/sdd:discover`) has red cards: open questions under each rule. This skill takes them
one rule at a time. The user answers, and each answer becomes part of the rule. When no rule has open questions left, a
final pass rewrites the whole spec, so the answers also reach the Story, Terms, "How it works today" and other rules.

**The one principle:** the rewritten rule must be what `/sdd:discover` would have written if it had known the answer.
Both skills follow one file for content and format: `${CLAUDE_PLUGIN_ROOT}/example-mapping/spec-format.md`. Read it in
full at the start of the session. This skill adds the loop, the diff and the checks, and no content or format rules of
its own. If this file and `spec-format.md` ever disagree, `spec-format.md` wins.

## Loop

```
read spec → next rule with questions → ask → rewrite rule → diff → accept → apply + check
    the rule still has a question: ask again (step 7)
    no question left: next rule (step 2)
no rule left → final pass on the whole spec → diff → accept → apply + check
```

1. **Read the spec from disk at the start of every round.** An IDE formatter often changes it between turns. Never edit
   from memory.
2. **Find the next rule.** Start at Rule 01, or at the start rule from the arguments.
    - A rule with no open questions: say so in one line. Put several in a row in one line: "Rules 03, 05 and 06 have no
      open questions."
    - Check such a rule against `spec-format.md` anyway, for example with the counter-example test. If it breaks a rule
      there, name the flaw in one line as an offer. Do not fix it unless the user picks that rule.
    - If an earlier answer affects such a rule (step 6), say how in one line: "Rule 07 is affected by the Rule 04
      answer: the row for a cancelled order is now wrong."
    - Then ask "Discuss any rule, or continue to Rule NN?" with the AskUserQuestion picker. Options: "Continue to Rule
      NN (Recommended)", one "Discuss Rule XX" per flawed or affected rule you named, and "Stop here". The picker takes
      at most 4 options, so keep the most important ones. The final pass still fixes the rest.
    - "Discuss Rule XX" on a rule with no questions: rewrite it with all answers so far (step 4), then steps 5 and 6.
    - On "Stop here", ask with the picker: "Run the final pass now (Recommended)" or "Stop without it".
3. **Ask with the AskUserQuestion picker**, never in a chat text table. Put all questions of the rule in one call, one
   picker question each. The picker takes at most 4 questions per call. With more, make a second call after the first is
   answered. For each question:
    - `question`: the spec question in short, plus the code facts that bear on it, with `file:line`. Read the code
      first. Base each recommendation on how the system works today.
    - Lay out `question` with real newline characters (`\n`), never as one line. Line 1 is `Rule NN: <question>?`. Line
      2 is `Code facts:`. Then one fact per line, numbered `(1)`, `(2)`... Example:

      ```
      Rule 05: which time zone does the confirmation email show?
      Code facts:
      (1) `Order.placedAt` is stored in UTC (order.ts:22).
      (2) The email template formats dates in the server's time zone (confirmation-email.ts:41).
      (3) `Customer` has no time zone field (customer.ts:10).
      ```
    - `header`: a short tag of at most 12 characters, for example `Rule 04 user`.
    - `options`: 2 to 4. The recommended option comes first, with "(Recommended)" at the end of its label. Each
      `description` says what the option means and why. Never add an "Other" option: the picker adds it itself.
    - If the code shows the question rests on a false premise (for example a job that does not exist), say so in the
      facts, and add an option to drop or narrow the question.
4. **Rewrite the rule** once every question has an answer. Treat each answer, and each answer from earlier rounds, as a
   fact `discover` knew from the start. Write the rule as `discover` would have written it then, by every rule in
   `spec-format.md`: a split, a Terms row, a "How it works today" line, a new real question. Do not only delete the
   question.
5. **Show the change as a unified diff.** Write the current rule and the proposed rule to two files in the session
   scratchpad directory (else `/tmp`). Keep the file's current style (table padding, sub-bullet indent). Run
   `git diff --no-index --no-prefix old.md new.md` and paste the output in a `diff` block.
    - Show only the changed rule. For a split, do not show the new rules. Say "N new rules will be added, as Rule NN to
      MM. Later rules move down by N." With no split, say "No new rules."
    - Print the diff in the chat first. Then ask with the picker: "Accept (Recommended)", "Change something", "Discard".
      On "Change something", or text in "Other", revise and show a new diff.
6. **Apply only after the user accepts.** Then:
    - Renumber later rule headings and every `(Rule NN)` cross-reference. Change them from the highest number down.
    - Keep the file's current style. Do not touch other rules.
    - Run the check script below, then give a one-line summary.
    - Name the other parts of the spec this answer affects: a rule with the same term, input or outcome, a Terms row, a
      "How it works today" line, or the Story. Say it in one line: "This answer also affects Rules 07 and 09, and the
      Terms row for Confirmation email." Do not edit them now. Keep the list: step 2 offers them, and step 8 fixes the
      rest.
    - If the user says "revert", restore the exact text from before the last apply. Change nothing else.
7. **Stay on the rule while it still has questions.** Read the applied rule back from disk. A rewrite often adds a new
   question. If the rule still has a **Questions:** item, say "Rule NN has a new open question." in one line and go back
   to step 3 for the same rule. Never skip a question the user has not seen yet.
    - Add one option to each question: "Leave it open", with the description "Keep the question in the spec and move
      on." Do not ask again about a question the user left open in this session.
    - When the rule has no open questions, or all are left open, go back to step 2. New rules from a split come next.
8. **Final pass** when no rule is left. Read the spec from disk. Rewrite the whole spec as in step 4, with every answer
   of the session. Fix each affected part from step 6. Never end the session after the last rule without this pass.
    - Keep each question the user left open, word for word. Do not add new questions. If `discover` would still ask one,
      name it in one line as an offer.
    - Show one diff of the whole spec and apply as in steps 5 and 6. With no change, say "Final pass: no changes."

## Check after each apply

The script must print nothing. Fix every hit, then run it again.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/example-mapping/check-spec.sh <spec>
```

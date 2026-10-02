---
name: discover
allowed-tools: Read, Grep, Glob, Write, Bash, AskUserQuestion
description: >-
  Use when the rules of a feature must be worked out before it is built. Input: a ticket URL, a ticket key or a user
  story. Writes an Example Mapping spec with rules, examples, counter-examples and open questions.
argument-hint: "<ticket URL, ticket key, or user story>"
---

You are a domain expert in the area of the story below. Propose rules, examples, counter-examples and questions using
the **Example Mapping** approach.

###

$ARGUMENTS

###

**TASK:**

Read `${CLAUDE_PLUGIN_ROOT}/example-mapping/spec-format.md` first. It holds every content and format rule for the spec:
the steps (story, rules, examples, counter-examples, questions), the counter-example test, and the skeleton. Follow it
exactly. Do not add rules of your own. `/sdd:resolve` follows the same file, so the two skills always agree.

Write only questions that the code, the ticket or the docs cannot answer. `/sdd:resolve` answers them later.

**SAVE:**

Save the result to `<repo docs folder>/specs/<ticket-key-or-feature-slug>.md` (use `docs/` if the repo has it, else
`doc/`). Do not overwrite an existing file without asking. Ask with the AskUserQuestion picker.

**VERIFY:**

Run the shared check script on the saved spec. It must print nothing. Fix every hit, then run it again.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/example-mapping/check-spec.sh <spec>
```

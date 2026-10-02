# Example Mapping spec format

The single source for what a spec says and how it looks. `/sdd:discover` writes a spec by these rules. `/sdd:resolve`
rewrites a rule by the same rules, as if the answer had been known from the start. Neither skill adds rules of its own.
Change them only here.

## Content (your judgement)

Base every rule on how the system works today: read the ticket, the code the story touches, and any glossary first.
Treat the story and its draft rules as a starting point to refine, split, or challenge. Never write Gherkin or
Given/When/Then.

0. **Story.** Write "As a <role>, I want <capability>, so that <benefit>." Use a business role, not a module or a
   developer. Do not copy the ticket title. If the ticket has no story, derive it from the ticket's goal.
1. **Rules.** Start the rule text with "Must..." or "Should...". One rule holds one constraint, so split a rule that
   holds two. The title must agree with its table and examples: a title that says "unchanged" while a row says
   "lowercase" is a conflict.
2. **Examples.** Use "The one where..." by default. When a rule's inputs vary independently, use a table instead, with
   one column per input and one per output.
3. **Counter-examples.** A valid case close to the rule where the rule's outcome does NOT happen. Most rules have none,
   and there is no quota. Write one only when it passes the test below. A table row with a different outcome already
   counts.
4. **Questions.** Only ones the code, ticket, or docs cannot answer. `/sdd:resolve` builds each answer into the rule
   text, an example or a table row. A spec never has a "Decisions" section.

Also:

- Use the domain's own terms. No UI steps. Explain a technical term in plain words once.
- If the story changes a running system, also cover failure, compatibility, and "existing behaviour is unchanged" rules.
- Each example shows a different business outcome or rule boundary. Cover the normal case first. Drop an example that
  only changes amounts, names, or wording.
- A table and the bullets never repeat each other. Add a bullet only for an outcome the table does not show.
- A row or example may point to another rule with `(Rule NN)`. Keep every cross-reference correct after a renumber.

### Counter-example test

Keep a counter-example only if all three answers are "yes":

1. Is it a real business case, not a bug or a failure?
2. Could a reader expect the rule to apply here?
3. Does the rule's outcome NOT happen? Say what happens instead.

A candidate that fails the test is something else. Put it where it belongs:

| It is really...                         | Put it in                                                 |
|-----------------------------------------|-----------------------------------------------------------|
| a case where the rule's outcome happens | **Example:**, or delete it if the table already covers it |
| the same case as a table row            | nothing                                                   |
| the reason for the rule                 | nothing, or `## How it works today`                       |
| a new constraint                        | a new rule                                                |
| a risk or a decision with no answer     | **Questions:**                                            |
| a code or design note (how, not what)   | nothing                                                   |

For the rule "Must send a confirmation email when an order is placed":

- Good: "The one where a staff member places a phone order for a customer with no email address. No email is sent. The
  receipt is printed instead." A reader may expect every order to send an email.
- Bad: "The one where two orders are placed in the same second. Two emails are sent." One email per order is the rule
  itself, so this is an Example.

## Format (checked by `check-spec.sh`)

Run `check-spec.sh` (next to this file) after every write. It must print nothing. Copy the skeleton below, and also:

- Start the file with the frontmatter block from the skeleton. The Spec Cards tab and `check-spec.sh` need it.
- Never indent a table or a label bullet. After a table, a 4-space indent renders as a code block.
- Put a blank line before and after every table.
- Never repeat a label in one rule. A context sentence stays in the same sub-bullet as its question.
- Leave out a Counter-example or Questions bullet with no item. Never write "none".
- Fill prose lines up to 120 characters. Indent a wrapped line to its bullet text: 2 spaces, or 6 in a sub-bullet.
- No long dashes. Use "-".
- A rule heading may end with one status tag: `` `[in progress]` `` or `` `[done]` ``. Only `/sdd:accept` sets it, and
  at most one rule is `[in progress]`. `/sdd:discover` never writes a tag. `/sdd:resolve` keeps every tag as it is, also
  on a renumber. If it rewrites a tagged rule, it says so in one line: the rule's acceptance tests may no longer match.

With no ticket, the title is just `# <short feature name>`. `## Terms` and `## How it works today` are optional. Add
them only when the rules need them. Rule 01 shows one item per label, kept on the label line. Rule 02 shows more than
one: the label alone, each item a sub-bullet 4 spaces in. Rule 03 shows a table that holds the examples, so no Example
bullet repeats them.

```markdown
---
type: example-mapping
---

# <TICKET-KEY> - <short feature name>

**Story:** As a <role>, I want <capability>, so that <benefit>.

## Terms

| Term | Meaning |
|------|---------|
| ...  | ...     |

## How it works today

- ...

## Rules

### **Rule 01:** Must...

- **Example:** The one where...
- **Counter-example:** The one where...
- **Questions:** ...

### **Rule 02:** Must...

- **Example:**
    - The one where...
    - The one where...
- **Questions:**
    - ...?
    - Context sentence. ...?

### **Rule 03:** Should...

| Input | Output |
|-------|--------|
| ...   | ...    |

- **Counter-example:** The one where...
```

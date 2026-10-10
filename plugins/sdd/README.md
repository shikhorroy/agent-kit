# sdd - spec-driven development

Six skills that take one feature from a ticket to a reviewed, green change. The spec is an Example Mapping file: rules,
examples, counter-examples and open questions.

```
discover → resolve                                   
  ▼                                                  
accept → tdd → verify → commit ◄────────────────────┐
                          ▼                         │
                  more rules to do? ── yes ─────────┤
                          ▼ no: every rule [done]   │
                     regression ── fixes: [rework] ─┘
                          ▼ verdict: Ready           
                         PR                          
```

`discover` and `resolve` run once per feature. `accept → tdd → verify → commit` runs once per rule. `regression` runs
once per branch, after every rule is `[done]`.

| Skill                        | What it does                                                              | Writes                |
|------------------------------|---------------------------------------------------------------------------|-----------------------|
| `discover <ticket or story>` | drafts the Example Mapping spec                                           | `docs/specs/<key>.md` |
| `resolve <spec> [rule]`      | answers the open questions, one rule at a time                            | the spec              |
| `accept <spec> [rule]`       | writes the failing acceptance tests for one rule, tags it `[in progress]` | test files, the tag   |
| `tdd [spec] [test]`          | runs red-green-refactor cycles until that acceptance test is green        | unit tests, code      |
| `verify [spec]`              | read-only review of the uncommitted changes against the spec              | nothing               |
| `regression <spec> [base]`   | whole-branch check: nothing of the feature left, no old feature broken    | `[rework]` rules      |

After the commit, run `accept` again. It tags the finished rule `[done]` and offers the next one.

## Status tags

The tags at the end of each rule heading are the only memory between sessions. A new session reads them and knows
where the work stands.

| Tag             | Means                                             | Set by       |
|-----------------|---------------------------------------------------|--------------|
| `[in progress]` | its acceptance tests are written, the code is not | `accept`     |
| `[done]`        | green and committed                               | `accept`     |
| `[rework]`      | was `[done]`, but `regression` found work left    | `regression` |

When you pick fixes in the `regression` picker, it tags each affected rule `[rework]` and adds a **Rework:** bullet:
what to change, and why. `accept` takes the `[rework]` rules first, with no extra question, and removes the bullet when
the rule is `[done]` again. Direct fixes, such as docs or leftovers, are not in the spec. The next `regression` run
finds them again if they are still open.

The agent can start `discover` by itself when you ask it to work out the rules of a feature. The other five run only
when you call them by name.

## Install

How you install the plugin and call a skill depends on the agent.

### Claude Code

```
/plugin marketplace add shikhorroy/agent-kit
/plugin install sdd@agent-kit
```

Call a skill with the plugin name in front, for example `/sdd:discover`. To try a local change, add the marketplace from
the cloned folder instead: `/plugin marketplace add ./agent-kit`.

### Other agents

Planned.

## Shared files

| File                             | Used by                               | Purpose                                               |
|----------------------------------|---------------------------------------|-------------------------------------------------------|
| `example-mapping/spec-format.md` | discover, resolve, accept, regression | the one source of the spec's content and format rules |
| `example-mapping/check-spec.sh`  | discover, resolve, accept, regression | format check; prints nothing when the spec is clean   |
| `hooks/report-gate.py`           | tdd, accept, regression               | blocks a picker that has no report before it          |

The skills find these files from the plugin's install folder, so the plugin works from any install location. Change a
spec rule only in `spec-format.md`. Run the check by hand with:

```bash
bash plugins/sdd/example-mapping/check-spec.sh docs/specs/<key>.md
```

The `report-gate.py` hook runs before every picker (`AskUserQuestion`), while `/sdd:tdd`, `/sdd:accept` or
`/sdd:regression` is the last skill you called. It needs `python3`.

| Skill        | The reply before the picker must have                                                                           |
|--------------|-----------------------------------------------------------------------------------------------------------------|
| `tdd`        | the Where line and the recommendation line; the rule tree too on the first picker and when a target turns green |
| `accept`     | the Step line and the recommendation line                                                                       |
| `regression` | the Base line and the recommendation line; the Verdict line too on the fixes picker                             |

- The reply can reach the transcript a moment after the hook starts. The hook waits up to 3 seconds for it.
- If the reply never shows up, the picker goes through.
- After 2 denials in a row, the picker goes through, so a session never gets stuck.

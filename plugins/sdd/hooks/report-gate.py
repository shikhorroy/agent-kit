#!/usr/bin/env python3
"""PreToolUse gate on AskUserQuestion during an /sdd:tdd or /sdd:accept run.

The picker is denied unless the reply that calls it holds the report:
- /sdd:tdd: a Where line and a recommendation line; on the first picker of the run, or when the Where line says the
  target is green, also the rule tree.
- /sdd:accept: a Step line and a recommendation line.

The reply can reach the transcript a moment after the hook starts, so the hook waits for the message that holds this
picker. If it never shows up, the picker goes through. Any error lets the picker through: the gate must never lock a
session.
"""
import json
import re
import sys
import time

MARKER = "[sdd report gate]"
MAX_DENIALS = 2
WAIT_SECONDS = 3.0
POLL_SECONDS = 0.1

WHERE = re.compile(r"\*\*Where:\*\*\s*Rule\s+\d+\b.*\btests?\s+\d+(?:-\d+)?\s+of\s+\d+\b.*\bcycle\s+\d+", re.I)
STEP = re.compile(r"\*\*Step\s+\d+/\d+\b")
RECOMMENDATION = re.compile(r"\*\*My recommendation:\*\*\s*\S")
TREE_HEADER = re.compile(r"^Rule\s+\d+\s+\S+:\d+\s", re.M)
TREE_TEST = re.compile(r"^\s*[|`]-\s*tests?\s+\d+", re.M)
TARGET_GREEN = re.compile(r"acceptance\s+test:\s*green", re.I)
COMMAND = re.compile(r"<command-name>/?([^<\s]+)</command-name>")
SKILLS = {"sdd:tdd": "tdd", "sdd:accept": "accept"}


def blocks(entry):
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    return content if isinstance(content, list) else []


def load(path):
    with open(path, encoding="utf-8") as f:
        entries = [json.loads(line) for line in f if line.strip()]
    return [e for e in entries if e.get("type") in ("user", "assistant") and not e.get("isSidechain")]


def holds(entry, tool_id):
    return any(b.get("type") == "tool_use" and b.get("id") == tool_id for b in blocks(entry))


def wait_for_reply(path, tool_id):
    """Entries up to the message that calls this picker, or None when it never reaches the transcript."""
    deadline = time.monotonic() + WAIT_SECONDS
    while True:
        entries = load(path)
        for i in range(len(entries) - 1, -1, -1):
            if entries[i]["type"] == "assistant" and holds(entries[i], tool_id):
                return entries[: i + 1]
        if time.monotonic() >= deadline:
            return None
        time.sleep(POLL_SECONDS)


def active_skill(entries):
    """Index and kind of the last skill or slash command, when it is a gated sdd skill."""
    start, kind = None, None
    for i, e in enumerate(entries):
        for b in blocks(e):
            name = None
            if e["type"] == "user" and b.get("type") == "text":
                m = COMMAND.search(b.get("text", ""))
                name = m.group(1) if m else None
            elif e["type"] == "assistant" and b.get("type") == "tool_use" and b.get("name") == "Skill":
                name = (b.get("input") or {}).get("skill")
            if name:
                start, kind = i, SKILLS.get(name.lstrip("/"))
    return start, kind


def reply_text(run):
    """Text of this step (back to the last tool result or user prompt), and the gate's denials in this turn."""
    texts, denials, in_step = [], 0, True
    for e in reversed(run):
        bs = blocks(e)
        if e["type"] == "user":
            results = [b for b in bs if b.get("type") == "tool_result"]
            if not results:
                break
            for r in results:
                if MARKER in json.dumps(r.get("content"), ensure_ascii=False):
                    denials += 1
            in_step = False
        elif in_step:
            texts[:0] = [b.get("text", "") for b in bs if b.get("type") == "text"]
    return "\n".join(texts), denials


def tdd_missing(text, first):
    missing = []
    where = WHERE.search(text)
    if not where:
        missing.append("the Where line, such as **Where:** Rule 07 | test 2 of 3 | cycle 1 of 2 | acceptance test: RED")
    if not RECOMMENDATION.search(text):
        missing.append("the **My recommendation:** line")
    where_line = text[where.start():].split("\n", 1)[0] if where else ""
    green = bool(TARGET_GREEN.search(where_line))
    if (first or green) and not (TREE_HEADER.search(text) and TREE_TEST.search(text)):
        why = "the first picker of the run" if first else "the target just turned green"
        missing.append(f"the rule tree in a ```text block ({why}): a 'Rule NN <path>:<line> (tag)' line, "
                       "then one '|- test <n> ...' or '`- test <n> ...' line per test")
    return missing


def accept_missing(text):
    missing = []
    if not STEP.search(text):
        missing.append("the Step line, such as **Step 2/8 - Choose the rule.** followed by the table or the proposal")
    if not RECOMMENDATION.search(text):
        missing.append("the **My recommendation:** line")
    return missing


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "AskUserQuestion":
        return
    path, tool_id = data["transcript_path"], data.get("tool_use_id")

    start, kind = active_skill(load(path))
    if kind is None:
        return
    entries = wait_for_reply(path, tool_id)
    if entries is None:
        return
    start, kind = active_skill(entries)
    if kind is None:
        return

    run = entries[start:]
    text, denials = reply_text(run)
    if denials >= MAX_DENIALS:
        return

    if kind == "tdd":
        denied = {b.get("tool_use_id") for e in run if e["type"] == "user" for b in blocks(e)
                  if b.get("type") == "tool_result" and MARKER in json.dumps(b.get("content"), ensure_ascii=False)}
        earlier = [b for e in run[:-1] if e["type"] == "assistant" for b in blocks(e)
                   if b.get("type") == "tool_use" and b.get("name") == "AskUserQuestion" and b.get("id") not in denied]
        missing = tdd_missing(text, first=not earlier)
        template = "the start template" if not earlier else "the cycle template"
        where = f"{template} of the sdd:tdd skill"
    else:
        missing = accept_missing(text)
        where = "the step context of the sdd:accept skill"
    if not missing:
        return

    reason = (f"{MARKER} Do not ask yet. Print the full report from {where} in this reply first, then call the "
              "picker again in the same reply. Missing: " + "; ".join(missing) + ". Never switch to a numbered text "
              "menu, and never tell the user the gate is wrong: it reads only this reply.")
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass

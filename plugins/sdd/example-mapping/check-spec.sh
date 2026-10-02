#!/usr/bin/env bash
# Format checks for an Example Mapping spec. Used by /sdd:discover and /sdd:resolve.
# The rules behind each check are in spec-format.md, next to this file.
# Prints each hit as "<line>: <problem>". Prints nothing and exits 0 when the spec is clean.
set -u

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "usage: check-spec.sh <spec.md>" >&2
    exit 2
fi
spec="$1"

out=$(
    LC_ALL=C.UTF-8 awk '
    function hit(n, msg) { print n ": " msg }
    function close_rule(   l) {
        if (!rule) return
        for (l in seen) if (seen[l] > 1) hit(rule_line, "Rule " rule_no " repeats the " l " label")
        if (alone_label != "") check_alone()
        delete seen
    }
    function check_alone() {
        if (alone_items == 1) hit(alone_line, alone_label " has one item; keep it on the label line")
        if (alone_items == 0) hit(alone_line, alone_label " label has no item")
        alone_label = ""
    }

    BEGIN { order["Example"] = 1; order["Counter-example"] = 2; order["Questions"] = 3; title_due = 1 }

    # frontmatter: must open the file and hold the spec marker; nothing inside it is checked further
    FNR == 1 && /^---[ ]*$/ { fm = 1; next }
    fm {
        if (/^---[ ]*$/) fm = 0
        else if (/^type:[ ]*["\047]?example-mapping["\047]?[ ]*$/) marker = 1
        next
    }

    # code fences: skip their content
    /^[ ]*```/ { fence = !fence; prev = ""; next }
    fence { next }

    # long dashes (en dash, em dash), as octal bytes so this file holds none and needs no grep -P
    index($0, "\342\200\223") || index($0, "\342\200\224") { hit(FNR, "long dash") }

    # title and story
    # title: the first non-blank line after the frontmatter
    title_due && /^$/ { next }
    title_due && !/^# [^ ]/ { hit(FNR, "the first line after the frontmatter is not a \"# <title>\" heading") }
    title_due && /^# [A-Z][A-Z0-9]*-[0-9]+/ && !/^# [A-Z][A-Z0-9]*-[0-9]+ - [^ ]/ {
        hit(FNR, "title is not \"# <TICKET-KEY> - <short feature name>\"")
    }
    title_due { title_due = 0 }
    /^\*\*Story:\*\*/ {
        story = 1
        if ($0 !~ /^\*\*Story:\*\* As an? .*, I want .*, so that /)
            hit(FNR, "story is not \"As a <role>, I want <capability>, so that <benefit>.\"")
    }

    # sections
    /^#+ .*Decisions/ { hit(FNR, "Decisions section; build each answer into its rule") }
    /^## /            { close_rule(); rule = 0; section = $0 }
    /^## Rules[ ]*$/  { rules_seen = 1 }
    section == "## Terms" && /^\|/ && !terms_head {
        terms_head = 1
        if ($0 !~ /^\| *Term *\| *Meaning *\|$/) hit(FNR, "Terms table header is not \"| Term | Meaning |\"")
    }

    # rule headings
    /^### / {
        close_rule()
        if (!rules_seen) hit(FNR, "rule heading before \"## Rules\"")
        if ($0 !~ /^### \*\*Rule [0-9][0-9]:\*\* (Must|Should)/) {
            hit(FNR, "rule heading is not \"### **Rule NN:** Must...\" or \"Should...\"")
        } else {
            n = substr($0, 12, 2) + 0
            if (n != expected + 1) hit(FNR, sprintf("rule number %02d, expected %02d", n, expected + 1))
            expected = n
        }
        rule = 1; rule_line = FNR; rule_no = substr($0, 12, 2); last_order = 0
        # status tag set by /sdd:accept: one at the end of the heading, at most one rule in progress
        if (match($0, /`\[[^]]*\]`[ ]*$/)) {
            tag = substr($0, RSTART, RLENGTH); sub(/[ ]*$/, "", tag)
            if (tag == "`[in progress]`") { if (++in_progress == 2) hit(FNR, "second rule tagged [in progress]") }
            else if (tag != "`[done]`") hit(FNR, "unknown status tag " tag "; use `[in progress]` or `[done]`")
        } else if (index($0, "[in progress]") || index($0, "[done]")) {
            hit(FNR, "status tag is not a `[...]` code span at the end of the heading")
        }
    }
    /^[ ]*[-*] +(Rule [0-9]+|Example|Counter-example|Questions):/ { hit(FNR, "label is not bold") }
    /^[ ]*[-*] +\*\*Rule [0-9]+:/ { hit(FNR, "rule written as a list item; use a ### heading") }

    # tables
    /^ +\|/ { hit(FNR, "indented table") }
    /^\|/ && prev != "" && prev !~ /^\|/ { hit(FNR, "no blank line before the table") }
    prev ~ /^\|/ && $0 != "" && !/^\|/   { hit(FNR, "no blank line after the table") }

    # Example / Counter-example / Questions bullets
    /^ +[-*] +\*\*(Example|Counter-example|Questions):\*\*/ { hit(FNR, "indented label bullet; start it at column 0") }
    alone_label != "" && /^    [-*] / { alone_items++ }
    alone_label != "" && !/^    [-*] / && !/^      [^ ]/ && !/^$/ { check_alone() }
    match($0, /^[-*] +\*\*(Example|Counter-example|Questions):\*\*/) {
        label = $0; sub(/^[-*] +\*\*/, "", label); sub(/:.*/, "", label)
        seen[label]++
        if (order[label] < last_order)
            hit(FNR, label " is out of order; use Example, Counter-example, Questions")
        last_order = order[label]
        rest = substr($0, RLENGTH + 1); gsub(/^ +| +$/, "", rest)
        if (tolower(rest) ~ /^(none|n\/a|-)\.?$/) hit(FNR, label " says \"" rest "\"; leave the bullet out")
        if (rest == "") { alone_label = label; alone_line = FNR; alone_items = 0 }
    }

    # line length and early wraps (tables and headings skipped)
    !/^\|/ && !/^#/ && length > 120 { hit(FNR, "prose line over 120 (" length ")") }
    {
        t = $0; sub(/^ +/, "", t)
        # first word; a `code span` counts as one word, since it must not be broken
        first = t; sub(/ .*/, "", first)
        if (match(t, /^[^ `]*`[^`]*`[^ ]*/)) first = substr(t, 1, RLENGTH)
        if (p != "" && t != "" && t !~ /^([-*#|>]|[0-9]+\.)/ && length(p) + 1 + length(first) <= 120)
            hit(FNR - 1, "wraps early; \"" first "\" fits on this line")
        p = (t == "" || t ~ /^[#|]/) ? "" : $0
        prev = $0
    }

    END {
        if (fm) hit(1, "frontmatter is not closed with ---")
        if (!marker) hit(1, "no \"type: example-mapping\" frontmatter")
        close_rule()
        if (!story) hit(1, "no **Story:** line")
        if (!rules_seen) hit(1, "no \"## Rules\" section")
    }
    ' "$spec"
)

if [ -n "$out" ]; then
    echo "$out" | sort -t: -k1,1n
    exit 1
fi

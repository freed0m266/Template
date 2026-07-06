#!/usr/bin/env python3
"""Generate a dark-mode Kanban dashboard of the Template task files.

Parses every `tasks/[0-9]*.md`, extracts a few lines of metadata (number,
title, status, priority/effort/impact, summary paragraph) with plain regex —
no markdown parser — and renders a single self-contained `tasks/dashboard.html`
(inline CSS + JS, no external assets). Each card embeds the full raw markdown
of its task file; clicking a card opens it in a modal (rendered client-side).

    python3 scripts/generate_dashboard.py            # regenerate + open
    python3 scripts/generate_dashboard.py --no-open  # regenerate only
    python3 scripts/generate_dashboard.py --serve    # live board on localhost

The static output is deterministic: same task data -> byte-identical HTML, so
it stays diff-friendly in git. No timestamps are embedded for that reason.

`--serve` runs a localhost-only stdlib HTTP server: `GET /` renders the board
fresh from the current `.md` files, and drag-and-dropping a card between
columns POSTs the new status back, rewriting the `**Status:**` line in the
task file (the `.md` files stay the single source of truth). The committed
static file is a read-only snapshot — drag-and-drop is disabled there.
"""

import argparse
import html
import json
import re
import subprocess
import sys
from collections import defaultdict
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TASKS_DIR = REPO_ROOT / "tasks"

# --- separators / dashes seen in the source files -------------------------
MIDDOT = "·"          # · field separator on the Priorita line
DASHES = "—–-"   # em-dash, en-dash, hyphen (used interchangeably)

# Column definitions: (status key, display label, border-top accent color).
COLUMNS = [
    ("todo", "Todo", "#5b9bd5"),
    ("done", "Done", "#6abf69"),
    ("canceled", "Canceled", "#6a4a4a"),
]

# Impact head word -> (css class suffix). Lookup is case-insensitive; the
# original (source-cased) head word is kept for display.
IMPACT_CLASS = {
    "blokující": "blocking",
    "high": "high",
    "medium": "medium",
    "low": "low",
    "none": "none",
}


# --------------------------------------------------------------------------
# Parsing
# --------------------------------------------------------------------------

def task_number(path):
    """Leading number from a `NN-slug.md` filename."""
    m = re.match(r"(\d+)-", path.name)
    if not m:
        raise SystemExit(f"Cannot parse task number from filename: {path}")
    return int(m.group(1))


def parse_title(lines, path):
    """`# NN — Title` -> 'Title'. Falls back to the filename slug."""
    for ln in lines:
        m = re.match(r"^#\s+\d+\s*[" + DASHES + r"]+\s*(.+?)\s*$", ln)
        if m:
            return m.group(1)
    sys.stderr.write(f"warning: no title heading in {path}\n")
    return path.stem


def parse_status(lines, path):
    """Return ('todo'|'done'|'canceled', completion_date_or_None).

    Matches only the exact `**Status:**` line — files may also carry a
    `**Status (history):**` / `**Status (předchozí):**` line which must be
    ignored. Older status lines below the first one are history (newest on
    top); only the first counts. An unrecognized status — including the
    retired 'Draft' — is a hard failure (better signal than a silent skip).
    """
    for ln in lines:
        m = re.match(r"^\s*\*\*Status:\*\*\s*(.*)$", ln)
        if not m:
            continue
        value = m.group(1).strip()
        if re.match(r"^Done\b", value):
            d = re.search(r"(\d{4}-\d{2}-\d{2})", value)
            if not d:
                raise SystemExit(
                    f"Malformed status in {path}:\n    {ln.strip()!r}\n"
                    f"A 'Done' status requires a completion date: 'Done — YYYY-MM-DD'."
                )
            return "done", d.group(1)
        if re.match(r"^Todo\b", value):
            return "todo", None
        if re.match(r"^Canceled\b", value):
            return "canceled", None
        raise SystemExit(
            f"Malformed status in {path}:\n    {ln.strip()!r}\n"
            f"Expected one of: 'Todo …', 'Done — YYYY-MM-DD', 'Canceled[ — reason]'."
        )
    raise SystemExit(f"No '**Status:**' line found in {path}")


def parse_meta(lines, path):
    """Parse the `**Priorita:** X · **Úsilí:** Y · **Dopad:** Z` line.

    Returns (priority_bucket, priority_display, effort, impact_class,
    impact_display). Missing/garbled lines warn and fall back to neutral
    defaults rather than crashing (only status is a hard requirement).
    """
    pat = (
        r"\*\*Priorita:\*\*\s*(.*?)\s*" + MIDDOT +
        r"\s*\*\*Úsilí:\*\*\s*(.*?)\s*" + MIDDOT +
        r"\s*\*\*Dopad:\*\*\s*(.*)$"
    )
    for ln in lines:
        m = re.search(pat, ln)
        if not m:
            continue
        prio_raw, effort_raw, impact_raw = (g.strip() for g in m.groups())

        # Priority bucket: cut the freeform parenthetical rationale, then
        # collapse a leading version token (v1.0 … v1.x) to just the version.
        # The full string survives for display in the card's priority badge.
        head = prio_raw.split("(", 1)[0].strip()
        vm = re.match(r"(v\d+\.(?:\d+|x))\b", head)
        bucket = vm.group(1) if vm else (head or prio_raw)

        # Effort: keep the single leading token (drops trailing parentheticals
        # like task 28's "S (designerská práce externí)").
        effort = effort_raw.split()[0] if effort_raw.split() else effort_raw

        # Impact: first word before any space/paren drives the color bucket.
        head_m = re.match(r"\s*([^\s(]+)", impact_raw)
        head = head_m.group(1) if head_m else impact_raw
        impact_class = IMPACT_CLASS.get(head.lower(), "none")

        return bucket, prio_raw, effort, impact_class, head

    sys.stderr.write(f"warning: no '**Priorita:**' line found in {path}\n")
    return "—", "", "", "none", ""


def strip_inline_markdown(text):
    """Flatten links, bold and inline code; collapse whitespace."""
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)  # [text](href) -> text
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)        # **x** -> x
    text = re.sub(r"`([^`]*)`", r"\1", text)              # `x` -> x
    return re.sub(r"\s+", " ", text).strip()


def truncate(text, limit=180):
    """Truncate to `limit` chars on a word boundary, appending an ellipsis."""
    if len(text) <= limit:
        return text
    cut = text[:limit]
    space = cut.rfind(" ")
    if space > 0:
        cut = cut[:space]
    return cut.rstrip() + "…"


def parse_summary(lines, path):
    """First non-empty paragraph under the first `## Cíl` or `## Souhrn`."""
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^##\s+(Cíl|Souhrn)\b", ln):
            start = i + 1
            break
    if start is None:
        sys.stderr.write(f"warning: no '## Cíl' or '## Souhrn' section in {path}\n")
        return ""
    j = start
    while j < len(lines) and not lines[j].strip():
        j += 1
    para = []
    while j < len(lines) and lines[j].strip():
        para.append(lines[j].strip())
        j += 1
    return truncate(strip_inline_markdown(" ".join(para)))


def parse_task(path):
    raw = path.read_text(encoding="utf-8")
    lines = raw.splitlines()
    bucket, prio_display, effort, impact_class, impact_display = parse_meta(lines, path)
    status, done_date = parse_status(lines, path)
    return {
        "number": task_number(path),
        "title": parse_title(lines, path),
        "status": status,
        "done_date": done_date,
        "bucket": bucket,
        "priority": prio_display,
        "effort": effort,
        "impact_class": impact_class,
        "impact": impact_display,
        "summary": parse_summary(lines, path),
        "raw": raw,
    }


def load_tasks():
    task_files = sorted(TASKS_DIR.glob("[0-9]*.md"), key=task_number)
    if not task_files:
        raise SystemExit(f"No task files found in {TASKS_DIR}")
    return [parse_task(p) for p in task_files]


# --------------------------------------------------------------------------
# Sorting / grouping
# --------------------------------------------------------------------------

def bucket_sort_key(bucket):
    """Natural order: v1.0 < v1.1 < … < v1.x < Tech debt < Pre-App-Store < other."""
    vm = re.match(r"v(\d+)\.(\d+|x)$", bucket)
    if vm:
        minor = float("inf") if vm.group(2) == "x" else int(vm.group(2))
        return (0, int(vm.group(1)), minor, "")
    fixed = {"Tech debt": 1, "Pre-App-Store": 2}
    if bucket in fixed:
        return (fixed[bucket], 0, 0, "")
    return (3, 0, 0, bucket)


def is_version_bucket(bucket):
    return re.match(r"v\d+\.(\d+|x)$", bucket) is not None


def sorted_buckets(tasks):
    """Unique buckets present, in display order."""
    seen = {t["bucket"] for t in tasks}
    return sorted(seen, key=bucket_sort_key)


def column_tasks(tasks, status):
    items = [t for t in tasks if t["status"] == status]
    if status == "todo":
        return sorted(items, key=lambda t: (bucket_sort_key(t["bucket"]), t["number"]))
    if status == "canceled":
        return sorted(items, key=lambda t: t["number"])
    # done: freshest completion first, newer task number breaks ties.
    return sorted(items, key=lambda t: (t["done_date"] or "", t["number"]), reverse=True)


# --------------------------------------------------------------------------
# Status writeback (used by --serve)
# --------------------------------------------------------------------------

# A "bare" status value: nothing hand-written beyond the plain status format.
BARE_STATUS_RE = re.compile(
    r"^(?:Todo"
    r"|Done\s*[" + DASHES + r"]\s*\d{4}-\d{2}-\d{2}"
    r"|Canceled(?:\s*[" + DASHES + r"].*)?"
    r")$"
)


def status_line(status, today):
    """The bare `**Status:**` line written for a drag-and-drop change."""
    if status == "done":
        return f"**Status:** Done — {today}"
    if status == "canceled":
        return "**Status:** Canceled"
    return "**Status:** Todo"


def apply_status_change(path, status, today):
    """Rewrite the topmost `**Status:**` line of `path` to `status`.

    Task files keep older status lines as history (newest on top; the parser
    reads only the first). A bare top line is overwritten in place; a line
    carrying hand-written prose is preserved as history and the new bare line
    is inserted above it.

    Returns ('replaced'|'prepended', new_line) so the client can replay the
    same edit on its embedded copy of the file (keeps the modal fresh without
    duplicating the bare-vs-prose rule in JS).
    """
    lines = path.read_text(encoding="utf-8").splitlines()
    for i, ln in enumerate(lines):
        m = re.match(r"^\s*\*\*Status:\*\*\s*(.*)$", ln)
        if not m:
            continue
        new_line = status_line(status, today)
        if BARE_STATUS_RE.match(m.group(1).strip()):
            lines[i] = new_line
            mode = "replaced"
        else:
            lines[i:i] = [new_line, ""]
            mode = "prepended"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return mode, new_line
    raise ValueError(f"No '**Status:**' line found in {path}")


# --------------------------------------------------------------------------
# HTML rendering
# --------------------------------------------------------------------------

CSS = """
:root { color-scheme: dark; }
* { box-sizing: border-box; }
html, body { background: #0a0a0a; margin: 0; }
body {
  color: #e5e5e5;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 14px;
  line-height: 1.45;
}
.num, .progress-label, footer.done { font-family: ui-monospace, "SF Mono", Menlo, monospace; }

header.site {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #0a0a0a;
  border-bottom: 1px solid #222;
  padding: 16px 20px;
}
header.site h1 { margin: 0 0 4px; font-size: 18px; font-weight: 600; }
.stats { color: #888; font-size: 13px; }
.stats .mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; }

.progress-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 8px 20px;
  margin: 12px 0 4px;
}
.progress-row { display: flex; align-items: center; gap: 10px; min-width: 0; }
.progress-track {
  flex: 1;
  min-width: 80px;
  height: 6px;
  background: #1c1c1c;
  border-radius: 999px;
  overflow: hidden;
}
.progress-fill { height: 100%; border-radius: 999px; }
.progress-label {
  font-size: 12px;
  color: #888;
  white-space: nowrap;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.controls { display: flex; flex-direction: column; gap: 10px; margin-top: 14px; }
input[type="search"] {
  width: 100%;
  background: #141414;
  border: 1px solid #222;
  border-radius: 8px;
  color: #e5e5e5;
  font-size: 14px;
  padding: 8px 12px;
}
input[type="search"]::placeholder { color: #555; }
input[type="search"]:focus { outline: none; border-color: #3a3a3a; }

.filter-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.filter-chips button {
  font: inherit;
  font-size: 11px;
  cursor: pointer;
  border-radius: 999px;
  padding: 3px 10px;
  border: 1px solid #333;
  background: transparent;
  color: #aaa;
  max-width: 100%;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.filter-chips button:hover { border-color: #444; }
.filter-chips button.active { background: #333; color: #fff; border-color: #333; }

main.board {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  padding: 20px;
  align-items: start;
}
@media (max-width: 900px) { main.board { grid-template-columns: 1fr; } }

.column { border-top: 2px solid #555; padding-top: 12px; }
.column[data-status="todo"] { border-top-color: #5b9bd5; }
.column[data-status="done"] { border-top-color: #6abf69; }
.column[data-status="canceled"] { border-top-color: #6a4a4a; }
.column[data-status="canceled"] .card { opacity: 0.6; }
.column.drag-over { outline: 1px dashed #444; outline-offset: 6px; border-radius: 8px; background: #101010; }
.column h2 {
  margin: 0 0 12px;
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #aaa;
}
.column h2 .count {
  color: #555;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  margin-left: 4px;
}

.card {
  background: #141414;
  border: 1px solid #222;
  border-radius: 8px;
  padding: 14px;
  margin-bottom: 12px;
  cursor: pointer;
}
.card:hover { border-color: #333; }
.card[hidden] { display: none; }
.card.dragging { opacity: 0.4; }
.card > header { display: flex; align-items: baseline; gap: 8px; margin-bottom: 8px; }
.card .num { color: #555; font-size: 12px; }
.card h3 { margin: 0; font-size: 14px; font-weight: 600; }

.badges { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
.badge {
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 11px;
  white-space: nowrap;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
}
.badge.priority, .badge.effort { border: 1px solid #333; color: #aaa; }
.badge.impact-blocking { background: #5a1f1f; color: #ffb4b4; }
.badge.impact-high { background: #5a3a1f; color: #ffd4a8; }
.badge.impact-medium { background: #4a4a1f; color: #f0e0a0; }
.badge.impact-low,
.badge.impact-none { background: #2a2a2a; color: #888; }

.card .summary { margin: 0; color: #bbb; font-size: 13px; }
.card footer.done { margin-top: 10px; color: #6abf69; font-size: 11px; }

.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.65);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 40px 20px;
}
.modal-backdrop[hidden] { display: none; }
.modal {
  background: #141414;
  border: 1px solid #222;
  border-radius: 12px;
  max-width: 760px;
  width: 100%;
  max-height: calc(100vh - 80px);
  overflow-y: auto;
  padding: 20px 28px 28px;
}
.modal-close {
  position: sticky;
  top: 0;
  float: right;
  font: inherit;
  font-size: 16px;
  line-height: 1;
  width: 30px;
  height: 30px;
  cursor: pointer;
  background: #1e1e1e;
  color: #888;
  border: 1px solid #333;
  border-radius: 8px;
}
.modal-close:hover { color: #fff; border-color: #444; }

.md { font-size: 14px; }
.md h1 { font-size: 20px; margin: 4px 0 12px; }
.md h2 { font-size: 16px; margin: 20px 0 8px; border-bottom: 1px solid #222; padding-bottom: 4px; }
.md h3 { font-size: 14px; margin: 16px 0 6px; }
.md h4, .md h5, .md h6 { font-size: 13px; margin: 12px 0 6px; color: #ccc; }
.md p, .md li { color: #bbb; }
.md li { margin: 3px 0; }
.md a { color: #5b9bd5; }
.md code {
  background: #1e1e1e;
  border: 1px solid #2a2a2a;
  border-radius: 4px;
  padding: 1px 5px;
  font-size: 12px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
}
.md pre {
  background: #0f0f0f;
  border: 1px solid #222;
  border-radius: 8px;
  padding: 12px;
  overflow-x: auto;
}
.md pre code { background: none; border: none; padding: 0; font-size: 12px; display: block; }
.md blockquote { border-left: 3px solid #333; margin: 8px 0; padding: 2px 12px; color: #999; }
.md table { border-collapse: collapse; margin: 10px 0; font-size: 13px; display: block; overflow-x: auto; }
.md th, .md td { border: 1px solid #2a2a2a; padding: 5px 10px; text-align: left; color: #bbb; }
.md th { color: #ddd; background: #181818; }
.md hr { border: none; border-top: 1px solid #222; margin: 16px 0; }

.toast {
  position: fixed;
  right: 16px;
  bottom: 16px;
  z-index: 200;
  background: #5a1f1f;
  color: #ffb4b4;
  border: 1px solid #7a2f2f;
  border-radius: 8px;
  padding: 10px 14px;
  font-size: 13px;
  max-width: 360px;
}
""".strip("\n")

JS = """
(function () {
  var SERVE = __SERVE__;
  var search = document.getElementById("search");
  var chips = Array.prototype.slice.call(document.querySelectorAll(".filter-chips button"));
  var cards = Array.prototype.slice.call(document.querySelectorAll(".card"));
  var columns = Array.prototype.slice.call(document.querySelectorAll(".column"));
  var activeFilter = "all";

  // --- search + priority filter -------------------------------------------

  function apply() {
    var q = search.value.trim().toLowerCase();
    cards.forEach(function (card) {
      var matchesSearch = !q || card.dataset.search.indexOf(q) !== -1;
      var matchesFilter = activeFilter === "all" || card.dataset.priority === activeFilter;
      card.hidden = !(matchesSearch && matchesFilter);
    });
    columns.forEach(function (col) {
      var visible = col.querySelectorAll(".card:not([hidden])").length;
      col.querySelector(".count").textContent = visible;
    });
  }

  search.addEventListener("input", apply);
  chips.forEach(function (chip) {
    chip.addEventListener("click", function () {
      chips.forEach(function (c) { c.classList.remove("active"); });
      chip.classList.add("active");
      activeFilter = chip.dataset.filter;
      apply();
    });
  });

  // --- tiny markdown renderer (covers what the task files use) -------------

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function inline(s) {
    s = escapeHtml(s);
    var codes = [];
    s = s.replace(/`([^`]*)`/g, function (_, code) {
      codes.push(code);
      return "\\u0000" + (codes.length - 1) + "\\u0000";
    });
    s = s.replace(/&lt;(https?:\\/\\/[^\\s&]+)&gt;/g,
                  '<a href="$1" target="_blank" rel="noopener">$1</a>');
    s = s.replace(/\\[([^\\]]+)\\]\\(([^)\\s]+)\\)/g,
                  '<a href="$2" target="_blank" rel="noopener">$1</a>');
    s = s.replace(/\\*\\*([^*]+)\\*\\*/g, "<strong>$1</strong>");
    s = s.replace(/\\*([^*]+)\\*/g, "<em>$1</em>");
    s = s.replace(/\\u0000(\\d+)\\u0000/g, function (_, i) {
      return "<code>" + codes[+i] + "</code>";
    });
    return s;
  }

  function renderMarkdown(src) {
    var lines = src.split("\\n");
    var out = [];
    var listStack = [];
    var i = 0;

    function closeLists() {
      while (listStack.length) out.push("</" + listStack.pop().type + ">");
    }
    function splitRow(row) {
      var s = row.trim();
      if (s.charAt(0) === "|") s = s.slice(1);
      if (s.charAt(s.length - 1) === "|") s = s.slice(0, -1);
      return s.split("|").map(function (c) { return c.trim(); });
    }

    while (i < lines.length) {
      var line = lines[i];

      if (/^\\s*```/.test(line)) {                      // fenced code block
        closeLists();
        var code = [];
        i += 1;
        while (i < lines.length && !/^\\s*```/.test(lines[i])) {
          code.push(lines[i]);
          i += 1;
        }
        i += 1;
        out.push("<pre><code>" + escapeHtml(code.join("\\n")) + "</code></pre>");
        continue;
      }

      var h = line.match(/^(#{1,6})\\s+(.*)$/);          // heading
      if (h) {
        closeLists();
        out.push("<h" + h[1].length + ">" + inline(h[2]) + "</h" + h[1].length + ">");
        i += 1;
        continue;
      }

      if (/^\\s*---+\\s*$/.test(line)) {                 // horizontal rule
        closeLists();
        out.push("<hr>");
        i += 1;
        continue;
      }

      if (/^\\s*>/.test(line)) {                         // blockquote
        closeLists();
        var quote = [];
        while (i < lines.length && /^\\s*>/.test(lines[i])) {
          quote.push(lines[i].replace(/^\\s*>\\s?/, ""));
          i += 1;
        }
        out.push("<blockquote>" + quote.map(inline).join("<br>") + "</blockquote>");
        continue;
      }

      if (/^\\s*\\|/.test(line) && i + 1 < lines.length &&  // table
          /^\\s*\\|[\\s|:-]*$/.test(lines[i + 1]) &&
          lines[i + 1].indexOf("-") !== -1) {
        closeLists();
        var head = splitRow(line);
        i += 2;
        var rows = "<tr>" + head.map(function (c) {
          return "<th>" + inline(c) + "</th>";
        }).join("") + "</tr>";
        while (i < lines.length && /^\\s*\\|/.test(lines[i])) {
          rows += "<tr>" + splitRow(lines[i]).map(function (c) {
            return "<td>" + inline(c) + "</td>";
          }).join("") + "</tr>";
          i += 1;
        }
        out.push("<table>" + rows + "</table>");
        continue;
      }

      var li = line.match(/^(\\s*)([-*+]|\\d+\\.)\\s+(.*)$/);  // list item
      if (li) {
        var indent = li[1].length;
        var type = /^\\d/.test(li[2]) ? "ol" : "ul";
        var text = li[3];
        var cb = text.match(/^\\[([ xX])\\]\\s*(.*)$/);
        if (cb) text = (cb[1] === " " ? "\\u2610 " : "\\u2611 ") + cb[2];
        while (listStack.length && indent < listStack[listStack.length - 1].indent) {
          out.push("</" + listStack.pop().type + ">");
        }
        var top = listStack[listStack.length - 1];
        if (!top || indent > top.indent) {
          listStack.push({ type: type, indent: indent });
          out.push("<" + type + ">");
        } else if (top.type !== type) {
          out.push("</" + listStack.pop().type + ">");
          listStack.push({ type: type, indent: indent });
          out.push("<" + type + ">");
        }
        out.push("<li>" + inline(text) + "</li>");
        i += 1;
        continue;
      }

      if (!line.trim()) {                                // blank line
        closeLists();
        i += 1;
        continue;
      }

      closeLists();                                      // paragraph
      var para = [line.trim()];
      i += 1;
      while (i < lines.length && lines[i].trim() &&
             !/^(#{1,6}\\s|\\s*```|\\s*>|\\s*([-*+]|\\d+\\.)\\s|\\s*\\|)/.test(lines[i])) {
        para.push(lines[i].trim());
        i += 1;
      }
      out.push("<p>" + inline(para.join(" ")) + "</p>");
    }
    closeLists();
    return out.join("\\n");
  }

  // --- task detail modal ----------------------------------------------------

  var modal = document.getElementById("modal");
  var modalBody = document.getElementById("modal-body");
  var suppressClick = false;

  function openModal(card) {
    var src = card.querySelector(".md-source");
    if (!src) return;
    modalBody.innerHTML = renderMarkdown(src.textContent);
    modal.hidden = false;
    modal.querySelector(".modal").scrollTop = 0;
  }
  function closeModal() { modal.hidden = true; }

  cards.forEach(function (card) {
    card.addEventListener("click", function () {
      if (suppressClick) return;
      openModal(card);
    });
  });
  modal.addEventListener("click", function (e) {
    if (e.target === modal) closeModal();
  });
  document.getElementById("modal-close").addEventListener("click", closeModal);
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !modal.hidden) closeModal();
  });
  // Cross-references to sibling task files open that task's modal in place.
  modalBody.addEventListener("click", function (e) {
    var a = e.target && e.target.closest && e.target.closest("a");
    if (!a) return;
    var m = (a.getAttribute("href") || "").match(/^(\\d+)-[^\\/]*\\.md$/);
    if (!m) return;
    var card = document.querySelector('.card[data-number="' + parseInt(m[1], 10) + '"]');
    if (card) {
      e.preventDefault();
      openModal(card);
    }
  });

  // --- counts / progress recompute (after a drag) ---------------------------

  function recount() {
    apply();
    ["todo", "done", "canceled"].forEach(function (status) {
      var el = document.getElementById("stat-" + status);
      if (el) {
        el.textContent = document.querySelectorAll(
          '.column[data-status="' + status + '"] .card').length;
      }
    });
    Array.prototype.slice.call(document.querySelectorAll(".progress-row")).forEach(function (row) {
      var bucket = row.getAttribute("data-bucket");
      var escaped = (window.CSS && CSS.escape) ? CSS.escape(bucket) : bucket;
      var sel = '.card[data-priority="' + escaped + '"]';
      var total = document.querySelectorAll(sel).length;
      var done = document.querySelectorAll('.column[data-status="done"] ' + sel).length;
      var canceled = document.querySelectorAll('.column[data-status="canceled"] ' + sel).length;
      var denom = total - canceled;
      var pct = denom ? Math.round(done / denom * 100) : 0;
      row.querySelector(".progress-fill").style.width = pct + "%";
      var label = bucket + " — " + done + "/" + denom + " (" + pct + "%)";
      var labelEl = row.querySelector(".progress-label");
      labelEl.textContent = label;
      labelEl.title = label;
    });
  }

  var toastTimer = null;
  function showToast(message) {
    var toast = document.getElementById("toast");
    toast.textContent = message;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.hidden = true; }, 4000);
  }

  // --- drag-and-drop status change (needs --serve for the writeback) --------

  function setDoneFooter(card, text) {
    var footer = card.querySelector("footer.done");
    if (!text) {
      if (footer) footer.remove();
      return;
    }
    if (!footer) {
      footer = document.createElement("footer");
      footer.className = "done";
      card.appendChild(footer);
    }
    footer.textContent = text;
  }

  // Replay the server's status-line edit on the card's embedded markdown so
  // the modal stays in sync with the file without a full reload.
  function patchSource(card, data) {
    if (!data.line || !data.mode) return;
    var src = card.querySelector(".md-source");
    if (!src) return;
    var lines = src.textContent.split("\\n");
    for (var i = 0; i < lines.length; i += 1) {
      if (/^\\s*\\*\\*Status:\\*\\*/.test(lines[i])) {
        if (data.mode === "replaced") lines[i] = data.line;
        else lines.splice(i, 0, data.line, "");
        src.textContent = lines.join("\\n");
        return;
      }
    }
  }

  function moveCard(card, fromCol, toCol) {
    var revertSibling = card.nextElementSibling;
    var oldFooter = card.querySelector("footer.done");
    var oldFooterText = oldFooter ? oldFooter.textContent : "";
    var newStatus = toCol.dataset.status;

    toCol.appendChild(card);
    if (newStatus !== "done") setDoneFooter(card, "");
    recount();

    fetch("/status", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ number: parseInt(card.dataset.number, 10), status: newStatus })
    }).then(function (res) {
      if (!res.ok) throw new Error("HTTP " + res.status);
      return res.json();
    }).then(function (data) {
      if (newStatus === "done" && data.date) setDoneFooter(card, "Done " + data.date);
      patchSource(card, data);
    }).catch(function (err) {
      fromCol.insertBefore(card, revertSibling);
      setDoneFooter(card, oldFooterText);
      recount();
      showToast("Failed to move #" + card.dataset.number + " — " + err.message);
    });
  }

  if (SERVE) {
    var dragCard = null;
    cards.forEach(function (card) {
      card.setAttribute("draggable", "true");
      card.addEventListener("dragstart", function (e) {
        dragCard = card;
        suppressClick = true;
        card.classList.add("dragging");
        e.dataTransfer.effectAllowed = "move";
        e.dataTransfer.setData("text/plain", card.dataset.number);
      });
      card.addEventListener("dragend", function () {
        card.classList.remove("dragging");
        dragCard = null;
        columns.forEach(function (c) { c.classList.remove("drag-over"); });
        setTimeout(function () { suppressClick = false; }, 0);
      });
    });
    columns.forEach(function (col) {
      col.addEventListener("dragover", function (e) {
        if (!dragCard) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
        col.classList.add("drag-over");
      });
      col.addEventListener("dragleave", function (e) {
        if (!col.contains(e.relatedTarget)) col.classList.remove("drag-over");
      });
      col.addEventListener("drop", function (e) {
        if (!dragCard) return;
        e.preventDefault();
        col.classList.remove("drag-over");
        var fromCol = dragCard.closest(".column");
        if (fromCol !== col) moveCard(dragCard, fromCol, col);
      });
    });
  }
})();
""".strip("\n")


def esc(text):
    return html.escape(str(text), quote=True)


def render_card(task):
    search_blob = (task["title"] + " " + task["summary"]).lower()
    parts = []
    parts.append(
        f'        <article class="card" data-number="{task["number"]}" '
        f'data-priority="{esc(task["bucket"])}" '
        f'data-impact="{esc(task["impact_class"])}" data-search="{esc(search_blob)}">'
    )
    parts.append('          <header>')
    parts.append(f'            <span class="num">#{task["number"]:02d}</span>')
    parts.append(f'            <h3>{esc(task["title"])}</h3>')
    parts.append('          </header>')

    badges = []
    if task["priority"]:
        badges.append(
            f'            <span class="badge priority" title="{esc(task["priority"])}">'
            f'{esc(task["priority"])}</span>'
        )
    if task["effort"]:
        badges.append(f'            <span class="badge effort">{esc(task["effort"])}</span>')
    if task["impact"]:
        badges.append(
            f'            <span class="badge impact impact-{esc(task["impact_class"])}">'
            f'{esc(task["impact"])}</span>'
        )
    if badges:
        parts.append('          <div class="badges">')
        parts.extend(badges)
        parts.append('          </div>')

    if task["summary"]:
        parts.append(f'          <p class="summary">{esc(task["summary"])}</p>')
    if task["status"] == "done" and task["done_date"]:
        parts.append(f'          <footer class="done">Done {esc(task["done_date"])}</footer>')

    # Full raw markdown for the detail modal; recovered via textContent.
    parts.append(
        f'          <div class="md-source" hidden>{html.escape(task["raw"], quote=False)}</div>'
    )
    parts.append('        </article>')
    return "\n".join(parts)


def render_column(tasks, status, label):
    cards = column_tasks(tasks, status)
    lines = [
        f'      <section class="column" data-status="{status}">',
        f'        <h2>{label} <span class="count">{len(cards)}</span></h2>',
    ]
    lines.extend(render_card(t) for t in cards)
    lines.append('      </section>')
    return "\n".join(lines)


def render_progress(tasks):
    by_total = defaultdict(int)
    by_done = defaultdict(int)
    by_canceled = defaultdict(int)
    for t in tasks:
        by_total[t["bucket"]] += 1
        if t["status"] == "done":
            by_done[t["bucket"]] += 1
        elif t["status"] == "canceled":
            by_canceled[t["bucket"]] += 1

    rows = []
    for bucket in sorted_buckets(tasks):
        done = by_done[bucket]
        # Canceled tasks leave the denominator — a bucket where something got
        # canceled can still reach 100 %.
        denom = by_total[bucket] - by_canceled[bucket]
        pct = round(done / denom * 100) if denom else 0
        color = "#6abf69" if is_version_bucket(bucket) else "#888"
        label = f"{bucket} — {done}/{denom} ({pct}%)"
        rows.append(
            f'        <div class="progress-row" data-bucket="{esc(bucket)}">\n'
            '          <div class="progress-track">'
            f'<div class="progress-fill" style="width:{pct}%;background:{color}"></div></div>\n'
            f'          <span class="progress-label" title="{esc(label)}">{esc(label)}</span>\n'
            '        </div>'
        )
    return "\n".join(rows)


def render_chips(tasks):
    chips = ['        <button data-filter="all" class="active">All</button>']
    for bucket in sorted_buckets(tasks):
        chips.append(
            f'        <button data-filter="{esc(bucket)}" title="{esc(bucket)}">'
            f'{esc(bucket)}</button>'
        )
    return "\n".join(chips)


def render_html(tasks, serve=False):
    n_total = len(tasks)
    n_done = sum(1 for t in tasks if t["status"] == "done")
    n_todo = sum(1 for t in tasks if t["status"] == "todo")
    n_canceled = sum(1 for t in tasks if t["status"] == "canceled")

    columns = "\n".join(render_column(tasks, status, label) for status, label, _ in COLUMNS)
    js = JS.replace("__SERVE__", "true" if serve else "false")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <title>Template tasks</title>
  <style>
{CSS}
  </style>
</head>
<body>
  <header class="site">
    <h1>Template tasks</h1>
    <div class="stats">
      <span class="mono">{n_total}</span> total ·
      <span class="mono" id="stat-done">{n_done}</span> done ·
      <span class="mono" id="stat-todo">{n_todo}</span> todo ·
      <span class="mono" id="stat-canceled">{n_canceled}</span> canceled
    </div>
    <div class="progress-grid">
{render_progress(tasks)}
    </div>
    <div class="controls">
      <input type="search" id="search" placeholder="Search title or summary…" autocomplete="off">
      <div class="filter-chips">
{render_chips(tasks)}
      </div>
    </div>
  </header>
  <main class="board">
{columns}
  </main>
  <div class="modal-backdrop" id="modal" hidden>
    <div class="modal">
      <button class="modal-close" id="modal-close" aria-label="Close" title="Close (Esc)">×</button>
      <div class="md" id="modal-body"></div>
    </div>
  </div>
  <div class="toast" id="toast" hidden></div>
  <script>
{js}
  </script>
</body>
</html>
"""


# --------------------------------------------------------------------------
# Serve mode
# --------------------------------------------------------------------------

class DashboardHandler(BaseHTTPRequestHandler):
    """`GET /` renders the board fresh from the current `.md` files;
    `POST /status` writes a dragged card's new status back into its file."""

    def do_GET(self):
        if self.path.split("?", 1)[0] != "/":
            self.send_error(404)
            return
        try:
            body = render_html(load_tasks(), serve=True).encode("utf-8")
        except SystemExit as exc:
            self.send_error(500, "Task parsing failed", str(exc))
            return
        self._respond(200, "text/html; charset=utf-8", body)

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/status":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            number = int(payload["number"])
            status = payload["status"]
        except (ValueError, KeyError, TypeError) as exc:
            self.send_error(400, "Bad request", f"Expected JSON {{number, status}}: {exc}")
            return
        if status not in {key for key, _, _ in COLUMNS}:
            self.send_error(400, "Bad request", f"Unknown status: {status!r}")
            return

        matches = [p for p in TASKS_DIR.glob("[0-9]*.md") if task_number(p) == number]
        if not matches:
            self.send_error(404, "No such task", f"No {number:02d}-*.md in {TASKS_DIR}")
            return
        if len(matches) > 1:
            self.send_error(500, "Ambiguous task number", ", ".join(p.name for p in matches))
            return

        today = date.today().isoformat()
        try:
            mode, new_line = apply_status_change(matches[0], status, today)
        except ValueError as exc:
            self.send_error(500, "Status write failed", str(exc))
            return
        self._respond(200, "application/json", json.dumps(
            {"ok": True, "status": status,
             "date": today if status == "done" else None,
             "mode": mode, "line": new_line}
        ).encode("utf-8"))

    def _respond(self, code, content_type, body):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        sys.stderr.write(f"[serve] {format % args}\n")


def serve(port, open_browser):
    httpd = ThreadingHTTPServer(("127.0.0.1", port), DashboardHandler)
    url = f"http://127.0.0.1:{port}/"
    print(f"Serving dashboard at {url} — drag cards between columns to change "
          f"status. Ctrl-C to stop.")
    if open_browser:
        subprocess.run(["open", url], check=False)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        httpd.server_close()


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate the Template task dashboard HTML.")
    parser.add_argument("--no-open", action="store_true", help="Skip opening in browser")
    parser.add_argument("--out", default=str(TASKS_DIR / "dashboard.html"),
                        help="Output path (default: tasks/dashboard.html)")
    parser.add_argument("--serve", action="store_true",
                        help="Serve the dashboard on localhost with drag-and-drop "
                             "status writeback instead of writing the static file")
    parser.add_argument("--port", type=int, default=8765,
                        help="Port for --serve (default: 8765)")
    args = parser.parse_args(argv)

    if args.serve:
        serve(args.port, open_browser=not args.no_open)
        return

    tasks = load_tasks()
    document = render_html(tasks)

    out_path = Path(args.out)
    out_path.write_text(document, encoding="utf-8")

    n_total = len(tasks)
    n_done = sum(1 for t in tasks if t["status"] == "done")
    n_todo = sum(1 for t in tasks if t["status"] == "todo")
    n_canceled = sum(1 for t in tasks if t["status"] == "canceled")
    print(
        f"✓ Wrote {out_path} ({n_total} tasks: "
        f"{n_todo} todo, {n_done} done, {n_canceled} canceled)"
    )

    if not args.no_open:
        subprocess.run(["open", str(out_path)], check=False)


if __name__ == "__main__":
    main()

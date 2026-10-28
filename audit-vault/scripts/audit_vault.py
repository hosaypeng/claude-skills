#!/usr/bin/env python3
"""Read-only audit of the Obsidian vault. Never writes to the vault.

Usage: python3 -B -I audit_vault.py [full|tags|frontmatter|links|orphans|relevance]
The vault path comes from $VAULT (default ~/Documents/obsidian).
Runs on macOS system Python 3.9: standard library only.
"""
from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass, field
from typing import Callable, Optional

DEFAULT_VAULT = "~/Documents/obsidian"
SEV_ORDER = {"Critical": 0, "Warning": 1, "Cosmetic": 2}
TYPE_TAGS = {"journal", "index"}  # valid without a 40_indexes/ file of their own
ORIGINS = ("human", "ai")
TYPES = ("research", "reference", "personal", "book_summary", "workflow", "project")
STATUSES = ("active", "archived", "draft")
NOTE_FIELDS = ("origin", "tags", "description", "type", "status")
ARTICLE_FIELDS = ("origin", "title", "source", "author", "published", "created",
                  "description", "tags")
BOM = chr(0xFEFF)
KNOWLEDGE_TOP_LEVEL = {"index.md", "papers.md", "nak_muay.md"}
LONG_NOTE_LINES = 200
MIN_CONTENT_LINES = 3
# CLAUDE.md is a tool-mandated name and _index.md is the vault's index-file convention.
NAMING_EXEMPT = {"CLAUDE", "_index"}
NAME_RE = re.compile(
  r"^([a-z0-9]+|\d{4}-\d{2}-\d{2})(_([a-z0-9]+|\d{4}-\d{2}-\d{2}))*$")
# Templates hold placeholders; the archive is frozen history.
ARCHIVE = "60_archive/"
ORPHAN_SKIP = ("templates/", "40_indexes/", ARCHIVE)
EMPTY_SKIP = ("templates/", ARCHIVE)
EMPTY_VALUES = {"", '""', "''", "[]", "{}", "null", "Null", "NULL", "~"}

KEY_RE = re.compile(r"^([A-Za-z_][\w-]*)[ \t]*:[ \t]*(.*)$")
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
INLINE_CODE_RE = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")
LINK_RE = re.compile(r"!?\[\[([^\[\]]+?)\]\]")
WIKI_RE = re.compile(r"!?\[\[[^\[\]]*\]\]")
MD_TARGET_RE = re.compile(r"\]\([^)]*\)")
URL_RE = re.compile(r"(?:https?|ftp|file)://\S+")
BODY_TAG_RE = re.compile(r"(?:^|\s)#([A-Za-z_][\w/-]*)")
H1_RE = re.compile(r"^#\s+(.*\S)")


# --- Data model ---

@dataclass
class Finding:
  severity: str
  category: str
  where: str
  message: str


@dataclass
class FmField:
  line: int
  inline: str
  items: list = field(default_factory=list)  # (line, text) of "- x" items
  block: list = field(default_factory=list)  # other indented continuation lines


@dataclass
class TagRef:
  name: str
  quoted: bool
  hashed: bool  # written with a "#" prefix outside quotes
  line: int


@dataclass
class Note:
  rel: str
  lines: list
  masked: list  # same line count, code blanked out
  has_fm: bool
  fm: dict
  body_start: int


@dataclass
class LinkRef:
  src: str
  line: int
  raw: str
  target: str
  notes: list
  files: list
  in_fm: bool = False  # the link sits in the frontmatter (e.g. an author link)


@dataclass
class Vault:
  root: str
  notes: dict
  note_index: dict  # lowercase path suffix without .md -> [rel]
  file_index: dict  # lowercase path suffix with extension -> [rel] (non-md files)
  valid_tags: Optional[set]
  topic_tags: set
  load_errors: list
  links: Optional[list] = None


# --- Parsing: code masking, frontmatter, tags ---

def mask_code(lines: list) -> list:
  """Blank fenced code and inline code spans, keeping the line count."""
  out = []
  fence = None
  for line in lines:
    m = FENCE_RE.match(line)
    if fence is not None:
      closes = m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1] \
        and not m.group(2).strip()
      if closes:
        fence = None
      out.append("")
    elif m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
      fence = (m.group(1)[0], len(m.group(1)))
      out.append("")
    else:
      out.append(INLINE_CODE_RE.sub(lambda mm: " " * len(mm.group(0)), line))
  return out


def clean_scalar(raw: str) -> str:
  s = raw.strip()
  if s[:1] in ("'", '"'):
    return s
  return re.split(r"\s#", s, maxsplit=1)[0].strip()


def absorb_fm_line(fields: dict, cur: Optional[FmField], idx: int, line: str) -> Optional[FmField]:
  m = KEY_RE.match(line)
  if m:
    cur = FmField(idx + 1, clean_scalar(m.group(2)))
    fields[m.group(1)] = cur
    return cur
  s = line.strip()
  if cur is None or not s or s.startswith("#"):
    return cur
  if s == "-" or s.startswith("- "):
    cur.items.append((idx + 1, clean_scalar(s[1:])))
  else:
    cur.block.append(s)
  return cur


def parse_frontmatter(lines: list) -> tuple:
  """Return (has_frontmatter, fields, index of first body line)."""
  if not lines or lines[0].lstrip(BOM).rstrip() != "---":
    return False, {}, 0
  end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), -1)
  if end < 0:
    return False, {}, 0
  fields: dict = {}
  cur = None
  for i in range(1, end):
    cur = absorb_fm_line(fields, cur, i, lines[i])
  return True, fields, end + 1


def field_empty(f: FmField) -> bool:
  inline = f.inline
  has_inline = inline not in EMPTY_VALUES and not re.match(r"^[|>][+-]?$", inline)
  has_items = any(text.strip() not in EMPTY_VALUES for _, text in f.items)
  return not (has_inline or has_items or f.block)


def scalar(note: Note, key: str) -> str:
  f = note.fm.get(key)
  if f is None:
    return ""
  text = f.inline
  if re.match(r"^[|>][+-]?$", text) or not text:  # block scalar or list value
    text = " ".join(f.block) or next((t for _, t in f.items if t), "")
  return unquote(text)[0]


def unquote(s: str) -> tuple:
  s = s.strip()
  if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
    return s[1:-1].strip(), True
  return s, False


def flow_inner(f: FmField) -> Optional[str]:
  """Inner text of a `[...]` flow list, joined across lines; None if it never closes."""
  text = " ".join([f.inline] + f.block).rstrip()
  return text[1:-1] if text.endswith("]") else None


def frontmatter_tags(note: Note) -> list:
  """Return a TagRef for every tag in the frontmatter (empty items skipped)."""
  f = note.fm.get("tags")
  if f is None:
    return []
  raws = []
  if f.inline.startswith("["):
    inner = flow_inner(f)
    raws += [(f.line, p) for p in (inner.split(",") if inner is not None else [])]
  elif f.inline:
    raws += [(f.line, p) for p in re.split(r"[,\s]+", f.inline)]
  raws += list(f.items)
  tags = []
  for line, raw in raws:
    name, quoted = unquote(raw)
    hashed = not quoted and name.startswith("#")  # YAML reads "#..." as a comment
    name = name.lstrip("#").strip()
    if name:
      tags.append(TagRef(name, quoted, hashed, line))
  return tags


def unclosed_flow_line(note: Note) -> int:
  """Line of a `tags: [` flow list that never closes, else 0."""
  f = note.fm.get("tags")
  if f is not None and f.inline.startswith("[") and flow_inner(f) is None:
    return f.line
  return 0


def body_tag_hits(note: Note) -> list:
  """Return (line, tag) for inline #tags outside code, links and URLs."""
  hits = []
  for i in range(note.body_start, len(note.masked)):
    line = note.masked[i]
    if "#" not in line:
      continue
    for rx in (WIKI_RE, MD_TARGET_RE, URL_RE):
      line = rx.sub(" ", line)
    for m in BODY_TAG_RE.finditer(line):
      hits.append((i + 1, m.group(1).rstrip("/-")))
  return hits


# --- Loading ---

def read_note(path: str, rel: str) -> Note:
  with open(path, encoding="utf-8", errors="replace") as fh:
    lines = fh.read().split("\n")
  has_fm, fm, body_start = parse_frontmatter(lines)
  return Note(rel, lines, mask_code(lines), has_fm, fm, body_start)


def add_suffixes(index: dict, key: str, rel: str) -> None:
  parts = key.split("/")
  for i in range(len(parts)):
    index.setdefault("/".join(parts[i:]), []).append(rel)


def load_index_tags(root: str) -> tuple:
  """Return (valid tags, tags with a topic index), or (None, set()) without 40_indexes/."""
  folder = os.path.join(root, "40_indexes")
  if not os.path.isdir(folder):
    return None, set()
  stems = {n[:-3] for n in os.listdir(folder) if n.endswith(".md") and n != "_index.md"}
  return stems | TYPE_TAGS, stems


def load_vault(root: str) -> Vault:
  notes: dict = {}
  note_index: dict = {}
  file_index: dict = {}
  errors = []
  for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
    for name in sorted(n for n in filenames if not n.startswith(".")):
      path = os.path.join(dirpath, name)
      rel = os.path.relpath(path, root)
      if not name.lower().endswith(".md"):
        add_suffixes(file_index, rel.lower(), rel)
        continue
      try:
        notes[rel] = read_note(path, rel)
      except OSError as exc:
        errors.append(Finding("Critical", "UNREADABLE", rel, exc.strerror or "read failed"))
        continue
      add_suffixes(note_index, rel[:-3].lower(), rel)
  valid, topics = load_index_tags(root)
  return Vault(root, notes, note_index, file_index, valid, topics, errors)


# --- Links ---

def resolve_target(v: Vault, target: str) -> tuple:
  t = target.strip().lstrip("/").lower()
  key = t[:-3] if t.endswith(".md") else t
  return v.note_index.get(key, []), v.file_index.get(t, [])


def extract_links(v: Vault, note: Note) -> list:
  refs = []
  for i, line in enumerate(note.masked):
    for m in LINK_RE.finditer(line):
      target = m.group(1).split("|", 1)[0].rstrip("\\").split("#", 1)[0].strip()
      if not target:
        continue  # [[#heading]] and [[#^block]] point at the same note
      notes, files = resolve_target(v, target)
      in_fm = note.has_fm and i < note.body_start
      refs.append(LinkRef(note.rel, i + 1, m.group(1), target, notes, files, in_fm))
  return refs


def all_links(v: Vault) -> list:
  if v.links is None:
    v.links = [r for n in v.notes.values() for r in extract_links(v, n)]
  return v.links


def check_links(v: Vault) -> list:
  out = []
  for ref in all_links(v):
    if ref.notes or ref.files:
      continue
    msg = f"-> [[{ref.raw}]]"
    base = ref.target.rsplit("/", 1)[-1].lower()
    if "/" in ref.target and v.note_index.get(base):
      msg += f" (no file at that path; same name exists at {', '.join(v.note_index[base])})"
    severity = "Warning" if ref.in_fm else "Critical"  # an unresolved author link is metadata
    out.append(Finding(severity, "BROKEN", f"{ref.src}:{ref.line}", msg))
  return out


def check_duplicates(v: Vault) -> list:
  stems: dict = {}
  for rel in v.notes:
    stems.setdefault(os.path.basename(rel)[:-3].lower(), []).append(rel)
  return [
    Finding("Warning", "DUPLICATE", stem, "same basename: " + ", ".join(sorted(rels)))
    for stem, rels in sorted(stems.items()) if len(rels) > 1
  ]


# --- Tags ---

def check_fm_tags(v: Vault) -> list:
  if v.valid_tags is None:
    return [Finding("Warning", "MISSING-DIR", "40_indexes/",
                    "folder not found; tag validity not checked")]
  out = []
  for rel, note in sorted(v.notes.items()):
    out += note_tag_findings(v, note)
  return out


def note_tag_findings(v: Vault, note: Note) -> list:
  """Invalid, malformed and quoted frontmatter tags of one note (archive: Cosmetic)."""
  rel = note.rel
  def sev(base: str) -> str:
    return "Cosmetic" if rel.startswith(ARCHIVE) else base

  tags = frontmatter_tags(note)
  out = []
  line = unclosed_flow_line(note)
  if line:
    out.append(Finding(sev("Warning"), "MALFORMED", f"{rel}:{line}",
                       "tags flow list is never closed (YAML reads ' #' as a comment)"))
  hashed = [f"#{t.name}" for t in tags if t.hashed]
  if hashed:
    out.append(Finding(sev("Warning"), "MALFORMED", f"{rel}:{note.fm['tags'].line}",
                       "Tag(s) " + ", ".join(hashed) + " start with '#'; YAML reads them as comments"))
  for t in tags:
    if not t.hashed and t.name not in v.valid_tags:
      out.append(Finding(sev("Critical"), "INVALID", f"{rel}:{t.line}",
                         f"Tag '{t.name}' has no file in 40_indexes/"))
  quoted = [t.name for t in tags if t.quoted]
  if quoted:
    out.append(Finding("Cosmetic", "QUOTED", f"{rel}:{note.fm['tags'].line}",
                       "Quoted tag(s) " + ", ".join(quoted) + " (remove quotes)"))
  return out


def check_body_tags(v: Vault) -> list:
  if v.valid_tags is None:
    return []
  out = []
  for rel, note in sorted(v.notes.items()):
    hits = [(ln, t) for ln, t in body_tag_hits(note) if t not in v.valid_tags]
    # Clipped articles carry the source's own tags; the archive is frozen history.
    reason = "Clipped article" if "source" in note.fm else \
      "Archived note" if rel.startswith(ARCHIVE) else ""
    if reason and hits:
      listing = ", ".join(f"#{t} (L{ln})" for ln, t in hits)
      out.append(Finding("Cosmetic", "BODYTAG", rel, f"{reason}: {listing}"))
      continue
    out += [Finding("Warning", "BODYTAG", f"{rel}:{ln}", f"#{t} has no file in 40_indexes/")
            for ln, t in hits]
  return out


# --- Frontmatter schema ---

def is_article(note: Note) -> bool:
  return "source" in note.fm and scalar(note, "type") != "reference" \
    and scalar(note, "origin") != "ai"


def invalid_values(note: Note) -> list:
  out = []
  for key, allowed in (("origin", ORIGINS), ("type", TYPES), ("status", STATUSES)):
    f = note.fm.get(key)
    if f is None or field_empty(f):
      continue
    val = scalar(note, key)
    if val not in allowed:
      out.append(Finding("Warning", "INVALID", f"{note.rel}:{f.line}",
                         f"{key}: '{val}' (expected {'|'.join(allowed)})"))
  return out


def missing_fields(note: Note, required: tuple) -> Optional[Finding]:
  absent = [k for k in required if k not in note.fm]
  empty = [k for k in required if k in note.fm and field_empty(note.fm[k])]
  if not absent and not empty:
    return None
  parts = []
  if absent:
    parts.append("Missing fields: " + ", ".join(absent))
  if empty:
    parts.append("Empty fields: " + ", ".join(empty))
  return Finding("Warning", "MISSING", note.rel, "; ".join(parts))


def summary_finding(note: Note) -> Optional[Finding]:
  count = len(note.lines) - (1 if note.lines and note.lines[-1] == "" else 0)
  if count <= LONG_NOTE_LINES or "source" in note.fm or scalar(note, "origin") != "human":
    return None
  f = note.fm.get("summary")
  if f is not None and not field_empty(f):
    return None
  return Finding("Cosmetic", "MISSING", note.rel, f"{count} lines but no summary field")


def schema_findings(note: Note) -> list:
  if not note.has_fm:
    return [Finding("Critical", "MISSING", note.rel, "No frontmatter found")]
  required = ARTICLE_FIELDS if is_article(note) else NOTE_FIELDS
  found = [missing_fields(note, required), summary_finding(note)]
  return [f for f in found if f] + invalid_values(note)


def check_schema(v: Vault) -> list:
  if not os.path.isdir(os.path.join(v.root, "30_knowledge")):
    return [Finding("Warning", "MISSING-DIR", "30_knowledge/",
                    "folder not found; schema not checked")]
  out = []
  for rel, note in sorted(v.notes.items()):
    if rel.startswith("30_knowledge/") and os.path.basename(rel) != "_index.md":
      out += schema_findings(note)
  return out


def check_inbox(v: Vault) -> list:
  if not os.path.isdir(os.path.join(v.root, "00_inbox")):
    return [Finding("Warning", "MISSING-DIR", "00_inbox/", "folder not found; inbox not checked")]
  out = []
  for rel, note in sorted(v.notes.items()):
    if os.path.dirname(rel) != "00_inbox" or os.path.basename(rel) == "_index.md":
      continue
    if not note.has_fm:
      out.append(Finding("Critical", "MISSING", rel, "No frontmatter found"))
      continue
    found = missing_fields(note, ("tags",))
    if found:
      out.append(found)
  return out


# --- Orphans, empty files, naming ---

def has_topic_tag(v: Vault, note: Note) -> bool:
  names = {t.name for t in frontmatter_tags(note) if not t.hashed}
  names |= {t for _, t in body_tag_hits(note)}
  return bool(names & v.topic_tags)


def check_orphans(v: Vault) -> list:
  inbound = set()
  for ref in all_links(v):
    inbound |= {rel for rel in ref.notes if rel != ref.src}
  out = []
  for rel, note in sorted(v.notes.items()):
    if rel.startswith(ORPHAN_SKIP) or os.path.basename(rel) in ("_index.md", "CLAUDE.md"):
      continue
    if rel not in inbound and not has_topic_tag(v, note):
      out.append(Finding("Warning", "ORPHAN", rel, "No inbound wikilink and no topic-index tag"))
  return out


def check_empty(v: Vault) -> list:
  out = []
  for rel, note in sorted(v.notes.items()):
    if rel.startswith(EMPTY_SKIP) or os.path.basename(rel) == "_index.md":
      continue
    count = sum(1 for line in note.lines[note.body_start:] if line.strip())
    if count < MIN_CONTENT_LINES:
      out.append(Finding("Cosmetic", "EMPTY", rel, f"{count} content line(s)"))
  return out


def check_naming(v: Vault) -> list:
  out = []
  for rel in sorted(v.notes):
    stem = os.path.basename(rel)[:-3]
    if stem not in NAMING_EXEMPT and not NAME_RE.match(stem):
      out.append(Finding("Warning", "NAMING", rel, f"'{stem}' is not snake_case"))
  return out


def check_toplevel(v: Vault) -> list:
  return [
    Finding("Warning", "TOPLEVEL", rel, "Note sits directly in 30_knowledge/; move to a topic folder")
    for rel in sorted(v.notes)
    if os.path.dirname(rel) == "30_knowledge" and os.path.basename(rel) not in KNOWLEDGE_TOP_LEVEL
  ]


# --- Relevance listing ---

def squash(text: str, limit: int) -> str:
  """One-line field: collapse whitespace, drop the column separator, truncate."""
  text = re.sub(r"\s+", " ", text.replace("|", "/")).strip()
  return text if len(text) <= limit else text[:max(limit - 3, 0)] + "..."


def first_h1(note: Note) -> str:
  for line in note.masked[note.body_start:]:
    m = H1_RE.match(line)
    if m:
      return m.group(1)
  return "-"


def relevance_line(note: Note) -> str:
  tags = ",".join(t.name for t in frontmatter_tags(note)) or "-"
  h1 = squash(first_h1(note), 60)
  budget = max(200 - len(note.rel) - len(tags) - len(h1) - 9, 30)
  desc = squash(scalar(note, "description") or "-", budget)
  return f"{note.rel} | {tags} | {desc} | {h1}"


def print_relevance(v: Vault) -> None:
  for rel, note in sorted(v.notes.items()):
    if rel.startswith("30_knowledge/"):
      print(relevance_line(note))


# --- Runner ---

CheckFn = Callable[[Vault], list]
SECTIONS = [
  ("tags", "Tag Validity Check", [
    ("fm_tags", "Frontmatter tags", check_fm_tags),
    ("body_tags", "Body #tags", check_body_tags)]),
  ("frontmatter", "Frontmatter Compliance Check", [
    ("schema", "30_knowledge/ schema", check_schema),
    ("inbox", "00_inbox/ tags", check_inbox)]),
  ("links", "Broken Wikilink Check", [
    ("links", "Wikilinks", check_links),
    ("duplicates", "Duplicate basenames", check_duplicates)]),
  ("orphans", "Orphans, Empty Files & Naming", [
    ("orphans", "Orphan notes", check_orphans),
    ("empty", "Near-empty files", check_empty),
    ("naming", "File naming", check_naming),
    ("toplevel", "30_knowledge/ top level", check_toplevel)]),
]
MODES = [s[0] for s in SECTIONS] + ["full", "relevance"]


def run_check(v: Vault, key: str, title: str, fn: CheckFn, totals: dict) -> None:
  print(f"--- {title} ---")
  try:
    findings = sorted(fn(v), key=lambda f: (SEV_ORDER[f.severity], f.where, f.message))
  except Exception as exc:  # one broken check must not stop the others
    print(f"[ERROR] {key}: {type(exc).__name__}: {exc}")
    totals["ERROR"] += 1
    print()
    return
  for f in findings:
    print(f"[{f.severity.upper()}] {f.category} {f.where}: {f.message}")
    totals[f.severity] += 1
  print(f"{len(findings)} finding(s)." if findings else "No findings.")
  print()


def run_sections(v: Vault, mode: str) -> dict:
  totals = {"Critical": 0, "Warning": 0, "Cosmetic": 0, "ERROR": 0}
  for finding in v.load_errors:
    print(f"[ERROR] load: {finding.where}: {finding.message}")
    totals["ERROR"] += 1
  for name, title, checks in SECTIONS:
    if mode not in ("full", name):
      continue
    print(f"=== {title} ===\n")
    for key, sub, fn in checks:
      run_check(v, key, sub, fn, totals)
  return totals


def main(argv: list) -> int:
  mode = argv[0] if argv else "full"
  if mode not in MODES:
    print(f"usage: audit_vault.py [{'|'.join(MODES)}]", file=sys.stderr)
    return 2
  root = os.path.expanduser(os.environ.get("VAULT") or DEFAULT_VAULT)
  if not os.path.isdir(root):
    print(f"Vault not found: {root} (set VAULT)", file=sys.stderr)
    return 2
  vault = load_vault(root)
  if mode == "relevance":
    print_relevance(vault)
    return 0
  if mode == "full":
    print("=========================================\n  Obsidian Vault Audit - Full Report\n"
          "=========================================\n")
  totals = run_sections(vault, mode)
  print(f"Summary: {totals['Critical']} critical, {totals['Warning']} warning, "
        f"{totals['Cosmetic']} cosmetic, {totals['ERROR']} error(s).")
  return 1 if totals["ERROR"] else 0


if __name__ == "__main__":
  try:
    code = main(sys.argv[1:])
    sys.stdout.flush()  # flush here, or the broken pipe surfaces after this handler
  except BrokenPipeError:
    # Output was piped to something that closed early (e.g. head): point stdout
    # at /dev/null so the flush at interpreter exit stays quiet.
    os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
    code = 0
  sys.exit(code)

#!/usr/bin/env python3
"""Find everything that still points at vault paths that moved or were deleted.

Strictly read-only. Git is used through plumbing only (diff-index, ls-files,
ls-tree, cat-file, hash-object, rev-parse, rev-list, log), always with
--no-optional-locks. The porcelain `git diff` can rewrite .git/index when stat
info is stale, even with optional locks off, so it is never called.
Standard library only; runs on macOS system Python 3.9 (run as `python3 -B -I`).

Usage:
  find_moved_refs.py [--vault DIR] [--ref REV | --since DATE]
                     [--move OLD NEW]... [--all]

What counts as "moved": the net change from the base commit to the working
tree, so committed, staged and unstaged moves are all seen. The base is the last
commit older than 2 days unless --ref or --since says otherwise (the vault
auto-commits, so a move is usually buried under later commits). A plain `mv`
shows up in git as a deleted file plus an untracked one; those are paired by
content hash, then identical basename, then text similarity. Exact-path
.gitignore entries that no longer exist on disk are reported too, because git
cannot see moves of ignored files.
"""
from __future__ import annotations

import argparse
import ast
import bisect
import difflib
import glob
import os
import re
import subprocess
import sys
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

HOME = Path.home()
CANON_VAULT = HOME / "Documents" / "obsidian"
INDEXER = HOME / "Code" / "vault-rag" / "index_vault.py"
DEFAULT_SINCE = "2 days ago"
SIMILARITY = 0.5
SIMILARITY_PAIR_LIMIT = 4000
SIMILARITY_MAX_BYTES = 300_000
LIST_LIMIT = 60
MAX_SOURCE_BYTES = 1_000_000
ICLOUD_MARK = "iCloud~md~obsidian"

# Files that hard-code vault paths. Home-relative; expanded at runtime.
SOURCE_PATTERNS = [
  "~/AGENTS.md",
  "~/.claude/AGENTS.md",
  "~/.codex/AGENTS.md",
  "~/.claude/CLAUDE.md",
  "~/.claude/hooks/*",
  "~/.claude/settings.json",
  "~/.claude/skills/*/SKILL.md",
  "~/.claude/skills/*/scripts/*",
  "~/Library/LaunchAgents/*.plist",
  "~/Code/agent-config/bin/*",
  "~/Code/vault-rag/*.py",
  "~/Code/vault-rag/README.md",
  "~/Code/macos-recovery-setup/RECOVERY.md",
  "~/.claude/projects/%s/memory/*.md" % str(CANON_VAULT).replace("/", "-"),
]

# A path component separator, also as it appears split across Python/shell
# string literals: "a" / "b", "a", "b", "a/" + "b".
SEP = r"""(?:/(?:["']\s*\+\s*["'])?|["']\s*[/,+]\s*["'])"""
RIGHT = r"(?![\w\-]|\.\w)"
RIGHT_NOTE = r"(?![\w\-/]|\.\w)"
NAME_LEFT = r"(?<![\w\-.])"
MULTI_LEFT = r"(?<![\w\-.])"  # a multi-part path may follow any "/" ($VAULT_DIR/a/b)
_VAULT_ROOTS = (
  r"(?<=%s/)|(?<=VAULT/)|(?<=VAULT_DIR/)|(?<=VAULT\}/)|(?<=VAULT_DIR\}/)|(?<=vault/)"
  % re.escape(CANON_VAULT.name)
)
VAULT_PREFIX = "(?:" + _VAULT_ROOTS + ")"  # right after the vault root
VAULT_LEFT = r"(?:(?<![\w\-./])|" + _VAULT_ROOTS + ")"
HOME_LEFT = (
  r"(?:(?<![\w\-./])|(?<=~/)|(?<=HOME/)|(?<=HOME\}/)|(?<=%s/))"
  % re.escape(str(HOME))
)
INLINE_CODE = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")
WIKILINK = re.compile(r"(!?)\[\[([^\]\n]+?)\]\]")


class SweepError(Exception):
  """A real failure (bad repo, bad revision): reported on stderr, exit 2."""


@dataclass
class Move:
  old: str
  new: Optional[str]
  how: str
  private: bool = False
  absolute: bool = False


@dataclass
class DirMove:
  old: str
  new: Optional[str]
  total: int
  to_new: int


@dataclass
class Needle:
  kind: str  # file | dir | name | link
  old: str
  new: Optional[str]
  regex: "re.Pattern[str]"
  hint: str
  unknown: bool = False  # gone from its path, destination not known


LinkRef = Tuple[str, int, str, str, str]  # file, line, "!" or "", target, rest


@dataclass
class Source:
  label: str
  aliases: List[str]
  text: str


@dataclass
class Report:
  header: List[str] = field(default_factory=list)
  moved: List[str] = field(default_factory=list)
  external: List[str] = field(default_factory=list)
  links: List[str] = field(default_factory=list)
  dups: List[str] = field(default_factory=list)
  coverage: List[str] = field(default_factory=list)
  standing: List[str] = field(default_factory=list)
  notes: List[str] = field(default_factory=list)


# ---------------------------------------------------------------- small helpers


def nfc(text: str) -> str:
  """macOS may hand back decomposed names; compare everything composed."""
  return unicodedata.normalize("NFC", text)


def tilde(path: str) -> str:
  home = str(HOME)
  return "~" + path[len(home):] if path.startswith(home + "/") else path


def visible(path: str) -> bool:
  return not any(p.startswith(".") for p in path.split("/"))


def link_path(rel: str) -> str:
  """Path as written in a wikilink: no .md suffix."""
  return rel[:-3] if rel.lower().endswith(".md") else rel


def link_name(rel: str) -> str:
  return link_path(rel).split("/")[-1]


def top_dir(rel: str) -> str:
  return rel.split("/")[0]


# ------------------------------------------------------------------------ git


def git(vault: Path, args: List[str], stdin: Optional[bytes] = None) -> bytes:
  cmd = ["git", "--no-optional-locks", "-C", str(vault), "-c", "core.fsmonitor=false",
         "-c", "diff.renameLimit=5000"] + args
  env = dict(os.environ)
  env["GIT_OPTIONAL_LOCKS"] = "0"  # older gits without --no-optional-locks
  try:
    proc = subprocess.run(cmd, input=stdin, capture_output=True, env=env,
                          check=False)
  except OSError as err:
    raise SweepError("cannot run git: %s" % err)
  if proc.returncode != 0:
    msg = proc.stderr.decode("utf-8", "replace").strip()
    raise SweepError("git %s failed: %s" % (" ".join(args[:2]), msg))
  return proc.stdout


def git_text(vault: Path, args: List[str]) -> str:
  return git(vault, args).decode("utf-8", "replace")


def git_z(vault: Path, args: List[str]) -> List[str]:
  return [p for p in git_text(vault, args).split("\0") if p]


def check_repo(vault: Path) -> None:
  if not vault.is_dir():
    raise SweepError("vault not found: %s" % vault)
  top = git_text(vault, ["rev-parse", "--show-toplevel"]).strip()
  if os.path.realpath(top) != os.path.realpath(str(vault)):
    raise SweepError("%s is not a git repository root (root: %s)" % (vault, top))


def resolve_base(vault: Path, ref: Optional[str], since: Optional[str]) -> Tuple[str, str]:
  """Return (commit sha, how the base was chosen)."""
  if ref:
    if ref.startswith("-"):
      raise SweepError("bad revision: %s" % ref)
    try:
      sha = git_text(vault, ["rev-parse", "--verify", "--quiet", ref + "^{commit}"])
    except SweepError:
      sha = ""
    if not sha.strip():
      raise SweepError("unknown revision %r (pass a commit, or --ref HEAD)" % ref)
    return sha.strip(), "--ref %s" % ref
  when = since or DEFAULT_SINCE
  sha = git_text(vault, ["rev-list", "-1", "--before=" + when, "HEAD"]).strip()
  if sha:
    return sha, "last commit before '%s'%s" % (when, "" if since else " (default)")
  roots = git_text(vault, ["rev-list", "--max-parents=0", "HEAD"]).split()
  if not roots:
    raise SweepError("repository has no commits")
  return roots[0], "root commit (nothing is older than '%s')" % when


def describe_range(vault: Path, base: str) -> str:
  """'abc1234..def5678, 12 commit(s), 2026-10-24..2026-10-28'."""
  head = git_text(vault, ["rev-parse", "HEAD"]).strip()
  count = git_text(vault, ["rev-list", "--count", base + "..HEAD"]).strip()
  first = git_text(vault, ["log", "-1", "--format=%cs", base]).strip()
  last = git_text(vault, ["log", "-1", "--format=%cs", head]).strip()
  return "%s..%s, %s commit(s), %s..%s" % (base[:7], head[:7], count, first, last)


def diff_changes(vault: Path, base: str) -> Tuple[List[Tuple[str, str]], List[str], List[str]]:
  """Net change from base to the working tree: (renames, deleted, added).

  Plumbing on purpose: unlike `git diff` it never refreshes or writes the index.
  A file with stale stat info can show up as modified; only R, D and A matter here.
  """
  raw = git_z(vault, ["diff-index", "-M", "--name-status", "-z", base, "--"])
  renames: List[Tuple[str, str]] = []
  deleted: List[str] = []
  added: List[str] = []
  i = 0
  while i < len(raw):
    code = raw[i][0]
    width = 3 if code in "RC" else 2
    chunk = raw[i:i + width]
    i += width
    if len(chunk) < width:
      break
    if code == "R":
      renames.append((chunk[1], chunk[2]))
    elif code == "C":
      added.append(chunk[2])
    elif code == "D":
      deleted.append(chunk[1])
    elif code == "A":
      added.append(chunk[1])
  return renames, deleted, added


def tree_blobs(vault: Path, rev: str) -> Dict[str, str]:
  out: Dict[str, str] = {}
  for entry in git_z(vault, ["ls-tree", "-r", "-z", rev]):
    meta, _, path = entry.partition("\t")
    fields = meta.split()
    if len(fields) == 3:
      out[path] = fields[2]
  return out


def hash_files(vault: Path, paths: List[str]) -> Dict[str, str]:
  """Blob ids of working-tree files, without writing anything to the repo."""
  safe = [p for p in paths if "\n" not in p and (vault / p).is_file()]
  if not safe:
    return {}
  payload = ("\n".join(safe) + "\n").encode("utf-8")
  out = git_text_in(vault, ["hash-object", "--stdin-paths"], payload).split("\n")
  return dict(zip(safe, out))


def git_text_in(vault: Path, args: List[str], payload: bytes) -> str:
  return git(vault, args, stdin=payload).decode("utf-8", "replace")


def ignored_exact(vault: Path) -> List[str]:
  """Exact-path .gitignore entries (private files); git cannot see them move."""
  try:
    lines = (vault / ".gitignore").read_text(encoding="utf-8").splitlines()
  except (OSError, UnicodeDecodeError):
    return []
  out: List[str] = []
  for raw in lines:
    entry = raw.strip()
    if not entry or entry[0] in "#!" or entry.endswith("/"):
      continue
    entry = entry.lstrip("/")
    if "/" in entry and visible(entry) and not any(c in entry for c in "*?[\\"):
      out.append(entry)
  return out


# ------------------------------------------------------------- move detection


def pair_by_content(olds: Dict[str, Set[str]], news: List[str],
                    hashes: Dict[str, str]) -> Tuple[List[Move], List[str], Set[str]]:
  """Pair deleted files with new files that have the same blob id."""
  by_hash: Dict[str, List[str]] = defaultdict(list)
  for path in news:
    by_hash[hashes.get(path, "")].append(path)
  free = set(news)
  moves: List[Move] = []
  rest: List[str] = []
  for old in sorted(olds):
    cands = list(dict.fromkeys(p for h in olds[old] for p in by_hash.get(h, []) if p in free))
    same = [p for p in cands if os.path.basename(p) == os.path.basename(old)]
    pick = same[0] if same else (cands[0] if len(cands) == 1 else None)
    if pick is None:
      rest.append(old)
      continue
    moves.append(Move(old, pick, "content match"))
    free.discard(pick)
  return moves, rest, free


def pair_by_basename(rest: List[str], free: Set[str]) -> Tuple[List[Move], List[str]]:
  """Pair what is left when exactly one old and one new file share a name."""
  old_by: Dict[str, List[str]] = defaultdict(list)
  new_by: Dict[str, List[str]] = defaultdict(list)
  for path in rest:
    old_by[os.path.basename(path).lower()].append(path)
  for path in sorted(free):
    new_by[os.path.basename(path).lower()].append(path)
  moves: List[Move] = []
  gone: List[str] = []
  for name, olds in sorted(old_by.items()):
    if len(olds) == 1 and len(new_by.get(name, [])) == 1:
      moves.append(Move(olds[0], new_by[name][0], "basename match"))
    else:
      gone.extend(olds)
  return moves, gone


def blob_text(vault: Path, sha: str) -> str:
  try:
    return git(vault, ["cat-file", "blob", sha]).decode("utf-8", "replace")
  except SweepError:
    return ""


def file_text(vault: Path, rel: str) -> str:
  path = vault / rel
  try:
    if path.stat().st_size > SIMILARITY_MAX_BYTES:
      return ""
    return path.read_text(encoding="utf-8", errors="replace")
  except OSError:
    return ""


def line_ratio(a: List[str], b: List[str]) -> float:
  matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
  if matcher.real_quick_ratio() < SIMILARITY or matcher.quick_ratio() < SIMILARITY:
    return 0.0
  return matcher.ratio()


def pair_by_similarity(vault: Path, gone: List[str], free: Set[str],
                       blobs: Dict[str, str]) -> Tuple[List[Move], List[str]]:
  """Last resort: pair a deleted file with a new one of similar text (mv + edit)."""
  olds = [p for p in gone if blobs.get(p)]
  news = sorted(free)
  if not olds or not news or len(olds) * len(news) > SIMILARITY_PAIR_LIMIT:
    return [], gone
  new_lines = {p: file_text(vault, p).splitlines() for p in news}
  scored: List[Tuple[float, str, str]] = []
  for old in olds:
    old_lines = blob_text(vault, blobs[old]).splitlines()
    ext = os.path.splitext(old)[1].lower()
    for new in news:
      if old_lines and new_lines[new] and os.path.splitext(new)[1].lower() == ext:
        ratio = line_ratio(old_lines, new_lines[new])
        if ratio >= SIMILARITY:
          scored.append((ratio, old, new))
  moves: List[Move] = []
  used_old: Set[str] = set()
  used_new: Set[str] = set()
  for ratio, old, new in sorted(scored, key=lambda t: (-t[0], t[1], t[2])):
    if old not in used_old and new not in used_new:
      used_old.add(old)
      used_new.add(new)
      moves.append(Move(old, new, "similar content, %d%%" % int(ratio * 100)))
  return moves, [p for p in gone if p not in used_old]


def pair_leftovers(vault: Path, olds: Dict[str, Set[str]], news: List[str],
                   blobs: Dict[str, str], notes: List[str]) -> Tuple[List[Move], List[str]]:
  """Pair deleted files with new ones: content hash, then basename, then similarity."""
  want_hash = bool(news) and any(olds.values())
  hashes = hash_files(vault, news) if want_hash else {}
  if want_hash and not hashes:
    notes.append("no content hashes available; paired by basename and similarity only")
  by_content, rest, free = pair_by_content(olds, news, hashes)
  by_name, gone = pair_by_basename(rest, free)
  free = free - {m.new for m in by_name}
  by_text, gone = pair_by_similarity(vault, gone, free, blobs)
  return by_content + by_name + by_text, gone


def detect_moves(vault: Path, base: str, notes: List[str]) -> List[Move]:
  renames, deleted, added = diff_changes(vault, base)
  moves = [Move(o, n, "git rename") for o, n in renames if visible(o) or visible(n)]
  taken = {m.new for m in moves}
  head_blobs = tree_blobs(vault, "HEAD")
  base_blobs = tree_blobs(vault, base)
  olds: Dict[str, Set[str]] = {}
  for path in deleted:
    if visible(path):
      olds[path] = {b for b in (base_blobs.get(path), head_blobs.get(path)) if b}
  ignored = set(ignored_exact(vault))
  renamed_old = {o for o, _ in renames}
  for path in sorted(ignored - set(olds) - renamed_old):
    if not (vault / path).exists():
      olds[path] = set()
  untracked = git_z(vault, ["ls-files", "--others", "--exclude-standard", "-z"])
  news = sorted({p for p in list(added) + untracked if visible(p)} - taken)
  blobs = {p: head_blobs.get(p) or base_blobs.get(p) or "" for p in olds}
  paired, gone = pair_leftovers(vault, olds, news, blobs, notes)
  moves += paired
  for old in gone:
    moves.append(Move(old, None, "deleted" if olds[old] else "gitignored path missing"))
  for m in moves:
    m.private = m.old in ignored
    m.old = nfc(m.old)
    m.new = nfc(m.new) if m.new else None
  return sorted(moves, key=lambda m: m.old)


def manual_moves(vault: Path, pairs: List[List[str]]) -> Tuple[List[Move], List[DirMove]]:
  """--move OLD NEW: moves git cannot see (ignored files) or a relocated root."""
  moves: List[Move] = []
  dirs: List[DirMove] = []
  for old, new in pairs:
    dest: Optional[str] = None if new == "-" else new
    if old.startswith(("/", "~")):
      expanded = os.path.expanduser(old).rstrip("/")
      target = os.path.expanduser(dest).rstrip("/") if dest else None
      moves.append(Move(expanded, target, "manual (absolute)", absolute=True))
      continue
    old = nfc(old.strip("/"))
    dest = nfc(dest.strip("/")) if dest else None
    if dest and (vault / dest).is_dir():
      files = sorted(str(p.relative_to(vault / dest)) for p in (vault / dest).rglob("*")
                     if p.is_file() and visible(str(p.relative_to(vault / dest))))
      moves += [Move(old + "/" + f, dest + "/" + f, "manual (dir)") for f in files]
      dirs.append(DirMove(old, dest, len(files), len(files)))
    else:
      moves.append(Move(old, dest, "manual"))
  return moves, dirs


# --------------------------------------------------------- directory renames


def dir_is_empty(path: Path) -> bool:
  if not path.is_dir():
    return True
  for _root, _dirs, files in os.walk(path):
    if any(f != ".DS_Store" for f in files):
      return False
  return True


def vacated_ancestor(vault: Path, rel: str, cache: Dict[str, bool]) -> Optional[str]:
  """Topmost ancestor directory of rel that no longer holds any file."""
  parts = rel.split("/")
  for k in range(1, len(parts)):
    d = "/".join(parts[:k])
    if d not in cache:
      cache[d] = dir_is_empty(vault / d)
    if cache[d]:
      return d
  return None


def dest_dir(m: Move, top: str) -> Optional[str]:
  """Where the directory `top` went, judged from one moved file."""
  if m.new is None:
    return None
  tail = m.old[len(top) + 1:]
  if m.new.endswith("/" + tail):
    return m.new[:-(len(tail) + 1)]
  return None


def derive_dir_moves(vault: Path, moves: List[Move]) -> List[DirMove]:
  votes: Dict[str, Counter] = defaultdict(Counter)
  cache: Dict[str, bool] = {}
  for m in moves:
    if m.absolute or m.how.startswith("manual"):
      continue
    top = vacated_ancestor(vault, m.old, cache)
    if top is not None:
      votes[top][dest_dir(m, top)] += 1
  out: List[DirMove] = []
  for d, counter in sorted(votes.items()):
    dests = [(c, n) for n, c in counter.items() if n is not None]
    best = max(dests) if dests else None
    out.append(DirMove(d, best[1] if best else None, sum(counter.values()),
                       best[0] if best else 0))
  return out


def covered_by_dirs(m: Move, dirs: List[DirMove]) -> bool:
  for d in dirs:
    if d.new and m.new and m.old.startswith(d.old + "/"):
      if m.new == d.new + m.old[len(d.old):]:
        return True
  return False


# ------------------------------------------------------------------- needles


def comp_regex(comps: List[str], left: str, optional_md: bool = False) -> "re.Pattern[str]":
  body = SEP.join(re.escape(c) for c in comps)
  if optional_md:  # `a/b` without .md must not be the start of a longer path `a/b/c`
    return re.compile(left + body + r"(?:\.md)?" + RIGHT_NOTE)
  return re.compile(left + body + RIGHT)


def one_part_dir_regex(name: str) -> "re.Pattern[str]":
  """A one-word folder (`templates`) also names things in prose: need a path context."""
  n = re.escape(name)
  return re.compile(VAULT_PREFIX + n + RIGHT                  # after the vault root
                    + r"|(?<![\w\-./])" + n + "/"             # `name/`
                    + r"|(?<=[\"'`])" + n + r"(?=[\"'`])")     # quoted: "name"


def path_needle(kind: str, old: str, new: Optional[str]) -> Needle:
  """Needle for a vault-relative file or directory path."""
  comps = old.split("/")
  if kind == "dir" and len(comps) == 1:
    return Needle(kind, old, new, one_part_dir_regex(comps[0]), comps[0].lower())
  is_md = kind == "file" and len(comps) > 1 and old.lower().endswith(".md")
  if is_md:
    comps[-1] = comps[-1][:-3]
  left = MULTI_LEFT if len(comps) > 1 else VAULT_LEFT
  return Needle(kind, old, new, comp_regex(comps, left, is_md), comps[-1].lower())


def abs_needle(m: Move) -> Needle:
  """Needle for an absolute path (e.g. a relocated vault root)."""
  home = str(HOME)
  if m.old.startswith(home + "/"):
    comps = m.old[len(home) + 1:].split("/")
    return Needle("file", m.old, m.new, comp_regex(comps, HOME_LEFT), comps[-1].lower())
  regex = re.compile(NAME_LEFT + re.escape(m.old) + RIGHT)
  return Needle("file", m.old, m.new, regex, os.path.basename(m.old).lower())


def name_needle(m: Move) -> Needle:
  base = os.path.basename(m.old)
  regex = re.compile(NAME_LEFT + re.escape(base) + RIGHT)
  new = os.path.basename(m.new) if m.new else None
  return Needle("name", base, new, regex, base.lower())


def link_needle(m: Move) -> Needle:
  name = link_name(m.old)
  regex = re.compile(
    r"\[\[(?:[^\]|#^\n]*/)?" + re.escape(name) + r"(?:\.md)?(?:[#|^\\][^\]\n]*)?\]\]",
    re.IGNORECASE)
  new = link_name(m.new) if m.new else None
  return Needle("link", name, new, regex, name.lower())


def build_needles(moves: List[Move], dirs: List[DirMove],
                  filenames: Set[str]) -> List[Needle]:
  needles: List[Needle] = []
  for m in moves:
    if m.absolute:
      needles.append(abs_needle(m))
      continue
    made = [path_needle("file", m.old, m.new)]
    base = os.path.basename(m.old)
    renamed = m.new is None or os.path.basename(m.new) != base
    if renamed and base.lower() not in filenames:
      if "." in base:
        made.append(name_needle(m))
      made.append(link_needle(m))
    for needle in made:
      needle.unknown = m.how.startswith("gitignored")
    needles.extend(made)
  for d in dirs:
    needles.append(path_needle("dir", d.old, d.new))
  return needles


# ------------------------------------------------------- external references


def read_source(path: str) -> Tuple[Optional[str], str]:
  try:
    if os.path.getsize(path) > MAX_SOURCE_BYTES:
      return None, "larger than %d bytes" % MAX_SOURCE_BYTES
    with open(path, "rb") as fh:
      data = fh.read()
  except OSError as err:
    return None, str(err)
  if data.startswith(b"bplist") or b"\0" in data:
    return None, "binary file"
  return data.decode("utf-8", "replace"), ""


def expand_patterns(vault: Path, notes: List[str]) -> List[str]:
  paths: List[str] = []
  for pattern in SOURCE_PATTERNS + [str(vault / "CLAUDE.md")]:
    found = sorted(glob.glob(os.path.expanduser(pattern)))
    if not found:
      notes.append("source missing, skipped: %s" % tilde(os.path.expanduser(pattern)))
    paths.extend(p for p in found if os.path.isfile(p))
  return paths


def load_sources(vault: Path, notes: List[str]) -> List[Source]:
  me = os.path.realpath(__file__)
  groups: Dict[str, List[str]] = defaultdict(list)
  for path in expand_patterns(vault, notes):
    real = os.path.realpath(path)
    if real != me and path not in groups[real]:
      groups[real].append(path)
  sources: List[Source] = []
  for real, paths in sorted(groups.items()):
    text, why = read_source(real)
    if text is None:
      notes.append("source skipped (%s): %s" % (why, tilde(real)))
      continue
    aliases = [tilde(p) for p in paths if p != real]
    sources.append(Source(tilde(real), aliases, text))
  return sources


def scan_text(text: str, needles: List[Needle]) -> List[Tuple[int, int, Needle]]:
  low = text.lower()
  found: List[Tuple[int, int, Needle]] = []
  for needle in needles:
    if needle.hint in low:
      found.extend((m.start(), m.end(), needle) for m in needle.regex.finditer(text))
  found.sort(key=lambda h: (h[0], -(h[1] - h[0])))
  kept: List[Tuple[int, int, Needle]] = []
  for start, end, needle in found:
    if not kept or start >= kept[-1][1]:
      kept.append((start, end, needle))
  return kept


def suggestion(needle: Needle) -> str:
  if needle.unknown:
    return "(moved or deleted, destination unknown: pass --move OLD NEW)"
  if needle.new is None:
    return "(deleted)" if needle.kind != "dir" else "(deleted or scattered)"
  if needle.kind == "link":
    return "[[%s]]" % needle.new
  return needle.new + ("/" if needle.kind == "dir" else "")


def display_match(text: str, start: int, end: int) -> Tuple[str, bool]:
  """Matched text for display; quoted when the path is split across literals."""
  raw = text[start:end]
  split = any(c in raw for c in "\"'")
  if split:
    start -= 1 if start > 0 and text[start - 1] in "\"'" else 0
    end += 1 if end < len(text) and text[end] in "\"'" else 0
    raw = text[start:end]
  return re.sub(r"\s+", " ", raw)[:90], split


def find_external(sources: List[Source], needles: List[Needle]) -> List[str]:
  rows: List[str] = []
  for src in sources:
    offsets = [i for i, c in enumerate(src.text) if c == "\n"]
    for start, end, needle in scan_text(src.text, needles):
      line = bisect.bisect_right(offsets, start) + 1
      lo = (offsets[line - 2] + 1) if line > 1 else 0
      hi = offsets[line - 1] if line - 1 < len(offsets) else len(src.text)
      same_line = src.text[lo:hi]
      also = needle.new is not None and needle.new in same_line and needle.kind != "name"
      shown, split = display_match(src.text, start, end)
      via = "  (also via %s)" % ", ".join(src.aliases) if src.aliases else ""
      tag = ("  [line also mentions the new path]" if also else "")
      tag += "  [path split across string literals: edit each part]" if split else ""
      rows.append("  %s:%d  %s -> %s%s%s" % (src.label, line, shown, suggestion(needle), via, tag))
  return list(dict.fromkeys(rows))


def find_icloud(sources: List[Source]) -> List[str]:
  rows: List[str] = []
  for src in sources:
    for number, line in enumerate(src.text.split("\n"), 1):
      at = line.find(ICLOUD_MARK)
      if at >= 0:
        excerpt = line[max(0, at - 40):at + len(ICLOUD_MARK) + 40].strip()
        rows.append("  %s:%d  ...%s..." % (src.label, number, excerpt))
  return rows


# ------------------------------------------------------------ vault wikilinks


def vault_files(vault: Path) -> List[str]:
  out: List[str] = []
  for root, dirs, files in os.walk(vault):
    dirs[:] = sorted(d for d in dirs if not d.startswith("."))
    rel_root = os.path.relpath(root, vault)
    for name in sorted(files):
      rel = name if rel_root == "." else rel_root + "/" + name
      if visible(rel):
        out.append(nfc(rel))
  return out


def blank_code(text: str) -> str:
  """Blank fenced and inline code (keeping line numbers) before link parsing."""
  out: List[str] = []
  fence = ""
  for line in text.split("\n"):
    stripped = line.lstrip()
    marker = stripped[:3] if stripped[:3] in ("```", "~~~") else ""
    if fence:
      if marker == fence:
        fence = ""
      out.append("")
    elif marker:
      fence = marker
      out.append("")
    else:
      out.append(INLINE_CODE.sub(lambda m: " " * len(m.group(0)), line))
  return "\n".join(out)


def parse_links(vault: Path, files: List[str], notes: List[str]) -> List[LinkRef]:
  """Every wikilink outside code: (file, line, bang, target, rest)."""
  links: List[LinkRef] = []
  for rel in files:
    if not rel.lower().endswith(".md"):
      continue
    try:
      text = (vault / rel).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as err:
      notes.append("unreadable note skipped: %s (%s)" % (rel, err))
      continue
    for number, line in enumerate(blank_code(text).split("\n"), 1):
      for m in WIKILINK.finditer(line):
        parts = re.match(r"^([^#^|\\]*)(.*)$", m.group(2))
        if parts and parts.group(1).strip():
          links.append((rel, number, m.group(1), nfc(parts.group(1)), parts.group(2)))
  return links


def build_suffixes(files: List[str]) -> Dict[str, List[str]]:
  """Every path-suffix form a link may use (lowercase) -> files it could reach."""
  out: Dict[str, List[str]] = defaultdict(list)
  for rel in files:
    parts = link_path(rel).lower().split("/")
    for i in range(len(parts)):
      out["/".join(parts[i:])].append(rel)
  return dict(out)


def new_target(key: str, orig: str, m: Move, suffixes: Dict[str, List[str]]) -> str:
  """Link text for the moved note: full path if the old link was rooted, else the
  shortest path suffix that reaches exactly one file."""
  newp = link_path(m.new or "")
  parts = newp.split("/")
  target = newp
  if "/" not in key or link_path(m.old).lower() != key:
    for k in range(key.count("/") + 1, len(parts) + 1):
      candidate = "/".join(parts[-k:])
      if len(suffixes.get(candidate.lower(), [])) == 1:
        target = candidate
        break
  return target + (".md" if orig.lower().endswith(".md") else "")


def pick_link_target(src: str, key: str, files: List[str]) -> Optional[str]:
  """Approximation of Obsidian: an exact vault path wins, then the linking note's
  own folder, then the shortest path."""
  exact = [p for p in files if link_path(p).lower() == key]
  if exact:
    return exact[0]
  here = os.path.dirname(src)
  pool = [p for p in files if os.path.dirname(p) == here] or files
  return min(pool, key=lambda p: (len(p), p)) if pool else None


def gone_text(hits: List[Move]) -> str:
  if all(m.how.startswith("gitignored") for m in hits):
    return "(destination unknown: moved or deleted; pass --move OLD NEW)"
  return "(note deleted: remove or repoint)"


def redirect_row(ref: LinkRef, key: str, hits: List[Move],
                 suffixes: Dict[str, List[str]]) -> Optional[str]:
  """A link that still resolves, but no longer to the note it used to reach."""
  rel, number, bang, target, rest = ref
  now = suffixes.get(key, [])
  for m in hits:
    before = pick_link_target(rel, key, [p for p in now if p != m.new] + [m.old])
    after = pick_link_target(rel, key, now)
    if before == m.old and after != m.new:
      fix = gone_text(hits)
      if m.new:
        fix = "%s[[%s%s]]" % (bang, new_target(key, target, m, suffixes), rest)
      return ("  %s:%d  %s[[%s%s]] -> %s  [silent redirect: now resolves to %s]"
              % (rel, number, bang, target, rest, fix, after))
  return None


def rewrite_row(ref: LinkRef, key: str, hits: List[Move],
                suffixes: Dict[str, List[str]]) -> str:
  """A link whose target no longer exists: propose the new target."""
  rel, number, bang, target, rest = ref
  old_text = "%s[[%s%s]]" % (bang, target, rest)
  news = list(dict.fromkeys(
    new_target(key, target, m, suffixes) if m.new else "" for m in hits))
  if news == [""]:
    return "  %s:%d  %s -> %s" % (rel, number, old_text, gone_text(hits))
  new_text = " | ".join("%s[[%s%s]]" % (bang, n, rest) for n in news if n)
  flag = "  [ambiguous: %d candidates]" % len(news) if len(news) > 1 else ""
  return "  %s:%d  %s -> %s%s" % (rel, number, old_text, new_text, flag)


def link_rewrites(links: List[LinkRef], moves: List[Move],
                  suffixes: Dict[str, List[str]]) -> List[str]:
  by_name: Dict[str, List[Tuple[str, Move]]] = defaultdict(list)
  for m in moves:
    if not m.absolute:
      lp = link_path(m.old).lower()
      by_name[lp.split("/")[-1]].append((lp, m))
  rows: List[str] = []
  for ref in links:
    key = re.sub(r"\.md$", "", ref[3].strip(), flags=re.IGNORECASE).lower()
    cands = by_name.get(key.split("/")[-1], [])
    hits = [m for lp, m in cands if lp == key or lp.endswith("/" + key)]
    if not hits:
      continue
    # Still resolving is fine unless it now reaches a different note.
    build = redirect_row if key in suffixes else rewrite_row
    row = build(ref, key, hits, suffixes)
    if row:
      rows.append(row)
  return rows


# ----------------------------------------------------- duplicates and coverage


def winner(paths: List[str]) -> str:
  """Obsidian's pick for a bare link from another folder: shortest path."""
  return min(paths, key=lambda p: (len(p), p))


def duplicate_risks(moves: List[Move], suffixes: Dict[str, List[str]], bare: Counter) -> List[str]:
  rows: List[str] = []
  for m in moves:
    if m.absolute or not m.new:
      continue
    key = link_name(m.new).lower()
    others = [p for p in suffixes.get(key, []) if p != m.new]
    if not others:
      continue
    created = link_name(m.old).lower() != key
    flips = (winner(others + [m.old]) == m.old) != (winner(others + [m.new]) == m.new)
    if not (created or flips):
      continue
    why = "new duplicate name" if created else "default winner changes"
    count = bare.get(key, 0)
    rows.append("  %s shares its name with %s  [%s; %d bare [[%s]] link(s); "
                "shortest path now wins: %s]" % (m.new, ", ".join(others), why, count,
                                                  link_name(m.new), winner(others + [m.new])))
  return rows


def parse_dirs_to_index(path: Path) -> Optional[List[str]]:
  try:
    tree = ast.parse(path.read_text(encoding="utf-8"))
  except (OSError, SyntaxError, ValueError):
    return None
  for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
      targets = node.targets
    elif isinstance(node, ast.AnnAssign):
      targets = [node.target]
    else:
      continue
    if any(isinstance(t, ast.Name) and t.id == "DIRS_TO_INDEX" for t in targets) and node.value:
      try:
        value = ast.literal_eval(node.value)
      except ValueError:
        return None
      if isinstance(value, (list, tuple)) and all(isinstance(v, str) for v in value):
        return list(value)
  return None


def vault_rag_coverage(vault: Path, moves: List[Move], standing: List[str],
                       notes: List[str]) -> List[str]:
  indexed = parse_dirs_to_index(INDEXER)
  if indexed is None:
    notes.append("could not read DIRS_TO_INDEX from %s" % tilde(str(INDEXER)))
    return []
  rows = ["  DIRS_TO_INDEX lists %s but the vault has no such directory" % d
          for d in indexed if not (vault / d).is_dir()]
  tops = sorted(d.name for d in vault.iterdir() if d.is_dir() and visible(d.name))
  left: Counter = Counter()
  for m in moves:
    if m.new and not m.absolute and top_dir(m.old) in indexed and top_dir(m.new) not in indexed:
      left[top_dir(m.new)] += 1
  rows += ["  %d moved file(s) now sit in %s, which vault-rag does not index (they drop "
           "out of search)" % (n, d) for d, n in sorted(left.items())]
  unindexed = [d for d in tops if d not in indexed]
  if unindexed:
    standing.append("  top-level dirs not in DIRS_TO_INDEX: %s" % ", ".join(unindexed))
  return rows


# ------------------------------------------------------------------ reporting


def describe_moves(moves: List[Move], dirs: List[DirMove], show_all: bool) -> List[str]:
  rows: List[str] = []
  for d in dirs:
    dest = d.new + "/" if d.new else "(deleted or scattered)"
    rows.append("  [dir] %s/ -> %s   (%d file(s), %d to that destination)"
                % (d.old, dest, d.total, d.to_new))
  for m in moves:
    if covered_by_dirs(m, dirs) and not show_all:
      continue
    flag = ""
    if m.private:
      flag = ("  !! gitignored private file: the new path is NOT ignored, auto-sync "
              "would publish it" if m.new else
              "  !! gitignored private file missing; if it moved, the new copy is NOT ignored")
    rows.append("  %s -> %s   [%s]%s" % (m.old, m.new or "(deleted)", m.how, flag))
  return rows


def clip(rows: List[str], show_all: bool) -> List[str]:
  if show_all or len(rows) <= LIST_LIMIT:
    return rows
  return rows[:LIST_LIMIT] + ["  ... and %d more (re-run with --all)" % (len(rows) - LIST_LIMIT)]


def render(rep: Report, show_all: bool) -> str:
  out = list(rep.header)
  sections = [
    ("What moved", rep.moved, "no moves or deletions found"),
    ("External references to old paths (fix manually)", rep.external, "none"),
    ("Wikilinks to update (proposed old -> new)", rep.links, "none"),
    ("Duplicate-basename risks", rep.dups, "none"),
    ("vault-rag coverage", rep.coverage, "none"),
  ]
  for title, rows, empty in sections:
    out += ["", "## " + title] + (clip(rows, show_all) if rows else ["  " + empty])
  if rep.standing:
    out += ["", "## Standing checks (informational, do not affect 'All clear')"] + rep.standing
  if rep.notes:
    out += ["", "## Notes"] + ["  " + n for n in rep.notes]
  findings = rep.external or rep.links or rep.dups or rep.coverage
  out += ["", "" if findings else "All clear: nothing points at an old path."]
  return "\n".join(out).rstrip() + "\n"


# ----------------------------------------------------------------------- main


def build_report(args: argparse.Namespace) -> Report:
  vault = Path(os.path.expanduser(args.vault)).resolve()
  rep = Report()
  check_repo(vault)
  base, desc = resolve_base(vault, args.ref, args.since)
  moves = detect_moves(vault, base, rep.notes)
  extra, extra_dirs = manual_moves(vault, args.move or [])
  moves = sorted({m.old: m for m in moves + extra}.values(), key=lambda m: m.old)
  dirs = derive_dir_moves(vault, moves) + extra_dirs
  files = vault_files(vault)
  suffixes = build_suffixes(files)
  filenames = {os.path.basename(f).lower() for f in files}
  sources = load_sources(vault, rep.notes)
  rep.header = ["vault: %s" % vault,
                "base: %s" % desc,
                "compared: %s + uncommitted changes" % describe_range(vault, base),
                "scanned: %d source file(s) for stale references" % len(sources)]
  rep.moved = describe_moves(moves, dirs, args.all)
  rep.external = find_external(sources, build_needles(moves, dirs, filenames))
  links = parse_links(vault, files, rep.notes)
  rep.links = link_rewrites(links, moves, suffixes)
  bare = Counter(t.strip().lower() for _f, _n, _b, t, _r in links if "/" not in t)
  rep.dups = duplicate_risks(moves, suffixes, bare)
  rep.coverage = vault_rag_coverage(vault, moves, rep.standing, rep.notes)
  icloud = find_icloud(sources)
  if icloud:
    rep.standing.insert(0, "  %s still appears in:" % ICLOUD_MARK)
    rep.standing[1:1] = icloud
  return rep


def parse_args(argv: Optional[List[str]]) -> argparse.Namespace:
  ap = argparse.ArgumentParser(description="Find references to moved or deleted vault paths.")
  ap.add_argument("--vault", default=str(CANON_VAULT), help="vault root (a git repo)")
  group = ap.add_mutually_exclusive_group()
  group.add_argument("--ref", help="compare REV..working tree (e.g. HEAD = uncommitted only)")
  group.add_argument("--since", help="compare from the last commit before DATE "
                     "(default: '%s')" % DEFAULT_SINCE)
  ap.add_argument("--move", nargs=2, action="append", metavar=("OLD", "NEW"),
                  help="extra move git cannot see; NEW '-' = deleted; absolute OLD = relocated root")
  ap.add_argument("--all", action="store_true", help="do not truncate long lists")
  return ap.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
  args = parse_args(argv)
  try:
    rep = build_report(args)
  except SweepError as err:
    print("error: %s" % err, file=sys.stderr)
    return 2
  sys.stdout.write(render(rep, args.all))
  return 0


if __name__ == "__main__":
  sys.exit(main())

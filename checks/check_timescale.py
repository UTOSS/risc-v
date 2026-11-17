#!/usr/bin/env python3
"""Check that every design unit under src/ imports src/timescale.svh.

Verilator raises TIMESCALEMOD when some design units have a timescale and
others do not. Whether a unit "has" one depends on which files the compiler
happened to read before it, so the error can come and go with the order of
the source list. This check removes that dependency: every file that declares
a design unit (module, interface, package, ...) must include the shared
timescale header (src/timescale.svh) *itself* before its first declaration,
either directly or through another header that includes it. This keeps the
project's timescale defined in exactly one place.

A `timescale directive does not count, and one written anywhere other than
the shared header is reported as an error.

Files that declare no design units (for example macro-only headers) are not
checked.

Usage: check_timescale.py [--root DIR] [--header FILE] [--github-actions] [PATH ...]
PATHs default to the src/ directory; directories are searched recursively
for .sv, .svh, .v and .vh files. Exits 1 if any file fails.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

SOURCE_SUFFIXES = {".sv", ".svh", ".v", ".vh"}
DEFAULT_HEADER = "src/timescale.svh"

DESIGN_UNIT_KEYWORDS = (
    "module",
    "macromodule",
    "interface",
    "package",
    "program",
    "primitive",
    "checker",
    "config",
)

# A design unit declaration: the keyword at the start of a statement, followed
# by an optional lifetime and the unit's name. "interface class" is a class
# declaration, not a design unit, so it is excluded.
DESIGN_UNIT_RE = re.compile(
    r"(?:^|(?<=[;\s]))(?P<kw>" + "|".join(DESIGN_UNIT_KEYWORDS) + r")\b"
    r"(?!\s+class\b)"
    r"(?:\s+(?:static|automatic))?"
    r"\s+(?P<name>[A-Za-z_][A-Za-z0-9_$]*)",
    re.MULTILINE,
)
INCLUDE_RE = re.compile(r'`include\s+"(?P<path>[^"]+)"')
TIMESCALE_RE = re.compile(r"`timescale\b")
# Strings first so that "//" inside a string is not treated as a comment.
COMMENT_OR_STRING_RE = re.compile(
    r'"(?:\\.|[^"\\\n])*"|//[^\n]*|/\*.*?\*/', re.DOTALL
)


def strip_comments(text: str) -> str:
    """Blank out comments, keeping strings and line numbers intact."""

    def repl(match: re.Match[str]) -> str:
        s = match.group(0)
        if s.startswith('"'):
            return s
        return re.sub(r"[^\n]", " ", s)

    return COMMENT_OR_STRING_RE.sub(repl, text)


def strip_define_bodies(text: str) -> str:
    """Blank out `define bodies (with line continuations) so that keywords or
    includes inside macros are not mistaken for real ones."""
    out = []
    in_define = False
    for line in text.split("\n"):
        stripped = line.lstrip()
        if in_define or stripped.startswith("`define"):
            in_define = line.rstrip().endswith("\\")
            out.append(" " * len(line))
        else:
            out.append(line)
    return "\n".join(out)


@dataclass
class Event:
    pos: int
    kind: str  # "timescale" | "include" | "unit"
    value: str = ""


class Checker:
    def __init__(self, root: Path, header: Path) -> None:
        self.root = root
        self.header = header
        self.header_name = header.relative_to(root).as_posix() if header.is_relative_to(root) else str(header)
        self._provides: dict[Path, bool] = {}
        self._events: dict[Path, tuple[str, list[Event]]] = {}

    def resolve_include(self, include: str, from_file: Path) -> Path | None:
        for base in (self.root, from_file.parent):
            candidate = (base / include).resolve()
            if candidate.is_file():
                return candidate
        return None

    def events(self, path: Path) -> tuple[str, list[Event]]:
        if path not in self._events:
            text = strip_define_bodies(strip_comments(path.read_text()))
            events = [Event(m.start(), "timescale") for m in TIMESCALE_RE.finditer(text)]
            events += [Event(m.start(), "include", m.group("path")) for m in INCLUDE_RE.finditer(text)]
            events += [
                Event(m.start("kw"), "unit", f"{m.group('kw')} {m.group('name')}")
                for m in DESIGN_UNIT_RE.finditer(text)
            ]
            events.sort(key=lambda e: e.pos)
            self._events[path] = (text, events)
        return self._events[path]

    def provides_timescale(self, path: Path, stack: tuple[Path, ...] = ()) -> bool:
        """True if `path` is the shared header or includes it, directly or
        through other includes. `timescale directives do not count."""
        if path == self.header:
            return True
        if path in self._provides:
            return self._provides[path]
        if path in stack:  # include cycle; guarded headers make this harmless
            return False
        _, events = self.events(path)
        result = False
        for event in events:
            if event.kind == "include":
                target = self.resolve_include(event.value, path)
                if target and self.provides_timescale(target, stack + (path,)):
                    result = True
                    break
        self._provides[path] = result
        return result

    def check(self, path: Path) -> list[tuple[int, str]]:
        """Return (line, message) for each problem found in `path`."""
        text, events = self.events(path)
        problems = []
        have_timescale = False
        for event in events:
            line = text.count("\n", 0, event.pos) + 1
            if event.kind == "timescale":
                if path != self.header:
                    problems.append(
                        (line, f'`timescale directive is not allowed here; use `include "{self.header_name}" instead')
                    )
            elif event.kind == "include":
                target = self.resolve_include(event.value, path)
                if target is None:
                    problems.append((line, f'cannot resolve `include "{event.value}"'))
                elif self.provides_timescale(target):
                    have_timescale = True
            elif event.kind == "unit" and not have_timescale:
                problems.append(
                    (
                        line,
                        f"{event.value} is declared before {self.header_name} is included; "
                        f'add `include "{self.header_name}" at the top of the file',
                    )
                )
                break  # one report per file is enough
        return problems


def collect(paths: list[Path]) -> list[Path]:
    files: set[Path] = set()
    for p in paths:
        if p.is_dir():
            files.update(f for f in p.rglob("*") if f.suffix in SOURCE_SUFFIXES and f.is_file())
        elif p.is_file():
            files.add(p)
        else:
            raise SystemExit(f"error: no such file or directory: {p}")
    return sorted(files)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("paths", nargs="*", type=Path, help="files or directories (default: src)")
    parser.add_argument("--root", type=Path, default=Path("."), help="directory include paths are relative to")
    parser.add_argument("--header", type=Path, default=None,
                        help=f"the shared timescale header, relative to --root (default: {DEFAULT_HEADER})")
    parser.add_argument("--github-actions", action="store_true", help="also emit GitHub Actions annotations")
    args = parser.parse_args()

    root = args.root.resolve()
    files = collect(args.paths or [root / "src"])
    header = (root / (args.header or DEFAULT_HEADER)).resolve()
    if not header.is_file():
        raise SystemExit(f"error: timescale header not found: {header}")
    checker = Checker(root, header)

    failures = 0
    for f in files:
        for line, message in checker.check(f.resolve()):
            failures += 1
            try:
                shown = f.resolve().relative_to(root)
            except ValueError:
                shown = f
            print(f"{shown}:{line}: {message}")
            if args.github_actions:
                print(f"::error file={shown},line={line},title=timescale::{message}")

    if failures:
        print(f"\n{failures} timescale problem(s) found.", file=sys.stderr)
        return 1
    print(f"timescale check passed ({len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

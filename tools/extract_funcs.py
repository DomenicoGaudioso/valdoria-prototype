#!/usr/bin/env python3
"""Remove top-level functions/methods from a GDScript file by name.

Usage: python extract_funcs.py <file.gd> <func_name1> [func_name2 ...]

A "top-level" definition is a line starting (after stripping leading tabs) with
one of: 'func ', 'static func ', 'var ', 'const ', '@onready', '@export', or a
section header comment starting with '# ===='.
Each removed function's trailing blank lines are also dropped.
"""
import sys
import re

# A boundary is a top-level (column-0, no leading tab) definition or section
# header. Inner locals (indented with a tab) never count as boundaries.
DEF_RE = re.compile(r'^(func |static func |var |const |@export |@onready |# ====)')

def is_def(line: str) -> bool:
    return bool(DEF_RE.match(line))

def main() -> int:
    path = sys.argv[1]
    names = set(sys.argv[2:])
    with open(path, 'r', encoding='utf-8', newline='') as f:
        lines = f.readlines()

    func_header = re.compile(r'^(static )?func\s+(\w+)\s*\(')

    out = []
    i = 0
    n = len(lines)
    removed = []
    while i < n:
        line = lines[i]
        m = func_header.match(line)
        if m and m.group(2) in names:
            # Determine the indent prefix of this definition.
            removed.append(m.group(2))
            # Skip until the next top-level definition.
            i += 1
            while i < n and not is_def(lines[i]):
                i += 1
            # Drop trailing blank lines that belong to the removed block.
            while out and out[-1].strip() == '':
                out.pop()
            # Ensure exactly one blank line separator remains if something
            # follows and the previous kept line wasn't blank.
            if i < n and out and out[-1].strip() != '':
                out.append('\n')
            continue
        out.append(line)
        i += 1

    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.writelines(out)

    missing = names - set(removed)
    print('Removed:', ', '.join(sorted(set(removed))) if removed else '(none)')
    if missing:
        print('NOT FOUND:', ', '.join(sorted(missing)))
        return 2
    return 0

if __name__ == '__main__':
    sys.exit(main())

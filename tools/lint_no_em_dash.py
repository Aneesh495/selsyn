#!/usr/bin/env python3
"""
Typography invariant linter.

Scans all source code, documentation, comments, and configuration files
in the repository to ensure that zero Unicode em dashes (U+2014) or en dashes (U+2013)
exist anywhere.

Enforces strict compliance with typography guidelines.
"""

import os
import sys
from pathlib import Path

FORBIDDEN_CHARS = {
    '\u2014': 'EM DASH (\\u2014)',
    '\u2013': 'EN DASH (\\u2013)',
}

EXCLUDE_DIRS = {'.git', '.packages', 'build', '__pycache__', '.pytest_cache', 'venv', '.venv'}
TEXT_EXTENSIONS = {
    '.toit', '.py', '.c', '.h', '.cpp', '.hpp', '.md', '.yaml', '.yml',
    '.txt', '.json', '.sh', '.csv'
}
EXACT_FILES = {'Makefile', 'LICENSE', 'package.yaml', 'package.lock'}


def check_file(filepath: Path) -> list:
    """Check a single file for forbidden typography characters."""
    errors = []
    try:
        content = filepath.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        return errors  # Skip non-UTF8 binary files

    lines = content.splitlines()
    for line_num, line in enumerate(lines, 1):
        for char, name in FORBIDDEN_CHARS.items():
            if char in line:
                col = line.index(char) + 1
                errors.append(f"{filepath}:{line_num}:{col}: forbidden {name} detected: '{line.strip()}'")
    return errors


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    all_errors = []
    files_checked = 0

    for current_dir, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            filepath = Path(current_dir) / file
            if filepath.suffix in TEXT_EXTENSIONS or file in EXACT_FILES:
                files_checked += 1
                errors = check_file(filepath)
                if errors:
                    all_errors.extend(errors)

    if all_errors:
        print(f"FAILED: Found {len(all_errors)} typography violations:")
        for err in all_errors:
            print(f"  {err}")
        return 1

    print(f"Passed: Checked {files_checked} files with 0 typography violations.")
    return 0


if __name__ == '__main__':
    sys.exit(main())

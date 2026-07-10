#!/usr/bin/env python3
"""Extract the section for a given version from CHANGELOG.md.

Usage: extract_changelog.py <version> <changelog_path>
Prints the section body (excluding the heading line) to stdout.
Exits non-zero with an error on stderr if no matching section is found,
so a release tagged without a corresponding changelog entry fails loudly
instead of shipping an empty or misleading release body.
"""
import re
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_changelog.py <version> <changelog_path>", file=sys.stderr)
        return 2

    version, path = sys.argv[1], sys.argv[2]
    with open(path, encoding="utf-8") as f:
        text = f.read()

    heading_pattern = re.compile(
        r"^##\s*\[" + re.escape(version) + r"\].*$", re.MULTILINE
    )
    match = heading_pattern.search(text)
    if not match:
        print(
            f"error: no CHANGELOG.md section found for version {version!r} "
            f"(expected a heading like '## [{version}] - YYYY-MM-DD')",
            file=sys.stderr,
        )
        return 1

    start = match.end()
    next_heading = re.search(r"^##\s*\[", text[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(text)

    body = text[start:end].strip()
    if not body:
        print(f"error: CHANGELOG.md section for {version!r} is empty", file=sys.stderr)
        return 1

    print(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

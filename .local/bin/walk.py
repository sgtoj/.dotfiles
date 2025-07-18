#!/usr/bin/env python3

import os
import sys
import fnmatch

HIDDEN_PATHS = [".git", ".node_modules", ".env", "go.sum"]


def should_exclude(path, base_dir, excludes):
    rel_path = os.path.relpath(path, base_dir)
    for pattern in excludes:
        if fnmatch.fnmatch(rel_path, pattern):
            return True
    for pattern in HIDDEN_PATHS:
        if fnmatch.fnmatch(rel_path, pattern):
            return True
    return False


def walk_and_print(base_dir, excludes):
    for root, dirs, files in os.walk(base_dir):
        if should_exclude(root, base_dir, excludes):
            dirs[:] = []
            continue

        for file_name in files:
            file_path = os.path.join(root, file_name)
            if should_exclude(file_path, base_dir, excludes):
                continue

            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
            except OSError as e:
                print("could not read file:", e, file=sys.stderr)
                continue

            relative_path = os.path.relpath(file_path, base_dir)
            print(f"# {relative_path}")
            print("```")
            print(content, end="")
            print("```")
            print("---")


def main():
    if len(sys.argv) < 2:
        print("usage: python script.py <directory> [exclude patterns...]")
        sys.exit(1)

    base_dir = sys.argv[1]
    excludes = sys.argv[2:]

    if not os.path.isdir(base_dir):
        print("directory does not exist")
        sys.exit(1)

    walk_and_print(base_dir, excludes)


if __name__ == "__main__":
    main()

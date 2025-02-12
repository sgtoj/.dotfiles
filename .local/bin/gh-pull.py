#!/usr/bin/env python3

"""
a script to clone all non-archived repos for a given github organization
"""

import sys
import os
import subprocess
import json

# ---------------------------------------------------------------------- fns ---


def list_org_repos(org: str):
    cmd = f"gh repo list {org} --json name,isArchived,url --limit 9999"
    try:
        result = subprocess.run(
            cmd.split(" "),
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        print("failed to retrieve repositories")
        sys.exit(1)

    try:
        repos = json.loads(result.stdout)
    except json.JSONDecodeError:
        print("failed to parse json output")
        sys.exit(1)

    return repos


def clone_org(org: str, target_dir: str):
    repos = list_org_repos(org)
    for repo in repos:
        if repo.get("isArchived"):
            continue

        repo_name = repo.get("name")
        repo_url = repo.get("url")

        if not repo_name or not repo_url:
            continue

        clone_path = os.path.join(target_dir, repo_name)

        if os.path.isdir(clone_path):
            continue

        try:
            subprocess.run(["git", "clone", f"{repo_url}.git", clone_path], check=True)
            print(f"cloned {repo_name}")
        except subprocess.CalledProcessError:
            print(f"failed to clone {repo_name}")


# -------------------------------------------------------------------- main ---


def main():
    if len(sys.argv) != 3:
        print("usage: clone_repos.py <org> <target_dir>")
        sys.exit(1)

    org = sys.argv[1]
    target_dir = sys.argv[2]

    if not os.path.isdir(target_dir):
        print("target directory does not exist")
        sys.exit(1)

    clone_org(org, target_dir)


if __name__ == "__main__":
    main()

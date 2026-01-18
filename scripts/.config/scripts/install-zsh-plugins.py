#!/bin/python3
import os
import subprocess

BASE_DIR = os.path.expanduser("~/.local/share/zsh-plugins")

os.makedirs(BASE_DIR, exist_ok=True)

REPOSITORIES = [
    "jeffreytse/zsh-vi-mode",
    "zsh-users/zsh-syntax-highlighting",
    "zsh-users/zsh-completions",
    "zsh-users/zsh-autosuggestions",
    "zsh-users/zsh-history-substring-search",
]

# Clone repos to base dir
for repo in REPOSITORIES:
    local_repo = os.path.join(BASE_DIR, os.path.basename(repo))

    if not os.path.exists(local_repo):
        print(f"Cloning {repo} into {local_repo}")
        subprocess.run(
            ["git", "clone", f"https://github.com/{repo}.git", local_repo], check=True
        )
    else:
        print(f"{repo} already cloned. Skipping...")

print("DONE")

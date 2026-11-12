#!/usr/bin/env python3
"""Prepare dependency updates, or check a pushed snapshot without changing its lock."""

import os

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "nixosConfigurations.hws.config.services.caddy.package"
SOURCE = f".#{PACKAGE}.src"


def nix(*args, capture=False):
    return subprocess.run(
        ["nix", *args], cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    ).stdout


def recipe(flake="."):
    return nix("eval", "--raw", "--no-update-lock-file", f"{flake}#{PACKAGE}.src.drvPath", capture=True).strip()


before = None
previous = os.getenv("PUSH_BASE")
if os.getenv("CHECK_ONLY") != "true":
    before = recipe()
    nix(
        "flake", "update", "--commit-lock-file",
        "--option", "commit-lock-file-summary", "chore: update flake inputs",
        *os.getenv("REQUESTED_INPUTS", "").split(),
    )
elif previous:
    try:
        before = recipe(f"git+file://{ROOT}?rev={previous}")
    except subprocess.CalledProcessError:
        print("Previous recipe unavailable; checking the current hash instead.", flush=True)

# No baseline (first push, rewritten history, or manual check): refresh once.
after = recipe()
if before == after and os.getenv("CHECK_ONLY") == "true":
    # An unchanged recipe is not a safe baseline if the previous build failed.
    passed = subprocess.check_output([
        "gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/commits/{previous}/check-runs?per_page=100",
        "--jq", 'any(.check_runs[]; .app.slug == "github-actions" and (.name | endswith("Cache x86_64-linux")) and .conclusion == "success")',
    ], text=True).strip()
    if passed != "true":
        before = None
if before != after or os.getenv("FORCE_CADDY") == "true":
    print("Refreshing Caddy hash with nix-update.", flush=True)
    nix(
        "run", "--no-update-lock-file", "--inputs-from", ".", "nixpkgs#nix-update", "--",
        "--flake", "--version=skip", "--src-only", "--system", "x86_64-linux",
        "--override-filename", "hosts/hws/default.nix", PACKAGE,
    )
    nix("build", "-L", "--no-link", "--no-update-lock-file", SOURCE)
else:
    print("Caddy source recipe unchanged; skipping hash refresh and verification.")

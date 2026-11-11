#!/usr/bin/env python3
"""Update Flake inputs and refresh Caddy's hash only when its source recipe changes."""

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


def recipe():
    return nix("eval", "--raw", "--no-update-lock-file", f"{SOURCE}.drvPath", capture=True).strip()


before = recipe()
nix(
    "flake", "update", "--commit-lock-file",
    "--option", "commit-lock-file-summary", "chore: update flake inputs",
    *os.getenv("REQUESTED_INPUTS", "").split(),
)
after = recipe()
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

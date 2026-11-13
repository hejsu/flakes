#!/usr/bin/env python3
"""Prepare the update PR body: lock changelog, Caddy diff, closure package diff."""

import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = os.environ["BASE_COMMIT"]
OUTPUT = Path(os.environ["OUTPUT"])
OLD = f"git+file://{ROOT}?rev={BASE}"
CONFIGURATIONS = ("nixosConfigurations", "darwinConfigurations")


def run(*args):
    return subprocess.run(
        args, cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE
    ).stdout


def nix(*args):
    return run("nix", *args)


def git(*args):
    return run("git", *args)


def targets():
    for configs in CONFIGURATIONS:
        names = json.loads(nix(
            "eval", "--json", "--no-update-lock-file", f".#{configs}",
            "--apply", "configs: builtins.attrNames configs",
        ))
        for name in names:
            label = f"{configs}.{name}"
            yield label, f"{label}.config.system.build.toplevel"


def closure_diff():
    blocks = []
    for label, attr in targets():
        try:
            old = nix("path-info", "--derivation", "--no-update-lock-file",
                      f"{OLD}#{attr}").strip()
            new = nix("path-info", "--derivation", "--no-update-lock-file",
                      f"path:.#{attr}").strip()
            diff = nix("run", "--no-update-lock-file", "--inputs-from", ".",
                       "nixpkgs#dix", "--", "diff", "--full", "--color=never",
                       old, new)
        except subprocess.CalledProcessError as exc:
            diff = f"closure diff unavailable (exit {exc.returncode})"
        blocks.append(f"# {label}\n{diff.rstrip()}")
    return "\n\n".join(blocks)


def main():
    # Only a dependency update (a new lock commit) needs a closure diff; plain
    # pushes must not pay for evaluating every host on every commit.
    report = closure_diff() if git("rev-list", f"{BASE}..HEAD").strip() else ""
    body = "\n".join([
        "```text",
        git("log", "--format=%b", f"{BASE}..HEAD").rstrip(),
        "```",
        "",
        "```diff",
        git("diff", "--", "hosts/hws/default.nix").rstrip(),
        "```",
        "",
        "<!-- update-report:start -->",
        "```text",
        report,
        "```",
        "<!-- update-report:end -->",
        "",
    ])
    OUTPUT.write_text(body)


if __name__ == "__main__":
    main()

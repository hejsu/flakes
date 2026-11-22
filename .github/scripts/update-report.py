#!/usr/bin/env python3
"""Render, diff, and update closure reports in dependency-update PR bodies."""

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
START = "<!-- update-report:start -->"
END = "<!-- update-report:end -->"
BODY_LIMIT = 60_000


def run(*args, input=None):
    return subprocess.run(
        args, cwd=ROOT, check=True, text=True, input=input, stdout=subprocess.PIPE
    ).stdout


def nix(*args):
    return run("nix", *args)


def render():
    base = os.environ["BASE_COMMIT"]
    body = "\n".join([
        "```text",
        run("git", "log", "--format=%b", f"{base}..HEAD").rstrip(),
        "```",
        "",
        "```diff",
        run("git", "diff", "--", "modules/services/caddy.nix").rstrip(),
        "```",
        "",
        START,
        "_Waiting for build to generate closure diff…_",
        END,
        "",
    ])
    Path(os.environ["OUTPUT"]).write_text(body, encoding="utf-8")


def diff():
    base = os.environ["DIFF_BASE"]
    configs = os.environ["CONFIGURATIONS"]
    hosts = json.loads(Path(os.environ["HOSTS_JSON"]).read_text(encoding="utf-8"))
    prefix = os.environ["RESULT_PREFIX"]
    dix = Path(nix("build", "--no-link", "--print-out-paths", "--no-update-lock-file",
                   "--inputs-from", ".", "nixpkgs#dix").strip()) / "bin" / "dix"

    blocks = []
    for i, host in enumerate(hosts):
        label = f"{configs}.{host}"
        new = str(Path(f"{prefix}-{i}" if i else prefix).resolve())
        try:
            old = nix("eval", "--raw", "--no-update-lock-file",
                      f"git+file://{ROOT}?rev={base}#{label}.config.system.build.toplevel.outPath").strip()
            if old != new:
                # Realising a store path directly substitutes from caches (even
                # for allowSubstitutes = false outputs) and never builds locally.
                nix("build", "--no-link", old)
            out = run(str(dix), "diff", "--color=never", old, new)
        except subprocess.CalledProcessError as exc:
            out = f"closure diff unavailable (exit {exc.returncode})"
        blocks.append(f"# {label}\n{out.rstrip()}")

    output = Path(os.environ["OUTPUT"])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(blocks) + "\n", encoding="utf-8")


def splice(body, report):
    s, e = body.find(START), body.find(END)
    prefix, suffix = (body[:s], body[e + len(END):]) if 0 <= s < e else (body.rstrip() + "\n\n", "\n")
    head = f"{START}\n```text\n"
    tail = f"\n```\n{END}"
    full = prefix + head + report + tail + suffix
    if len(full) <= BODY_LIMIT:
        return full
    tail = f"\n```\n\nPR description truncated at 60,000 characters.\n{END}"
    avail = max(0, BODY_LIMIT - len(prefix) - len(suffix) - len(head) - len(tail))
    return prefix + head + report[:avail].rstrip() + tail + suffix


def update():
    pr = os.environ["PR_NUMBER"]
    diff_dir = Path(os.environ["DIFF_DIR"])
    files = sorted(diff_dir.glob("*.txt"), key=lambda p: (not p.name.startswith("nixos"), p.name)) if diff_dir.is_dir() else []
    parts = [t for p in files if (t := p.read_text(encoding="utf-8").strip())]
    report = "\n\n".join(parts) or "closure diff unavailable (no build reports produced)"
    body = run("gh", "pr", "view", pr, "--json", "body", "--jq", ".body")
    run("gh", "pr", "edit", pr, "--body-file", "-", input=splice(body, report))


if __name__ == "__main__":
    {"render": render, "diff": diff, "update": update}[sys.argv[1]]()

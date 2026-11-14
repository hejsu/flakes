import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "config/fish/functions/ss_enroll.fish"
CONFIG = "keys:\n  - &existing age1existing\ncreation_rules:\n  - path_regex: secrets/.*\n"
STAGED = "/tmp/ss-enroll.TEST"


def mock(command, args):
    root = Path(os.environ["ENROLL_TEST_ROOT"])
    fault = os.environ.get("ENROLL_TEST_FAULT")
    staging = root / "remote/staged"
    stage = staging / "key"
    if command == "uname":
        print(os.environ.get("ENROLL_TEST_OS", "Linux"))
        return 0
    if command == "sudo":
        if fault == "sudo":
            return 1
        if fault == "hangup":
            os.kill(os.getppid(), signal.SIGHUP)
            return 1
        return subprocess.call(args)
    if command == "install":
        if fault == "install" and "-d" not in args:
            return 41
        args = args[:]
        for flag in ("-o", "-g"):
            index = args.index(flag)
            del args[index:index + 2]
        return subprocess.call([shutil.which("install", path=os.defpath), *args])

    with (root / "calls").open("a") as log:
        log.write(json.dumps([command, *args]) + "\n")
    if command == "scp":
        if fault == "protected-tmp":
            if not staging.is_dir() or stat.S_IMODE(staging.stat().st_mode) != 0o700:
                return 1
        shutil.copyfile(args[-2], stage)
        return 27 if fault == "upload" else 0
    if args[-1].startswith("mktemp "):
        if fault == "connect":
            return 255
        if fault == "stage-output":
            print("unexpected output")
        else:
            if "mktemp -d " in args[-1]:
                staging.mkdir(mode=0o700)
            else:
                staging.touch(mode=0o600)
            print(STAGED)
        return 0
    if fault == "result" and args[-1].startswith("cat "):
        print("ssh: result channel failed", file=sys.stderr)
        return 255
    if os.environ.get("ENROLL_TEST_CLEANUP_OFFLINE") == "1" and "set -eu" not in args[-1]:
        return 255

    script = args[-1].replace(STAGED, str(staging))
    script = script.replace("/var/lib/sops-nix", str(root / "remote/linux"))
    script = script.replace("/var/db/age", str(root / "remote/darwin"))
    script = script.replace(">/dev/tty", ">&2")
    script = script.replace("</dev/tty", "<" + shlex.quote(str(root / "reply")))
    rc = subprocess.call([os.environ.get("ENROLL_TEST_SHELL", "/bin/sh"), "-c", script])
    if not rc and fault in ("concurrent", "concurrent-index") and "set -eu" in script:
        config = root / "repo/.sops.yaml"
        original = config.read_text()
        config.write_text(original + "# user edit\n")
        if fault == "concurrent-index":
            subprocess.check_call(["git", "-C", str(root / "repo"), "add", ".sops.yaml"])
            config.write_text(original)
    return rc


class Enroll(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ss-enroll.")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.config = self.repo / ".sops.yaml"
        for directory in ("repo/hosts/syd", "local", "remote", "bin"):
            (self.root / directory).mkdir(parents=True)
        self.host = self.repo / "hosts/syd/default.nix"
        self.host.write_text("{ modules.sops.enable = false; }\n")
        self.config.write_text(CONFIG)
        self.git("init", "-q")
        self.git("config", "user.name", "test")
        self.git("config", "user.email", "test@example.org")
        self.git("config", "commit.gpgSign", "false")
        self.git("config", "core.hooksPath", str(self.repo / ".git/hooks"))
        self.git("add", ".")
        self.git("-c", "user.name=test", "-c", "user.email=test@example.org",
                 "-c", "commit.gpgSign=false", "commit", "-qm", "fixture")
        self.env = dict(os.environ, ENROLL_TEST_ROOT=str(self.root),
                        TMPDIR=str(self.root / "local"),
                        PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"])
        for name in ("uname", "install", "sudo"):
            executable = self.root / "bin" / name
            executable.write_text(
                "#!/bin/sh\nexec " + shlex.join([sys.executable, str(Path(__file__).resolve()), name]) + ' "$@"\n'
            )
            executable.chmod(0o700)
        self.driver = self.root / "driver.fish"
        self.driver.write_text("""
function ssh
    command $ENROLL_TEST_PYTHON $ENROLL_TEST_FILE ssh $argv
end
function scp
    command $ENROLL_TEST_PYTHON $ENROLL_TEST_FILE scp $argv
end
set -gx NH_FLAKE "$ENROLL_TEST_ROOT/repo"
source $ENROLL_TEST_SOURCE
ss_enroll $argv
""")
        self.env.update(ENROLL_TEST_PYTHON=sys.executable,
                        ENROLL_TEST_FILE=str(Path(__file__).resolve()),
                        ENROLL_TEST_SOURCE=str(SOURCE))

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.STDOUT)

    def run_enroll(self, *args, reply="n", fault="", system="Linux"):
        (self.root / "reply").write_text(reply + "\n")
        self.env.update(ENROLL_TEST_FAULT=fault, ENROLL_TEST_OS=system)
        result = subprocess.run(["fish", "--no-config", str(self.driver), *args],
                                env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(list((self.root / "local").iterdir()), [], result.stderr)
        self.assertFalse((self.root / "remote/staged").exists(), result.stderr)
        self.assertFalse(list((self.root / "remote").rglob("*.new")), result.stderr)
        return result

    def existing_key(self, backup=False):
        key = self.root / "remote/linux/key.txt"
        key.parent.mkdir(mode=0o700)
        key.write_text("original key\n")
        key.chmod(0o600)
        if backup:
            key.with_suffix(".txt.old").write_text("previous backup\n")
        return key

    def assert_unchanged(self):
        self.assertEqual(self.config.read_text(), CONFIG)

    def test_fresh_linux(self):
        result = self.run_enroll("syd")
        self.assertEqual(result.returncode, 0, result.stderr)
        key = self.root / "remote/linux/key.txt"
        public = subprocess.check_output(["age-keygen", "-y", str(key)], text=True).strip()
        self.assertIn("+  - &syd " + public, result.stdout)
        self.assertEqual(result.stderr, "Public key: " + public + "\n")
        self.assertEqual(stat.S_IMODE(key.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(key.parent.stat().st_mode), 0o700)
        self.assertEqual(self.git("log", "-1", "--format=%s").decode().strip(), "sops: enroll syd")
        self.assertEqual(self.git("status", "--porcelain", "--", ".sops.yaml"), b"")

    def test_darwin_filename(self):
        result = self.run_enroll("syd", system="Darwin")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "remote/darwin/keys.txt").exists())
        self.assertFalse((self.root / "remote/darwin/key.txt").exists())

    def test_private_staging_directory(self):
        result = self.run_enroll("syd", fault="protected-tmp")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]
        self.assertTrue(any(call[-1] == "mktemp -d /tmp/ss-enroll.XXXXXXXX" for call in calls))
        self.assertTrue(any(call[0] == "scp" and call[-1] == "syd:" + STAGED + "/key" for call in calls))

    def test_remote_fish_shell(self):
        self.env["ENROLL_TEST_SHELL"] = shutil.which("fish")
        result = self.run_enroll("syd")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_replace_anchor(self):
        self.config.write_text(CONFIG.replace("&existing", "&syd"))
        self.git("add", ".sops.yaml")
        self.git("-c", "user.name=test", "-c", "user.email=test@example.org",
                 "-c", "commit.gpgSign=false", "commit", "-qm", "existing anchor")
        result = self.run_enroll("syd")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config.read_text().count("&syd "), 1)
        self.assertIn("-  - &syd age1existing", result.stdout)

    def test_rotation_declined(self):
        key = self.existing_key()
        result = self.run_enroll("syd")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(key.read_text(), "original key\n")
        self.assertFalse(key.with_suffix(".txt.old").exists())
        self.assert_unchanged()

    def test_rotation_confirmed(self):
        key = self.existing_key()
        self.host.write_text("{ modules.sops.enable = true; }\n")
        result = self.run_enroll("syd", reply="y")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(key.with_suffix(".txt.old").read_text(), "original key\n")
        self.assertNotEqual(key.read_text(), "original key\n")
        self.assertIn("rotated; updatekeys before deploy", result.stderr)
        self.assertEqual(self.git("log", "-1", "--format=%s").decode().strip(), "sops: rotate syd")
        self.assertEqual(self.git("status", "--porcelain", "--", ".sops.yaml"), b"")

    def test_first_enrollment_with_sops_enabled(self):
        self.host.write_text("{ modules.sops = {\n enable = true;\n }; }\n")
        self.driver.write_text(self.driver.read_text().replace(
            "ss_enroll $argv", "function nix; return 1; end\nss_enroll $argv"
        ))
        result = self.run_enroll("syd")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "remote/linux/key.txt").exists())

    def test_local_hostname_allowed(self):
        local = subprocess.check_output(["hostname", "-s"], text=True).strip()
        host = self.repo / "hosts" / local
        host.mkdir(exist_ok=True)
        (host / "default.nix").write_text("{}\n")
        result = self.run_enroll(local)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("&" + local + " age1", self.config.read_text())

    def test_shared_guard_autoloads(self):
        script = (
            'set -p fish_function_path ' + shlex.quote(str(SOURCE.parent))
            + '\nfunction ssh; echo 1; end\nss_require_clean syd\n'
        )
        result = subprocess.run(["fish", "--no-config", "-c", script],
                                env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("impure mode is active on syd", result.stderr)

    def test_host_enum_allows_dotted_names(self):
        host = self.repo / "hosts/syd.example"
        host.mkdir()
        (host / "default.nix").write_text("{}\n")
        result = self.run_enroll("syd.example")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("&syd.example age1", self.config.read_text())

    def test_empty_host_enum_does_not_connect(self):
        self.host.rename(self.root / "saved-host.nix")
        result = self.run_enroll("syd")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no such host", result.stderr)
        self.assertFalse((self.root / "calls").exists())
        self.assert_unchanged()

    def test_remote_failure_cleanup_without_reconnection(self):
        key = self.existing_key()
        self.env["ENROLL_TEST_CLEANUP_OFFLINE"] = "1"
        for fault in ("sudo", "hangup", "", "install"):
            with self.subTest(fault=fault):
                result = self.run_enroll("syd", reply="y" if fault == "install" else "n", fault=fault)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(key.read_text(), "original key\n")
                self.assert_unchanged()

    def test_existing_backup_not_overwritten(self):
        key = self.existing_key(backup=True)
        result = self.run_enroll("syd", reply="y")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(key.read_text(), "original key\n")
        self.assertEqual(key.with_suffix(".txt.old").read_text(), "previous backup\n")
        self.assert_unchanged()

    def test_failed_install_preserves_key(self):
        key = self.existing_key()
        result = self.run_enroll("syd", reply="y", fault="install")
        self.assertEqual(result.returncode, 41)
        self.assertEqual(key.read_text(), "original key\n")
        self.assert_unchanged()

    def test_transport_failures(self):
        for fault, status in (("connect", 255), ("stage-output", 1), ("upload", 27)):
            with self.subTest(fault=fault):
                result = self.run_enroll("syd", fault=fault)
                self.assertEqual(result.returncode, status)
                self.assert_unchanged()

    def test_result_failure_is_not_commit_failure(self):
        head = self.git("rev-parse", "HEAD")
        result = self.run_enroll("syd", fault="result")
        self.assertEqual(result.returncode, 255)
        self.assertIn("ssh: result channel failed", result.stderr)
        self.assertNotIn("commit failed", result.stderr)
        self.assert_unchanged()
        self.assertEqual(self.git("rev-parse", "HEAD"), head)

    def test_unsupported_os(self):
        result = self.run_enroll("syd", system="FreeBSD")
        self.assertNotEqual(result.returncode, 0)
        self.assert_unchanged()

    def test_concurrent_edit_not_overwritten(self):
        head = self.git("rev-parse", "HEAD")
        result = self.run_enroll("syd", fault="concurrent")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_text(), CONFIG + "# user edit\n")
        self.assertIn("refusing to overwrite", result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)

    def test_concurrent_index_edit_not_overwritten(self):
        head = self.git("rev-parse", "HEAD")
        result = self.run_enroll("syd", fault="concurrent-index")
        self.assertNotEqual(result.returncode, 0)
        self.assert_unchanged()
        self.assertEqual(self.git("show", ":.sops.yaml").decode(), CONFIG + "# user edit\n")
        self.assertEqual(self.git("rev-parse", "HEAD"), head)

    def test_commit_excludes_other_changes(self):
        other = self.repo / "other.txt"
        other.write_text("staged work\n")
        self.git("add", "other.txt")
        other.write_text("unstaged work\n")
        staged = self.git("diff", "--cached", "--binary")
        unstaged = self.git("diff", "--binary", "--", "other.txt")
        result = self.run_enroll("syd")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"), b".sops.yaml\n")
        self.assertEqual(self.git("diff", "--cached", "--binary"), staged)
        self.assertEqual(self.git("diff", "--binary", "--", "other.txt"), unstaged)
        self.assertEqual(other.read_text(), "unstaged work\n")

    def test_commit_failure_keeps_diff(self):
        hook = self.repo / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\necho 'fixture: commit rejected' >&2\nexit 1\n")
        hook.chmod(0o700)
        other = self.repo / "other.txt"
        other.write_text("staged work\n")
        self.git("add", "other.txt")
        staged = self.git("diff", "--cached", "--binary")
        head = self.git("rev-parse", "HEAD")
        result = self.run_enroll("syd")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture: commit rejected", result.stderr)
        self.assertIn("+  - &syd age1", result.stdout)
        self.assertTrue((self.root / "remote/linux/key.txt").exists())
        self.assertIn("&syd age1", self.config.read_text())
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual(self.git("diff", "--cached", "--binary"), staged)

    def test_not_a_git_repository(self):
        (self.repo / ".git").rename(self.root / "saved-git")
        result = self.run_enroll("syd")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not a git repository", result.stderr.lower())
        self.assertFalse((self.root / "calls").exists())
        self.assert_unchanged()

    def test_untracked_config(self):
        self.git("rm", "--cached", ".sops.yaml")
        result = self.run_enroll("syd")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("commit .sops.yaml first", result.stderr)
        self.assertFalse((self.root / "calls").exists())
        self.assert_unchanged()

    def test_keygen_failure(self):
        self.driver.write_text(self.driver.read_text().replace(
            "ss_enroll $argv", "function age-keygen; return 37; end\nss_enroll $argv"
        ))
        self.assertEqual(self.run_enroll("syd").returncode, 37)
        self.assert_unchanged()

    def test_invalid_config_not_installed(self):
        self.config.write_text("keys:\n")
        self.git("add", ".sops.yaml")
        self.git("-c", "user.name=test", "-c", "user.email=test@example.org",
                 "-c", "commit.gpgSign=false", "commit", "-qm", "invalid config")
        result = self.run_enroll("syd")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot patch", result.stderr)
        self.assertFalse((self.root / "remote/linux").exists())

    def test_guards_do_not_connect(self):
        (self.repo / "hosts/not-a-host").mkdir()
        for args in ((), ("syd", "extra"), ("missing",), ("../syd",), ("syd/../syd",), ("not-a-host",)):
            with self.subTest(args=args):
                self.assertNotEqual(self.run_enroll(*args).returncode, 0)
        self.host.write_text("{}\n")
        self.config.write_text(CONFIG + "# user edit\n")
        self.assertNotEqual(self.run_enroll("syd").returncode, 0)
        self.git("add", ".sops.yaml")
        self.assertNotEqual(self.run_enroll("syd").returncode, 0)
        self.assertEqual(self.config.read_text(), CONFIG + "# user edit\n")
        self.config.write_text(CONFIG)
        self.assertNotEqual(self.run_enroll("syd").returncode, 0)
        self.assert_unchanged()
        self.assertFalse((self.root / "calls").exists())


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ("ssh", "scp", "install", "uname", "sudo"):
        sys.exit(mock(sys.argv[1], sys.argv[2:]))
    unittest.main()

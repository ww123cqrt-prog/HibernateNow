"""Exercise setup/rollback in a temporary directory without administrator access."""
from pathlib import Path
import os
import subprocess
import tempfile

project = Path(__file__).resolve().parent.parent
expected = (project / ".build/passwordless-rule-check").read_bytes()

with tempfile.TemporaryDirectory(prefix="power-access-check-") as temporary:
    test_root = Path(temporary)
    directory = test_root / "sudoers.d"
    directory.mkdir()
    rule = directory / "cq-hibernatenow-501"
    main = test_root / "sudoers"
    main.write_text("#includedir /private/etc/sudoers.d\n")
    counter = test_root / "validation-count"
    stat = test_root / "stat"
    stat.write_text("#!/bin/sh\nprintf '%s\\n' '0:0:755'\n")
    visudo = test_root / "visudo"
    visudo.write_text(f"""#!/bin/sh
if [ "$#" -gt 1 ]; then exec /usr/sbin/visudo "$@"; fi
count=0
if [ -f '{counter}' ]; then count=$(cat '{counter}'); fi
count=$((count+1))
printf '%s' "$count" > '{counter}'
if [ "${{FAIL_FINAL_VALIDATION:-0}}" = 1 ] && [ "$count" -eq 2 ]; then exit 1; fi
""")
    stat.chmod(0o755)
    visudo.chmod(0o755)

    def execute(enable, fail=False):
        counter.unlink(missing_ok=True)
        script = (project / f".build/passwordless-{'enable' if enable else 'disable'}-check.sh").read_text()
        # Only test fixtures replace privileged paths/owner checks; production stays fixed.
        script = script.replace("directory='/private/etc/sudoers.d'", f"directory='{directory}'")
        script = script.replace("rule='/private/etc/sudoers.d/cq-hibernatenow-501'", f"rule='{rule}'")
        script = script.replace(" /private/etc/sudoers;", f" '{main}';")
        script = script.replace("/usr/bin/stat", str(stat))
        script = script.replace("/usr/sbin/chown", "/usr/bin/true")
        script = script.replace("/usr/sbin/visudo", str(visudo))
        result = subprocess.run(["/bin/sh"], input=script, text=True, capture_output=True,
                                env={**os.environ, "FAIL_FINAL_VALIDATION": "1" if fail else "0"})
        return result.returncode

    assert execute(True) == 0 and rule.read_bytes() == expected
    assert rule.stat().st_mode & 0o777 == 0o440
    previous = b"# prior configuration retained by rollback\n"
    rule.chmod(0o600)
    rule.write_bytes(previous)
    rule.chmod(0o440)
    assert execute(True, fail=True) != 0 and rule.read_bytes() == previous
    assert rule.stat().st_mode & 0o777 == 0o440
    assert execute(False, fail=True) != 0 and rule.read_bytes() == previous
    assert execute(False) == 0 and not rule.exists()
    assert execute(False) == 0 and not rule.exists()
    assert execute(True, fail=True) != 0 and not rule.exists()
    victim = test_root / "unrelated-file"
    victim.write_text("untouched")
    rule.symlink_to(victim)
    assert execute(True) != 0 and rule.is_symlink() and victim.read_text() == "untouched"
    assert execute(False) != 0 and rule.is_symlink() and victim.read_text() == "untouched"
    assert sorted(p.name for p in directory.iterdir()) == [rule.name]

print("passwordless setup and rollback checks passed (temporary directory)")

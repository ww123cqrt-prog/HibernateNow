"""Create a UTF-8 app ZIP, relative-path provenance record, and SHA-256 checksums."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import platform
import plistlib
import stat
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def main():
    app, dmg = map(Path, sys.argv[1:])
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    version = (ROOT / "VERSION").read_text().strip()
    assert info["CFBundleShortVersionString"] == version
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    archive = dmg.with_suffix(".zip")
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zipped:
        for path in [app, *sorted(app.rglob("*"))]:
            name = str(path.relative_to(app.parent))
            if path.is_symlink():
                entry = zipfile.ZipInfo(name)
                entry.create_system = 3
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                zipped.writestr(entry, os.readlink(path))
            else:
                zipped.write(path, name)
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None

    tracked = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True).stdout
    sources = [Path(os.fsdecode(p)) for p in tracked.split(b"\0") if p]
    assert sources, "Stage the intended source files before recording a release"
    commit = subprocess.run(["git", "rev-parse", "--verify", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    clean = not command("git", "status", "--porcelain")
    record = {
        "version": version,
        "build": info["CFBundleVersion"],
        "bundle_id": info["CFBundleIdentifier"],
        "minimum_macos": info["LSMinimumSystemVersion"],
        "architecture": command("/usr/bin/lipo", "-archs", str(app / "Contents/MacOS/HibernateNow")),
        "signing": "ad-hoc",
        "notarized": False,
        "source_commit": commit.stdout.strip() if commit.returncode == 0 else None,
        "source_tree_clean": clean,
        "source_sha256": {str(p): digest(ROOT / p) for p in sources},
        "binary_sha256": digest(app / "Contents/MacOS/HibernateNow"),
        "dock_icon_sha256": {
            mode: digest(app / f"Contents/Resources/DockIcons/{mode}.icns")
            for mode in ["hibernate", "sleep", "keepRunning"]
        },
        "assets_sha256": {p.name: digest(p) for p in [dmg, archive]},
        "build_command": "./script/package_release.sh",
        "swift": command("swift", "--version"),
        "sdk_version": command("xcrun", "--show-sdk-version"),
        "build_macos": platform.mac_ver()[0],
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    manifest = dmg.parent / "release-manifest.json"
    manifest.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    (dmg.parent / "SHA256SUMS.txt").write_text(
        "".join(f"{digest(p)}  {p.name}\n" for p in [dmg, archive, manifest])
    )


if __name__ == "__main__":
    main()

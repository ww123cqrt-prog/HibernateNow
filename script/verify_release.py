"""Verify release contents by mounting the DMG read-only. Never run pmset writes."""
from pathlib import Path
import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    manifest = json.loads((DIST / "release-manifest.json").read_text())
    for name, expected in manifest["assets_sha256"].items():
        assert digest((DIST / name).read_bytes()) == expected, name
    for line in (DIST / "SHA256SUMS.txt").read_text().splitlines():
        expected, name = line.split("  ", 1)
        assert digest((DIST / name).read_bytes()) == expected, name
    for name, expected in manifest["source_sha256"].items():
        assert digest((ROOT / name).read_bytes()) == expected, name
    if manifest["source_commit"]:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        assert manifest["source_commit"] == head

    archive = next(DIST / name for name in manifest["assets_sha256"] if name.endswith(".zip"))
    binary_name = "电源管理.app/Contents/MacOS/HibernateNow"
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None
        binary_data = zipped.read(binary_name)
        assert digest(binary_data) == manifest["binary_sha256"]
        assert b"/Users/" not in binary_data and b"/var/folders/" not in binary_data
        assert (zipped.getinfo(binary_name).external_attr >> 16) & 0o111
        for mode, expected in manifest["dock_icon_sha256"].items():
            assert digest(zipped.read(f"电源管理.app/Contents/Resources/DockIcons/{mode}.icns")) == expected

    dmg = next(DIST / name for name in manifest["assets_sha256"] if name.endswith(".dmg"))
    subprocess.run(["/usr/bin/hdiutil", "verify", "-quiet", str(dmg)], check=True)
    with tempfile.TemporaryDirectory(prefix="verify-release-", dir=ROOT / ".build") as temporary:
        mount = Path(temporary) / "volume"
        mount.mkdir()
        subprocess.run(["/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-quiet",
                        "-mountpoint", str(mount), str(dmg)], check=True)
        try:
            app = mount / "电源管理.app"
            assert os.readlink(mount / "Applications") == "/Applications"
            assert (mount / "LICENSE.txt").read_bytes() == (ROOT / "LICENSE").read_bytes()
            assert (mount / "安装说明.txt").is_file()
            subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
            info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            assert info["CFBundleShortVersionString"] == manifest["version"]
            assert info["CFBundleIdentifier"] == manifest["bundle_id"]
            binary = app / "Contents/MacOS/HibernateNow"
            assert digest(binary.read_bytes()) == manifest["binary_sha256"]
            assert os.access(binary, os.X_OK)
            for mode, expected in manifest["dock_icon_sha256"].items():
                assert digest((app / f"Contents/Resources/DockIcons/{mode}.icns").read_bytes()) == expected
        finally:
            subprocess.run(["/usr/bin/hdiutil", "detach", "-quiet", str(mount)], check=True)
    print("Release checks passed: DMG mount, native signature, app ZIP, source identity, icons, checksums.")


if __name__ == "__main__":
    main()

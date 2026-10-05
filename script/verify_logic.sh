#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/.build"
cd "$ROOT_DIR"
swiftc -parse-as-library \
  "$ROOT_DIR/Sources/HibernateNow/Models/LidMode.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Models/PowerSnapshot.swift" \
  "$ROOT_DIR/Tests/PowerSnapshotChecks.swift" \
  -o "$ROOT_DIR/.build/PowerSnapshotChecks"
"$ROOT_DIR/.build/PowerSnapshotChecks"

swiftc -parse-as-library \
  "$ROOT_DIR/Sources/HibernateNow/Models/LidMode.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Models/PowerSnapshot.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PasswordlessPowerAccess.swift" \
  "$ROOT_DIR/Tests/PasswordlessPowerAccessChecks.swift" \
  -o "$ROOT_DIR/.build/PasswordlessPowerAccessChecks"
"$ROOT_DIR/.build/PasswordlessPowerAccessChecks"
/usr/sbin/visudo -c -f "$ROOT_DIR/.build/passwordless-rule-check"
/bin/sh -n "$ROOT_DIR/.build/passwordless-enable-check.sh"
/bin/sh -n "$ROOT_DIR/.build/passwordless-disable-check.sh"
python3 "$ROOT_DIR/Tests/PasswordlessSetupChecks.py"

swiftc -parse-as-library \
  "$ROOT_DIR/Sources/HibernateNow/Models/LidMode.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Models/PowerSnapshot.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PowerSettingsClient.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PasswordlessPowerAccess.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PrivilegedPowerControl.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PowerManager.swift" \
  "$ROOT_DIR/Tests/PowerManagerChecks.swift" \
  -o "$ROOT_DIR/.build/PowerManagerChecks"
"$ROOT_DIR/.build/PowerManagerChecks"

swiftc -parse-as-library \
  "$ROOT_DIR/Sources/HibernateNow/Models/LidMode.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Models/PowerSnapshot.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PowerSettingsClient.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PasswordlessPowerAccess.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PrivilegedPowerControl.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PowerManager.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/DockIconController.swift" \
  "$ROOT_DIR/Sources/HibernateNow/App/AppDelegate.swift" \
  "$ROOT_DIR/Tests/DockMenuChecks.swift" \
  -o "$ROOT_DIR/.build/DockMenuChecks"
"$ROOT_DIR/.build/DockMenuChecks"

swiftc -parse-as-library \
  "$ROOT_DIR/Sources/HibernateNow/Models/LidMode.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Models/PowerSnapshot.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PowerSettingsClient.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PasswordlessPowerAccess.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PrivilegedPowerControl.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/PowerManager.swift" \
  "$ROOT_DIR/Sources/HibernateNow/Services/DockIconController.swift" \
  "$ROOT_DIR/Tests/DockIconChecks.swift" \
  -o "$ROOT_DIR/.build/DockIconChecks"
"$ROOT_DIR/.build/DockIconChecks"

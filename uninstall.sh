#!/bin/bash

set -euo pipefail
umask 077

SUPPORT_DIR="/Library/Application Support/IronTurkeyLocker"
LAUNCH_DAEMONS_DIR="/Library/LaunchDaemons"
APP_DST="/Applications/Iron Turkey Locker.app"
GUARD_PLIST="com.ironturkey.locker.guard.plist"
RESTORE_PLIST="com.ironturkey.locker.restore.plist"
LEGACY_SUPPORT_DIR="/Library/Application Support/FrozenTurkeyLocker"
LEGACY_APP_DST="/Applications/Frozen Turkey Locker.app"
LEGACY_GUARD_PLIST="com.frozenturkey.locker.guard.plist"
LEGACY_RESTORE_PLIST="com.frozenturkey.locker.restore.plist"
COLD_TURKEY_DIR="/Library/Application Support/Cold Turkey"
LEGACY_TMP_DIRS=(
    "$COLD_TURKEY_DIR/.frozenturkey-guard-tmp"
    "$COLD_TURKEY_DIR/.frozenturkey-admin-lock-tmp"
    "$COLD_TURKEY_DIR/.ironturkey-guard-tmp"
    "$COLD_TURKEY_DIR/.ironturkey-admin-lock-tmp"
)

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Run as root: sudo ./uninstall.sh" >&2
    exit 1
fi

launchctl bootout system "$LAUNCH_DAEMONS_DIR/$GUARD_PLIST" 2>/dev/null || true
launchctl bootout system "$LAUNCH_DAEMONS_DIR/$RESTORE_PLIST" 2>/dev/null || true
launchctl bootout system "$LAUNCH_DAEMONS_DIR/$LEGACY_GUARD_PLIST" 2>/dev/null || true
launchctl bootout system "$LAUNCH_DAEMONS_DIR/$LEGACY_RESTORE_PLIST" 2>/dev/null || true

rm -f "$LAUNCH_DAEMONS_DIR/$GUARD_PLIST" "$LAUNCH_DAEMONS_DIR/$RESTORE_PLIST"
rm -f "$LAUNCH_DAEMONS_DIR/$LEGACY_GUARD_PLIST" "$LAUNCH_DAEMONS_DIR/$LEGACY_RESTORE_PLIST"
rm -rf "$SUPPORT_DIR" "$APP_DST" "$LEGACY_SUPPORT_DIR" "$LEGACY_APP_DST"
rm -rf "${LEGACY_TMP_DIRS[@]}"

echo "Uninstalled Iron Turkey Locker."

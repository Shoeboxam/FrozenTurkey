#!/bin/bash

set -euo pipefail

ACTIVE_DIR="/Library/Application Support/Cold Turkey"
ACTIVE_DB="$ACTIVE_DIR/data-app.db"
ACTIVE_BROWSER_DB="$ACTIVE_DIR/data-browser.db"
ACTIVE_HELPER_DB="$ACTIVE_DIR/data-helper.db"
ACTIVE_WAL="$ACTIVE_DIR/data-app.db-wal"
ACTIVE_SHM="$ACTIVE_DIR/data-app.db-shm"

CT_AGENT="/Applications/Cold Turkey Blocker.app/Contents/MacOS/Cold Turkey Blocker -agent"

ENFORCER_DIR="/Library/Application Support/FrozenTurkeyLocker"
STATE_DIR="$ENFORCER_DIR/state"
MODE_FILE="$STATE_DIR/mode"
HASH_FILE="$STATE_DIR/last_hash"
COMPARE_OUT="$STATE_DIR/compare.out"
STATS_COMPARE_OUT="$STATE_DIR/stats_compare.out"
LOG_DIR="$ENFORCER_DIR/logs"
GOLD_DIR="$ENFORCER_DIR/gold"
GOLD_DB="$GOLD_DIR/data-app.db"
GOLD_BROWSER_DB="$GOLD_DIR/data-browser.db"
GOLD_HELPER_DB="$GOLD_DIR/data-helper.db"

ct_agent_running() {
    pgrep -f "$CT_AGENT" >/dev/null 2>&1
}

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log_line() {
    local log_file="$1"
    shift
    printf '[%s] %s\n' "$(timestamp)" "$*" >> "$log_file"
}

mode() {
    if [ -f "$MODE_FILE" ]; then
        cat "$MODE_FILE"
    else
        printf 'locked'
    fi
}

set_mode() {
    local new_mode="$1"
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$new_mode" > "$MODE_FILE"
}

raw_hash() {
    python3 - <<'PY' "$ACTIVE_DB"
import hashlib, sqlite3, sys
db_path = sys.argv[1]
conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
try:
    raw = conn.execute("SELECT value FROM settings WHERE key='settings'").fetchone()[0]
finally:
    conn.close()
print(hashlib.sha256(raw.encode()).hexdigest())
PY
}

file_signature() {
    local path="$1"
    if [ ! -e "$path" ]; then
        printf 'missing'
        return 0
    fi
    if stat -f '%m:%z' "$path" >/dev/null 2>&1; then
        stat -f '%m:%z' "$path"
    else
        stat -c '%Y:%s' "$path"
    fi
}

state_signature() {
    local app_hash
    app_hash="$(raw_hash 2>/dev/null || printf 'unreadable')"
    printf 'app-settings:%s\n' "$app_hash"
    printf 'browser:%s\n' "$(file_signature "$ACTIVE_BROWSER_DB")"
    printf 'helper:%s\n' "$(file_signature "$ACTIVE_HELPER_DB")"
}

stop_cold_turkey() {
    pkill -f "$CT_AGENT" 2>/dev/null || true

    local timeout=20
    while pgrep -f "$CT_AGENT" >/dev/null 2>&1; do
        pkill -f "$CT_AGENT" 2>/dev/null || true
        sleep 1
        timeout=$((timeout - 1))
        if [ "$timeout" -le 0 ]; then
            return 1
        fi
    done
}

sqlite_integrity_ok() {
    local db="$1"
    sqlite3 "$db" 'PRAGMA integrity_check;' | grep -qx 'ok'
}

remove_sqlite_sidecars() {
    local db="$1"
    rm -f "$db-wal" "$db-shm"
}

restore_one_gold_into_active() {
    local gold_db="$1"
    local active_db="$2"
    local tmp_db="$3"

    [ -f "$gold_db" ] || return 0
    sqlite_integrity_ok "$gold_db" || return 1
    rm -f "$tmp_db"
    remove_sqlite_sidecars "$active_db"
    cp "$gold_db" "$tmp_db"
    sqlite_integrity_ok "$tmp_db" || return 1
    mv -f "$tmp_db" "$active_db"
    remove_sqlite_sidecars "$active_db"
    chown root:admin "$active_db" 2>/dev/null || true
    chmod 666 "$active_db" 2>/dev/null || true
}

backup_active_to_gold() {
    local active_db="$1"
    local gold_db="$2"
    local tmp_gold="$3"

    [ -f "$active_db" ] || return 0
    sqlite_integrity_ok "$active_db" || return 1
    rm -f "$tmp_gold"
    python3 - <<'PY' "$active_db" "$tmp_gold"
import sqlite3
import sys

src_path, dst_path = sys.argv[1], sys.argv[2]
src = sqlite3.connect(f"file:{src_path}?mode=ro", uri=True)
dst = sqlite3.connect(dst_path)
try:
    src.backup(dst)
finally:
    dst.close()
    src.close()
PY
    sqlite_integrity_ok "$tmp_gold" || return 1
    mv -f "$tmp_gold" "$gold_db"
    chown root:wheel "$gold_db" 2>/dev/null || true
    chmod 600 "$gold_db" 2>/dev/null || true
}

restore_gold_state_into_active() {
    local tmp_dir="$1"

    [ -f "$GOLD_DB" ] || return 1
    [ -f "$ACTIVE_DB" ] || return 1

    mkdir -p "$tmp_dir"
    stop_cold_turkey || return 1
    restore_one_gold_into_active "$GOLD_DB" "$ACTIVE_DB" "$tmp_dir/data-app.db.tmp" || return 1
    restore_one_gold_into_active "$GOLD_BROWSER_DB" "$ACTIVE_BROWSER_DB" "$tmp_dir/data-browser.db.tmp" || return 1
    restore_one_gold_into_active "$GOLD_HELPER_DB" "$ACTIVE_HELPER_DB" "$tmp_dir/data-helper.db.tmp" || return 1
    state_signature > "$HASH_FILE"
}

promote_active_state_to_gold() {
    local tmp_dir="$1"

    mkdir -p "$tmp_dir" "$GOLD_DIR"
    backup_active_to_gold "$ACTIVE_DB" "$GOLD_DB" "$tmp_dir/data-app.db.tmp" || return 1
    backup_active_to_gold "$ACTIVE_BROWSER_DB" "$GOLD_BROWSER_DB" "$tmp_dir/data-browser.db.tmp" || return 1
    backup_active_to_gold "$ACTIVE_HELPER_DB" "$GOLD_HELPER_DB" "$tmp_dir/data-helper.db.tmp" || return 1
    state_signature > "$HASH_FILE"
}

# Backwards-compatible wrappers used by older scripts.
restore_gold_into_active() {
    local tmp_db="$1"
    restore_gold_state_into_active "$(dirname "$tmp_db")"
}

promote_active_to_gold() {
    local tmp_gold="$1"
    promote_active_state_to_gold "$(dirname "$tmp_gold")"
}

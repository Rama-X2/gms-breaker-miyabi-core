#!/system/bin/sh
# ==============================================================================
# GMS Breaker Miyabi Core v3.0.0 - Watchdog Daemon
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core
# ==============================================================================

MODDIR="${0%/*}"
export MODDIR

(
  # Wait for Android boot completion
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
  done

  # Load core runtime library
  if [ ! -f "$MODDIR/core.sh" ]; then
    exit 1
  fi
  # shellcheck disable=SC1091
  . "$MODDIR/core.sh"

  ensure_state_dir
  load_config

  # Prevent duplicate watchdog instances
  if [ -f "$PID_FILE" ]; then
    _old_pid=$(cat "$PID_FILE" 2>/dev/null | tr -dc '0-9')
    if [ -n "$_old_pid" ] && [ "$_old_pid" != "$$" ] && kill -0 "$_old_pid" 2>/dev/null; then
      exit 0
    fi
  fi
  echo "$$" > "$PID_FILE" 2>/dev/null

  # Safe post-boot settle delay (prevents MIUI/HyperOS early-boot Binder thread exhaustion)
  _delay="${BOOT_DELAY:-45}"
  [ "$_delay" -lt 15 ] 2>/dev/null && _delay=15
  log_msg "INFO" "GMS Breaker Miyabi Core v3.0.0 Watchdog started (PID=$$). Settling for ${_delay}s..."
  sleep "$_delay"

  # Re-load config after settle in case user interacted during boot
  load_config

  # Self-Healing Boot Reset (configurable via BOOT_SELF_HEAL)
  if [ "$BOOT_SELF_HEAL" -eq 1 ] && [ "$ENABLED" -eq 0 ]; then
    ENABLED=1
    save_config
    log_msg "INFO" "Boot Self-Heal active: auto re-enabled GMS Breaker."
  fi

  # Perform initial single-pass setup (zero rapid-loop force-stop -> zero Zygisk deadlock)
  apply_miyabi_state 1

  # Ultra-Low-Overhead Watchdog Loop (wakes every 60s, ZERO Java/Binder spam)
  while true; do
    sleep 60

    # Sync with legacy flag file if toggled externally by third-party scripts
    load_config
    if [ -f "$LEGACY_FLAG" ] && [ "$ENABLED" -eq 1 ]; then
      ENABLED=0
      save_config
      apply_miyabi_state 0
      continue
    elif [ ! -f "$LEGACY_FLAG" ] && [ "$ENABLED" -eq 0 ]; then
      ENABLED=1
      save_config
      apply_miyabi_state 1
      continue
    fi

    if [ "$ENABLED" -eq 1 ]; then
      # 1. Zero-Java firewall integrity guard (auto-heals if VPN/tethering flushed tables)
      verify_firewall_integrity

      # 2. Screen-Off Smart Deep Doze (ONLY triggers when screen is OFF and NOT charging)
      run_screen_off_doze
    fi
  done
) &

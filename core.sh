#!/system/bin/sh
# ==============================================================================
# GMS Breaker Miyabi Core v3.0.0 - Core Runtime Library
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core
# ==============================================================================

MODDIR="${MODDIR:-/data/adb/modules/gms-breaker-miyabi-core}"
STATE_DIR="/data/adb/miyabi_core"
CONFIG_FILE="$STATE_DIR/config.sh"
LOG_FILE="$STATE_DIR/miyabi.log"
PID_FILE="$STATE_DIR/daemon.pid"
LOCK_DIR="$STATE_DIR/.lock"
UID_CACHE_FILE="$STATE_DIR/blocked_uids.cache"
FW_ENGINE_FILE="$STATE_DIR/fw_engine"
SYSCONFIG_FILE="$STATE_DIR/sysconfig_patched"
LEGACY_FLAG="/data/adb/miyabi_disabled"

# Package Definitions
CORE_PACKAGES="com.google.android.gms com.google.android.gsf com.android.vending"
AUX_PACKAGES="com.google.android.gms.setup com.google.android.feedback com.google.android.partnersetup com.google.android.onetimeinitializer com.google.android.backuptransport com.google.android.syncadapters.contacts com.google.android.syncadapters.calendar com.google.android.projection.gearhead com.google.android.apps.gcs com.google.android.gms.policy_sidecar com.google.android.printservice.recommendation com.google.android.gms.location.history"
ALL_PACKAGES="$CORE_PACKAGES $AUX_PACKAGES"

# AppOps Profiles (Never uses 'cmd appops reset' to keep MIUI/HyperOS 100% safe)
ALL_APPOPS="RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK START_FOREGROUND ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION GET_USAGE_STATS SYSTEM_ALERT_WINDOW WRITE_SETTINGS"
BALANCED_APPOPS="RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION GET_USAGE_STATS WRITE_SETTINGS"
DOZE_CORE_APPOPS="GET_USAGE_STATS WRITE_SETTINGS"

# Strictly Safe Telemetry-Only GMS Sub-Components (Zero impact on FCM, OAuth, Play Integrity, Chimera core)
SAFE_TELEMETRY_COMPONENTS="
com.google.android.gms/.analytics.AnalyticsService
com.google.android.gms/.analytics.AnalyticsTaskService
com.google.android.gms/.analytics.internal.PlayLogReportingService
com.google.android.gms/.measurement.PackageMeasurementService
com.google.android.gms/.measurement.PackageMeasurementTaskService
com.google.android.gms/.measurement.PackageMeasurementReceiver
com.google.android.gms/.stats.PlatformStatsCollectorService
com.google.android.gms/.usagereporting.service.UsageReportingService
com.google.android.gms/.tron.CollectionService
com.google.android.gms/.clearcut.debug.ClearcutDebugDumpService
com.google.android.gms/.ads.identifier.service.AdvertisingIdService
com.google.android.gms/.ads.measurement.GmpConversionTrackingBrokerService
"

# Ensure state directory exists
ensure_state_dir() {
  [ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR" 2>/dev/null
}

# Portable millisecond pacing sleep (avoids float sleep errors on legacy toybox/busybox)
safe_sleep_ms() {
  _ms="$1"
  [ -z "$_ms" ] && return 0
  if command -v usleep >/dev/null 2>&1; then
    usleep $((_ms * 1000)) 2>/dev/null && return 0
  fi
  case "$_ms" in
    50)  sleep 0.05 2>/dev/null && return 0 ;;
    100) sleep 0.1  2>/dev/null && return 0 ;;
    150) sleep 0.15 2>/dev/null && return 0 ;;
    200) sleep 0.2  2>/dev/null && return 0 ;;
    500) sleep 0.5  2>/dev/null && return 0 ;;
    *)   sleep 1    2>/dev/null && return 0 ;;
  esac
  return 0
}

# Lightweight Logger with automatic size rotation (max ~200 lines)
log_msg() {
  ensure_state_dir
  _lvl="$1"
  shift
  _ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "0000-00-00 00:00:00")
  echo "[$_ts] [$_lvl] $*" >> "$LOG_FILE" 2>/dev/null
  if [ -f "$LOG_FILE" ]; then
    _lines=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -dc '0-9')
    if [ -n "$_lines" ] && [ "$_lines" -gt 300 ] 2>/dev/null; then
      tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv -f "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
    fi
  fi
}

# Load Persistent Configuration with Safe Defaults
load_config() {
  ensure_state_dir
  ENABLED=1
  MODE="extreme"
  FIREWALL=1
  SMART_DOZE=1
  TELEMETRY_MUTE=1
  BOOT_SELF_HEAL=1
  LIVE_DESC=1
  BOOT_DELAY=45
  EXCLUDE_VENDING=0
  CUSTOM_EXCLUDE=""

  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE" 2>/dev/null
  else
    save_config
  fi

  # Sanitize values
  case "$MODE" in
    doze|balanced|extreme) ;;
    *) MODE="extreme" ;;
  esac
  case "$ENABLED" in 0|1) ;; *) ENABLED=1 ;; esac
  case "$FIREWALL" in 0|1) ;; *) FIREWALL=1 ;; esac
  case "$SMART_DOZE" in 0|1) ;; *) SMART_DOZE=1 ;; esac
  case "$TELEMETRY_MUTE" in 0|1) ;; *) TELEMETRY_MUTE=1 ;; esac
  case "$BOOT_SELF_HEAL" in 0|1) ;; *) BOOT_SELF_HEAL=1 ;; esac
  case "$LIVE_DESC" in 0|1) ;; *) LIVE_DESC=1 ;; esac
  case "$EXCLUDE_VENDING" in 0|1) ;; *) EXCLUDE_VENDING=0 ;; esac
  case "$BOOT_DELAY" in ''|*[!0-9]*) BOOT_DELAY=45 ;; esac
}

# Atomic Save Configuration
save_config() {
  ensure_state_dir
  cat <<EOF > "$CONFIG_FILE.tmp" 2>/dev/null
# GMS Breaker Miyabi Core v3.0.0 Configuration
ENABLED=$ENABLED
MODE="$MODE"
FIREWALL=$FIREWALL
SMART_DOZE=$SMART_DOZE
TELEMETRY_MUTE=$TELEMETRY_MUTE
BOOT_SELF_HEAL=$BOOT_SELF_HEAL
LIVE_DESC=$LIVE_DESC
BOOT_DELAY=$BOOT_DELAY
EXCLUDE_VENDING=$EXCLUDE_VENDING
CUSTOM_EXCLUDE="$CUSTOM_EXCLUDE"
EOF
  mv -f "$CONFIG_FILE.tmp" "$CONFIG_FILE" 2>/dev/null
  chmod 0644 "$CONFIG_FILE" 2>/dev/null

  # Keep legacy flag in sync for backwards compatibility
  if [ "$ENABLED" -eq 0 ]; then
    touch "$LEGACY_FLAG" 2>/dev/null
  else
    rm -f "$LEGACY_FLAG" 2>/dev/null
  fi
}

# Atomic Directory Lock (prevents race conditions between WebUI, CLI, Action, and Watchdog)
acquire_lock() {
  ensure_state_dir
  _tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [ -f "$LOCK_DIR/pid" ]; then
      _lpid=$(cat "$LOCK_DIR/pid" 2>/dev/null)
      if [ -n "$_lpid" ] && ! kill -0 "$_lpid" 2>/dev/null; then
        rm -rf "$LOCK_DIR" 2>/dev/null
        continue
      fi
    fi
    _tries=$((_tries + 1))
    if [ "$_tries" -ge 40 ]; then
      rm -rf "$LOCK_DIR" 2>/dev/null
      mkdir "$LOCK_DIR" 2>/dev/null
      break
    fi
    safe_sleep_ms 500
  done
  echo "$$" > "$LOCK_DIR/pid" 2>/dev/null
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null
}

# Detect iptables xtables wait lock support (-w) to prevent conflict with Clash/VPN/AFWall
init_ipt_cmds() {
  IPT="iptables"
  IP6T="ip6tables"
  if command -v iptables >/dev/null 2>&1; then
    iptables -w -L OUTPUT -n >/dev/null 2>&1 && IPT="iptables -w"
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -w -L OUTPUT -n >/dev/null 2>&1 && IP6T="ip6tables -w"
  fi
}

# Detect Android SDK Level
get_sdk_level() {
  _sdk=$(getprop ro.build.version.sdk 2>/dev/null | tr -dc '0-9')
  if [ -z "$_sdk" ]; then
    echo "30"
  else
    echo "$_sdk"
  fi
}

# Detect Root Manager
detect_root_manager() {
  if [ -d "/data/adb/ksu" ] || [ -n "$KSU" ]; then
    _kver=""
    [ -x "/data/adb/ksu/bin/ksud" ] && _kver=$(/data/adb/ksu/bin/ksud -V 2>/dev/null | head -n 1)
    if [ -n "$_kver" ]; then
      echo "KernelSU ($_kver)"
    else
      echo "KernelSU"
    fi
  elif [ -d "/data/adb/ap" ] || [ -d "/data/adb/apatch" ] || [ -n "$APATCH" ]; then
    _aver=""
    [ -x "/data/adb/ap/bin/apd" ] && _aver=$(/data/adb/ap/bin/apd -V 2>/dev/null | head -n 1)
    if [ -n "$_aver" ]; then
      echo "APatch ($_aver)"
    else
      echo "APatch"
    fi
  elif [ -d "/data/adb/magisk" ] || command -v magisk >/dev/null 2>&1; then
    _mver=$(magisk -v 2>/dev/null | cut -d':' -f1)
    if [ -n "$_mver" ]; then
      echo "Magisk ($_mver)"
    else
      echo "Magisk"
    fi
  else
    echo "Unknown Root"
  fi
}

# Get all active Android User IDs (Owner 0, Work Profile, Dual Apps / 999, etc.)
get_users() {
  _users=$(pm list users 2>/dev/null | grep "UserInfo{" | cut -d'{' -f2 | cut -d':' -f1 | tr -d '\r')
  if [ -z "$_users" ]; then
    echo "0"
  else
    echo "$_users"
  fi
}

# Add or remove a package from CUSTOM_EXCLUDE list
set_pkg_exclude() {
  _target="$1"
  _state="$2" # 1 = exclude, 0 = include
  load_config
  if [ "$_target" = "com.android.vending" ]; then
    EXCLUDE_VENDING="$_state"
  fi
  _new_list=""
  _norm=$(echo "$CUSTOM_EXCLUDE" | tr ',' ' ')
  for _item in $_norm; do
    [ -z "$_item" ] && continue
    [ "$_item" = "$_target" ] && continue
    if [ -z "$_new_list" ]; then
      _new_list="$_item"
    else
      _new_list="$_new_list $_item"
    fi
  done
  if [ "$_state" -eq 1 ] && [ "$_target" != "com.android.vending" ]; then
    if [ -z "$_new_list" ]; then
      _new_list="$_target"
    else
      _new_list="$_new_list $_target"
    fi
  fi
  CUSTOM_EXCLUDE="$_new_list"
  save_config
}

# Check if package is excluded by user config
is_pkg_excluded() {
  _pkg="$1"
  if [ "$EXCLUDE_VENDING" -eq 1 ] && [ "$_pkg" = "com.android.vending" ]; then
    return 0
  fi
  if [ -n "$CUSTOM_EXCLUDE" ]; then
    _norm=$(echo "$CUSTOM_EXCLUDE" | tr ',' ' ')
    for _ex in $_norm; do
      if [ "$_ex" = "$_pkg" ]; then
        return 0
      fi
    done
  fi
  return 1
}

# Ultra-Fast Zero-Binder AppId Lookup from /data/system/packages.list (with single-call cmd fallback)
_PKG_LIST_CACHE=""
prepare_pkg_cache() {
  if [ ! -r "/data/system/packages.list" ]; then
    _PKG_LIST_CACHE=$(cmd package list packages -U 2>/dev/null || pm list packages -U 2>/dev/null)
  fi
}

get_pkg_appid() {
  _pkg="$1"
  _aid=""
  if [ -r "/data/system/packages.list" ]; then
    if command -v awk >/dev/null 2>&1; then
      _aid=$(awk -v p="$_pkg" '$1 == p { print $2; exit }' /data/system/packages.list 2>/dev/null)
    else
      _aid=$(grep -m1 "^${_pkg} " /data/system/packages.list 2>/dev/null | cut -d' ' -f2)
    fi
  else
    [ -z "$_PKG_LIST_CACHE" ] && prepare_pkg_cache
    _aid=$(printf '%s\n' "$_PKG_LIST_CACHE" | grep -E "^package:${_pkg}($|[[:space:]])" | head -n 1 | grep -oE "uid:[0-9]+" | cut -d':' -f2)
  fi
  _aid=$(printf '%s' "$_aid" | tr -dc '0-9')
  printf '%s' "$_aid"
}

# Resolve installed packages into INSTALLED_CORE, INSTALLED_AUX, INSTALLED_ALL, and UIDs
resolve_environment() {
  USER_IDS=$(get_users)
  prepare_pkg_cache

  INSTALLED_CORE=""
  INSTALLED_AUX=""
  INSTALLED_ALL=""
  ACTIVE_TARGET_PKGS=""
  EXCLUDED_INSTALLED_PKGS=""
  TARGET_UIDS=""
  ALL_GOOGLE_UIDS=""

  for _p in $CORE_PACKAGES; do
    _aid=$(get_pkg_appid "$_p")
    if [ -n "$_aid" ]; then
      INSTALLED_CORE="$INSTALLED_CORE $_p"
      INSTALLED_ALL="$INSTALLED_ALL $_p"
      for _u in $USER_IDS; do
        _uid=$((_u * 100000 + _aid))
        case " $ALL_GOOGLE_UIDS " in
          *" $_uid "*) ;;
          *) ALL_GOOGLE_UIDS="$ALL_GOOGLE_UIDS $_uid" ;;
        esac
        if ! is_pkg_excluded "$_p"; then
          case " $TARGET_UIDS " in
            *" $_uid "*) ;;
            *) TARGET_UIDS="$TARGET_UIDS $_uid" ;;
          esac
        fi
      done
      if is_pkg_excluded "$_p"; then
        EXCLUDED_INSTALLED_PKGS="$EXCLUDED_INSTALLED_PKGS $_p"
      else
        ACTIVE_TARGET_PKGS="$ACTIVE_TARGET_PKGS $_p"
      fi
    fi
  done

  for _p in $AUX_PACKAGES; do
    _aid=$(get_pkg_appid "$_p")
    if [ -n "$_aid" ]; then
      INSTALLED_AUX="$INSTALLED_AUX $_p"
      INSTALLED_ALL="$INSTALLED_ALL $_p"
      for _u in $USER_IDS; do
        _uid=$((_u * 100000 + _aid))
        case " $ALL_GOOGLE_UIDS " in
          *" $_uid "*) ;;
          *) ALL_GOOGLE_UIDS="$ALL_GOOGLE_UIDS $_uid" ;;
        esac
        if ! is_pkg_excluded "$_p"; then
          case " $TARGET_UIDS " in
            *" $_uid "*) ;;
            *) TARGET_UIDS="$TARGET_UIDS $_uid" ;;
          esac
        fi
      done
      if is_pkg_excluded "$_p"; then
        EXCLUDED_INSTALLED_PKGS="$EXCLUDED_INSTALLED_PKGS $_p"
      else
        ACTIVE_TARGET_PKGS="$ACTIVE_TARGET_PKGS $_p"
      fi
    fi
  done
}

# ==============================================================================
# TRIPLE-LAYER NETWORK ISOLATION ENGINE (nftables -> iptables chain -> netpolicy)
# ==============================================================================

clear_legacy_output_rules() {
  init_ipt_cmds
  _uids="$1"
  for _uid in $_uids; do
    if command -v iptables >/dev/null 2>&1; then
      while $IPT -C OUTPUT -m owner --uid-owner "$_uid" -j DROP 2>/dev/null; do
        $IPT -D OUTPUT -m owner --uid-owner "$_uid" -j DROP 2>/dev/null
      done
    fi
    if command -v ip6tables >/dev/null 2>&1; then
      while $IP6T -C OUTPUT -m owner --uid-owner "$_uid" -j DROP 2>/dev/null; do
        $IP6T -D OUTPUT -m owner --uid-owner "$_uid" -j DROP 2>/dev/null
      done
    fi
  done
}

clear_firewall() {
  init_ipt_cmds
  # Layer A: nftables cleanup
  if command -v nft >/dev/null 2>&1; then
    nft delete table inet miyabi_core 2>/dev/null
  fi
  # Layer B: iptables / ip6tables dedicated MIYABI_BLOCK chain cleanup
  if command -v iptables >/dev/null 2>&1; then
    while $IPT -C OUTPUT -j MIYABI_BLOCK 2>/dev/null; do
      $IPT -D OUTPUT -j MIYABI_BLOCK 2>/dev/null
    done
    $IPT -F MIYABI_BLOCK 2>/dev/null
    $IPT -X MIYABI_BLOCK 2>/dev/null
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    while $IP6T -C OUTPUT -j MIYABI_BLOCK 2>/dev/null; do
      $IP6T -D OUTPUT -j MIYABI_BLOCK 2>/dev/null
    done
    $IP6T -F MIYABI_BLOCK 2>/dev/null
    $IP6T -X MIYABI_BLOCK 2>/dev/null
  fi
  echo "none" > "$FW_ENGINE_FILE" 2>/dev/null
  rm -f "$UID_CACHE_FILE" 2>/dev/null
}

apply_firewall() {
  _uids="$1"
  clear_firewall
  [ -z "$_uids" ] && return 0

  # Priority 1: Native nftables (O(1) inet table, Android 14/15/16 GKI 5.15/6.x native)
  _nft_ok=0
  if command -v nft >/dev/null 2>&1; then
    if nft add table inet miyabi_core 2>/dev/null && \
       nft add chain inet miyabi_core output '{ type filter hook output priority 0; policy accept; }' 2>/dev/null; then
      _nft_ok=1
      for _uid in $_uids; do
        if ! nft add rule inet miyabi_core output meta skuid "$_uid" drop 2>/dev/null; then
          _nft_ok=0
          break
        fi
      done
      if [ "$_nft_ok" -eq 0 ]; then
        nft delete table inet miyabi_core 2>/dev/null
      fi
    fi
  fi

  if [ "$_nft_ok" -eq 1 ]; then
    echo "nftables" > "$FW_ENGINE_FILE" 2>/dev/null
    echo "$_uids" > "$UID_CACHE_FILE" 2>/dev/null
    log_msg "INFO" "Firewall applied via native nftables (inet miyabi_core)."
    return 0
  fi

  # Priority 2: Dedicated iptables + ip6tables custom chain (Zero-conflict with Clash/VPN/AFWall)
  init_ipt_cmds
  _ipt_ok=0
  if command -v iptables >/dev/null 2>&1; then
    $IPT -N MIYABI_BLOCK 2>/dev/null
    $IPT -F MIYABI_BLOCK 2>/dev/null
    if $IPT -I OUTPUT 1 -j MIYABI_BLOCK 2>/dev/null; then
      for _uid in $_uids; do
        $IPT -A MIYABI_BLOCK -m owner --uid-owner "$_uid" -j DROP 2>/dev/null && _ipt_ok=1
      done
    fi
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    $IP6T -N MIYABI_BLOCK 2>/dev/null
    $IP6T -F MIYABI_BLOCK 2>/dev/null
    if $IP6T -I OUTPUT 1 -j MIYABI_BLOCK 2>/dev/null; then
      for _uid in $_uids; do
        $IP6T -A MIYABI_BLOCK -m owner --uid-owner "$_uid" -j DROP 2>/dev/null
      done
    fi
  fi

  if [ "$_ipt_ok" -eq 1 ]; then
    echo "iptables" > "$FW_ENGINE_FILE" 2>/dev/null
    echo "$_uids" > "$UID_CACHE_FILE" 2>/dev/null
    log_msg "INFO" "Firewall applied via dedicated iptables/ip6tables chain (MIYABI_BLOCK)."
  else
    echo "netpolicy" > "$FW_ENGINE_FILE" 2>/dev/null
    echo "$_uids" > "$UID_CACHE_FILE" 2>/dev/null
    log_msg "WARN" "Kernel netfilter owner match unavailable; falling back to Android netpolicy eBPF."
  fi
}

# Lightweight zero-Java firewall check for watchdog daemon
is_firewall_active() {
  _eng=$(cat "$FW_ENGINE_FILE" 2>/dev/null)
  case "$_eng" in
    nftables)
      nft list table inet miyabi_core >/dev/null 2>&1 && return 0
      return 1
      ;;
    iptables)
      init_ipt_cmds
      $IPT -C OUTPUT -j MIYABI_BLOCK 2>/dev/null && return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

verify_firewall_integrity() {
  load_config
  [ "$ENABLED" -ne 1 ] && return 0
  [ "$MODE" != "extreme" ] && return 0
  [ "$FIREWALL" -ne 1 ] && return 0

  _eng=$(cat "$FW_ENGINE_FILE" 2>/dev/null)
  [ "$_eng" = "netpolicy" ] && return 0

  if ! is_firewall_active; then
    _cached_uids=$(cat "$UID_CACHE_FILE" 2>/dev/null)
    if [ -n "$_cached_uids" ]; then
      log_msg "INFO" "Watchdog detected firewall table reset (VPN/network change). Re-applying..."
      apply_firewall "$_cached_uids"
    fi
  fi
}

# Layer C: Android Native eBPF Background Data Restriction (cmd netpolicy)
apply_netpolicy_restrict() {
  _uids="$1"
  for _uid in $_uids; do
    cmd netpolicy add restrict-background-blacklist "$_uid" >/dev/null 2>&1
  done
}

clear_netpolicy_restrict() {
  _uids="$1"
  for _uid in $_uids; do
    cmd netpolicy remove restrict-background-blacklist "$_uid" >/dev/null 2>&1
  done
}

# ==============================================================================
# TARGETED APPOPS, STANDBY BUCKET & SAFE TELEMETRY COMPONENT HELPERS
# ==============================================================================

set_pkg_appops() {
  _pkg="$1"
  _ops="$2"
  _action="$3"
  for _u in $USER_IDS; do
    for _op in $_ops; do
      cmd appops set --user "$_u" "$_pkg" "$_op" "$_action" >/dev/null 2>&1 || \
        cmd appops set "$_pkg" "$_op" "$_action" >/dev/null 2>&1
    done
  done
}

set_pkg_bucket() {
  _pkg="$1"
  _bucket="$2"
  for _u in $USER_IDS; do
    am set-standby-bucket --user "$_u" "$_pkg" "$_bucket" >/dev/null 2>&1 || \
      am set-standby-bucket "$_pkg" "$_bucket" >/dev/null 2>&1
  done
}

force_stop_pkg_once() {
  _pkg="$1"
  for _u in $USER_IDS; do
    am force-stop --user "$_u" "$_pkg" >/dev/null 2>&1 || am force-stop "$_pkg" >/dev/null 2>&1
  done
}

apply_telemetry_mute() {
  for _u in $USER_IDS; do
    for _comp in $SAFE_TELEMETRY_COMPONENTS; do
      pm disable --user "$_u" "$_comp" >/dev/null 2>&1
    done
  done
}

restore_telemetry_mute() {
  for _u in $USER_IDS; do
    for _comp in $SAFE_TELEMETRY_COMPONENTS; do
      pm enable --user "$_u" "$_comp" >/dev/null 2>&1
    done
  done
}

restore_single_package() {
  _pkg="$1"
  set_pkg_appops "$_pkg" "$ALL_APPOPS" "allow"
  set_pkg_bucket "$_pkg" "active"
  cmd deviceidle whitelist +"$_pkg" >/dev/null 2>&1
  safe_sleep_ms 50
}

# ==============================================================================
# LIVE MODULE.PROP DESCRIPTION UPDATER (Atomic & Safe)
# ==============================================================================

update_module_desc() {
  load_config
  _prop="$MODDIR/module.prop"
  [ -f "$_prop" ] || return 0

  _base="Universal Account-Safe GMS Isolation for Magisk, KernelSU, and APatch."
  if [ "$LIVE_DESC" -ne 1 ]; then
    _new_desc="$_base"
  elif [ "$ENABLED" -ne 1 ]; then
    _new_desc="[Paused | GMS Active] $_base"
  else
    case "$MODE" in
      doze)
        _new_desc="[Active | Smart Doze | Notif Safe] $_base"
        ;;
      balanced)
        _new_desc="[Active | Balanced | Hybrid] $_base"
        ;;
      extreme)
        _fw=$(cat "$FW_ENGINE_FILE" 2>/dev/null)
        [ -z "$_fw" ] && _fw="none"
        if [ "$FIREWALL" -eq 1 ] && [ "$_fw" != "none" ]; then
          _new_desc="[Active | Extreme | FW: $_fw] $_base"
        else
          _new_desc="[Active | Extreme | FW: Off] $_base"
        fi
        ;;
    esac
  fi

  if command -v awk >/dev/null 2>&1; then
    awk -v desc="$_new_desc" '
      /^description=/ { print "description=" desc; next }
      { print }
    ' "$_prop" > "$_prop.tmp" 2>/dev/null && \
      [ -s "$_prop.tmp" ] && \
      mv -f "$_prop.tmp" "$_prop" 2>/dev/null
  else
    sed "s|^description=.*|description=${_new_desc}|" "$_prop" > "$_prop.tmp" 2>/dev/null && \
      [ -s "$_prop.tmp" ] && \
      mv -f "$_prop.tmp" "$_prop" 2>/dev/null
  fi
}

# ==============================================================================
# MASTER ENGINE OPERATIONS (Apply State / Pause / Deep Clean / Screen-Off Doze)
# ==============================================================================

apply_miyabi_state() {
  _do_force_stop="${1:-1}"
  acquire_lock
  load_config
  resolve_environment

  _sdk=$(get_sdk_level)
  _restrict_bucket="rare"
  if [ "$_sdk" -ge 31 ] 2>/dev/null; then
    _restrict_bucket="restricted"
  fi

  # Always clean legacy v2.x OUTPUT rules silently once during state transitions
  clear_legacy_output_rules "$ALL_GOOGLE_UIDS"

  if [ "$ENABLED" -ne 1 ]; then
    # ---- PAUSED / DISABLED STATE ----
    log_msg "INFO" "Disabling Miyabi Core: restoring network, AppOps, buckets & telemetry..."
    clear_firewall
    clear_netpolicy_restrict "$ALL_GOOGLE_UIDS"
    restore_telemetry_mute
    for _p in $INSTALLED_ALL; do
      restore_single_package "$_p"
    done
    update_module_desc
    log_msg "INFO" "Miyabi Core PAUSED. Google Services fully restored."
    release_lock
    return 0
  fi

  # First restore any user-excluded packages so changes take effect immediately
  for _p in $EXCLUDED_INSTALLED_PKGS; do
    restore_single_package "$_p"
  done
  # Reset netpolicy for all before re-applying cleanly
  clear_netpolicy_restrict "$ALL_GOOGLE_UIDS"

  # Handle safe telemetry component mute
  if [ "$TELEMETRY_MUTE" -eq 1 ]; then
    apply_telemetry_mute
  else
    restore_telemetry_mute
  fi

  case "$MODE" in
    doze)
      # ---- MODE 1: SMART DOZE (Daily Driver & Push Notification Safe) ----
      log_msg "INFO" "Applying Mode: SMART DOZE (Notif & Play Store Safe)..."
      clear_firewall

      # Core packages: keep FCM & Play Store working, allow GMS to Doze properly
      for _p in $INSTALLED_CORE; do
        is_pkg_excluded "$_p" && continue
        if [ "$_p" = "com.google.android.gms" ]; then
          cmd deviceidle whitelist -com.google.android.gms >/dev/null 2>&1
          # Ensure background/location/wakelock ops are allowed for FCM stability
          set_pkg_appops "$_p" "$ALL_APPOPS" "allow"
          set_pkg_appops "$_p" "$DOZE_CORE_APPOPS" "ignore"
          set_pkg_bucket "$_p" "working_set"
        else
          # Keep GSF & Play Store fully functional in Smart Doze
          restore_single_package "$_p"
        fi
        safe_sleep_ms 100
      done

      # Auxiliary packages: aggressively restrict bloat/telemetry packages
      for _p in $INSTALLED_AUX; do
        is_pkg_excluded "$_p" && continue
        cmd deviceidle whitelist -"$_p" >/dev/null 2>&1
        set_pkg_appops "$_p" "$ALL_APPOPS" "ignore"
        set_pkg_bucket "$_p" "$_restrict_bucket"
        [ "$_do_force_stop" -eq 1 ] && force_stop_pkg_once "$_p"
        safe_sleep_ms 100
      done
      ;;

    balanced)
      # ---- MODE 2: BALANCED (Hybrid Gaming & Daily Driver) ----
      log_msg "INFO" "Applying Mode: BALANCED (Bg Restricted, Foreground Ready)..."
      clear_firewall

      for _p in $ACTIVE_TARGET_PKGS; do
        cmd deviceidle whitelist -"$_p" >/dev/null 2>&1
        # Allow foreground & alert window, block background/wakelock/location
        set_pkg_appops "$_p" "START_FOREGROUND SYSTEM_ALERT_WINDOW" "allow"
        set_pkg_appops "$_p" "$BALANCED_APPOPS" "ignore"
        set_pkg_bucket "$_p" "$_restrict_bucket"
        [ "$_do_force_stop" -eq 1 ] && force_stop_pkg_once "$_p"
        safe_sleep_ms 150
      done

      # Restrict background data via Android native eBPF netpolicy (foreground remains open)
      apply_netpolicy_restrict "$TARGET_UIDS"
      echo "netpolicy" > "$FW_ENGINE_FILE" 2>/dev/null
      echo "$TARGET_UIDS" > "$UID_CACHE_FILE" 2>/dev/null
      ;;

    extreme)
      # ---- MODE 3: EXTREME (Maximum Gaming Performance & Full Isolation) ----
      log_msg "INFO" "Applying Mode: EXTREME (Full Runtime & Network Isolation)..."

      for _p in $ACTIVE_TARGET_PKGS; do
        cmd deviceidle whitelist -"$_p" >/dev/null 2>&1
        # Single clean force-stop on apply/boot only (NEVER inside rapid loop -> zero Zygisk deadlock!)
        [ "$_do_force_stop" -eq 1 ] && force_stop_pkg_once "$_p"
        set_pkg_appops "$_p" "$ALL_APPOPS" "ignore"
        set_pkg_bucket "$_p" "$_restrict_bucket"
        safe_sleep_ms 150
      done

      apply_netpolicy_restrict "$TARGET_UIDS"
      if [ "$FIREWALL" -eq 1 ]; then
        apply_firewall "$TARGET_UIDS"
      else
        clear_firewall
      fi
      ;;
  esac

  update_module_desc
  log_msg "INFO" "Apply complete (Mode=$MODE, Targets=$(echo $ACTIVE_TARGET_PKGS | wc -w | tr -dc '0-9'), UIDs=$(echo $TARGET_UIDS | wc -w | tr -dc '0-9'))."
  release_lock
}

# One-shot clean sweep (force-stop target packages once safely on user demand)
run_deep_clean() {
  acquire_lock
  load_config
  resolve_environment
  if [ "$ENABLED" -ne 1 ]; then
    log_msg "WARN" "Deep Clean skipped: Miyabi Core is currently paused."
    release_lock
    return 1
  fi
  log_msg "INFO" "Running One-Shot Deep Clean (Mode=$MODE)..."
  _targets="$ACTIVE_TARGET_PKGS"
  if [ "$MODE" = "doze" ]; then
    _targets=""
    for _p in $INSTALLED_AUX; do
      is_pkg_excluded "$_p" || _targets="$_targets $_p"
    done
  fi
  for _p in $_targets; do
    force_stop_pkg_once "$_p"
    safe_sleep_ms 100
  done
  if [ "$MODE" = "extreme" ] && [ "$FIREWALL" -eq 1 ]; then
    if ! is_firewall_active; then
      apply_firewall "$TARGET_UIDS"
    fi
  fi
  log_msg "INFO" "Deep Clean finished."
  release_lock
  return 0
}

# Screen-Off & Non-Charging Smart Doze Check (Never disturbs active gaming or screen-on use!)
is_screen_off() {
  _pwr=$(dumpsys power 2>/dev/null | grep -m1 -E "mWakefulness=|Display Power: state=")
  case "$_pwr" in
    *Asleep*|*Dozing*|*OFF*) return 0 ;;
    *) return 1 ;;
  esac
}

is_charging() {
  for _f in /sys/class/power_supply/*/status; do
    [ -r "$_f" ] || continue
    _st=$(cat "$_f" 2>/dev/null)
    case "$_st" in
      Charging|Full) return 0 ;;
    esac
  done
  return 1
}

run_screen_off_doze() {
  load_config
  [ "$ENABLED" -ne 1 ] && return 0
  [ "$SMART_DOZE" -ne 1 ] && return 0

  if is_screen_off && ! is_charging; then
    _idle_state=$(dumpsys deviceidle get deep 2>/dev/null | tr -d '\r\n ')
    if [ "$_idle_state" != "IDLE" ]; then
      dumpsys deviceidle force-idle deep >/dev/null 2>&1 || dumpsys deviceidle force-idle >/dev/null 2>&1
    fi
  fi
}

# ==============================================================================
# LIVE TELEMETRY & JSON EXPORTER (Zero-Overhead Process & RAM Inspector)
# ==============================================================================

get_gms_process_stats() {
  GMS_PROC_COUNT=0
  GMS_RAM_KB=0
  _pids=$(pgrep -f "com\.google\.android\.gms|com\.google\.process\.gservices|com\.android\.vending" 2>/dev/null)
  for _pid in $_pids; do
    [ -r "/proc/$_pid/status" ] || continue
    _cmd=$(tr '\0' ' ' < "/proc/$_pid/cmdline" 2>/dev/null)
    case "$_cmd" in
      com.google.android.gms*|com.google.process.gservices*|com.android.vending*) ;;
      *) continue ;;
    esac
    GMS_PROC_COUNT=$((GMS_PROC_COUNT + 1))
    _rss=$(awk '/^VmRSS:/ { print $2; exit }' "/proc/$_pid/status" 2>/dev/null | tr -dc '0-9')
    if [ -z "$_rss" ]; then
      _rss=$(grep -m1 "^VmRSS:" "/proc/$_pid/status" 2>/dev/null | tr -dc '0-9')
    fi
    [ -n "$_rss" ] && GMS_RAM_KB=$((GMS_RAM_KB + _rss))
  done
  GMS_RAM_MB=$(( (GMS_RAM_KB + 512) / 1024 ))
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n'
}

print_status_json() {
  load_config
  resolve_environment
  get_gms_process_stats

  _fw_eng=$(cat "$FW_ENGINE_FILE" 2>/dev/null)
  [ -z "$_fw_eng" ] && _fw_eng="none"
  _fw_active="false"
  if [ "$ENABLED" -eq 1 ]; then
    if [ "$MODE" = "extreme" ] && [ "$FIREWALL" -eq 1 ]; then
      is_firewall_active && _fw_active="true"
      [ "$_fw_eng" = "netpolicy" ] && _fw_active="true"
    elif [ "$MODE" = "balanced" ]; then
      _fw_active="true"
      _fw_eng="netpolicy"
    fi
  fi

  _sys_patched=$(cat "$SYSCONFIG_FILE" 2>/dev/null | tr -dc '0-9')
  [ -z "$_sys_patched" ] && _sys_patched=0

  _dpid=$(cat "$PID_FILE" 2>/dev/null | tr -dc '0-9')
  _drun="false"
  if [ -n "$_dpid" ] && kill -0 "$_dpid" 2>/dev/null; then
    _drun="true"
  else
    _dpid=0
  fi

  _model=$(json_escape "$(getprop ro.product.model 2>/dev/null)")
  _brand=$(json_escape "$(getprop ro.product.brand 2>/dev/null)")
  _aver=$(json_escape "$(getprop ro.build.version.release 2>/dev/null)")
  _asdk=$(get_sdk_level)
  _kver=$(json_escape "$(uname -r 2>/dev/null)")
  _rmgr=$(json_escape "$(detect_root_manager)")
  _uid_cnt=$(echo $TARGET_UIDS | wc -w | tr -dc '0-9')
  [ -z "$_uid_cnt" ] && _uid_cnt=0

  # Build packages array JSON
  _pkgs_json="["
  _first=1
  for _p in $INSTALLED_ALL; do
    _role="aux"
    case " $CORE_PACKAGES " in
      *" $_p "*) _role="core" ;;
    esac
    _aid=$(get_pkg_appid "$_p")
    _excl="false"
    is_pkg_excluded "$_p" && _excl="true"
    _run="false"
    if [ "$_p" = "com.google.android.gms" ]; then
      pgrep -f "^com\.google\.android\.gms($|:|\.persistent|\.unstable|\.ui)" >/dev/null 2>&1 && _run="true"
    elif [ "$_p" = "com.google.android.gsf" ]; then
      (pgrep -f "^com\.google\.android\.gsf($|:)" >/dev/null 2>&1 || pgrep -f "^com\.google\.process\.gservices" >/dev/null 2>&1) && _run="true"
    else
      pgrep -f "^${_p}($|:)" >/dev/null 2>&1 && _run="true"
    fi
    [ "$_first" -eq 0 ] && _pkgs_json="${_pkgs_json},"
    _pkgs_json="${_pkgs_json}{\"pkg\":\"${_p}\",\"uid\":\"${_aid}\",\"role\":\"${_role}\",\"excluded\":${_excl},\"running\":${_run}}"
    _first=0
  done
  _pkgs_json="${_pkgs_json}]"

  printf '{"version":"v3.0.0","enabled":%s,"mode":"%s","firewall":%s,"smart_doze":%s,"telemetry_mute":%s,"boot_self_heal":%s,"live_desc":%s,"exclude_vending":%s,"boot_delay":%s,"fw_engine":"%s","fw_active":%s,"blocked_uid_count":%s,"sysconfig_patched":%s,"gms_proc_count":%s,"gms_ram_mb":%s,"daemon_running":%s,"daemon_pid":%s,"device":"%s %s","android_ver":"%s","android_sdk":%s,"kernel":"%s","root_manager":"%s","packages":%s}\n' \
    "$([ "$ENABLED" -eq 1 ] && echo true || echo false)" \
    "$MODE" \
    "$([ "$FIREWALL" -eq 1 ] && echo true || echo false)" \
    "$([ "$SMART_DOZE" -eq 1 ] && echo true || echo false)" \
    "$([ "$TELEMETRY_MUTE" -eq 1 ] && echo true || echo false)" \
    "$([ "$BOOT_SELF_HEAL" -eq 1 ] && echo true || echo false)" \
    "$([ "$LIVE_DESC" -eq 1 ] && echo true || echo false)" \
    "$([ "$EXCLUDE_VENDING" -eq 1 ] && echo true || echo false)" \
    "$BOOT_DELAY" \
    "$(json_escape "$_fw_eng")" \
    "$_fw_active" \
    "$_uid_cnt" \
    "$_sys_patched" \
    "$GMS_PROC_COUNT" \
    "$GMS_RAM_MB" \
    "$_drun" \
    "$_dpid" \
    "$_brand" "$_model" \
    "$_aver" \
    "$_asdk" \
    "$_kver" \
    "$_rmgr" \
    "$_pkgs_json"
}

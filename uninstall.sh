#!/system/bin/sh
# ==============================================================================
# GMS Breaker Miyabi Core v3.0.0 - 100% Surgical Restoration & Clean Uninstall
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core
# ==============================================================================

(
  # Wait for Android boot completion so pm/cmd services are online
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
  done

  sleep 10

  ALL_PACKAGES="
  com.google.android.gms
  com.google.android.gsf
  com.android.vending
  com.google.android.gms.setup
  com.google.android.feedback
  com.google.android.partnersetup
  com.google.android.onetimeinitializer
  com.google.android.backuptransport
  com.google.android.syncadapters.contacts
  com.google.android.syncadapters.calendar
  com.google.android.projection.gearhead
  com.google.android.apps.gcs
  com.google.android.gms.policy_sidecar
  com.google.android.printservice.recommendation
  com.google.android.gms.location.history
  "

  ALL_APPOPS="RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK START_FOREGROUND ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION GET_USAGE_STATS SYSTEM_ALERT_WINDOW WRITE_SETTINGS"

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

  # 1. Stop any running watchdog daemon
  if [ -f "/data/adb/miyabi_core/daemon.pid" ]; then
    _dpid=$(cat /data/adb/miyabi_core/daemon.pid 2>/dev/null | tr -dc '0-9')
    [ -n "$_dpid" ] && kill "$_dpid" 2>/dev/null
  fi

  # 2. Clean nftables & iptables/ip6tables custom chains
  if command -v nft >/dev/null 2>&1; then
    nft delete table inet miyabi_core 2>/dev/null
  fi

  IPT="iptables"
  IP6T="ip6tables"
  iptables -w -L OUTPUT -n >/dev/null 2>&1 && IPT="iptables -w"
  ip6tables -w -L OUTPUT -n >/dev/null 2>&1 && IP6T="ip6tables -w"

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

  # 3. Resolve Users & UIDs to clean netpolicy and any legacy OUTPUT rules
  USER_IDS=$(pm list users 2>/dev/null | grep "UserInfo{" | cut -d'{' -f2 | cut -d':' -f1 | tr -d '\r')
  [ -z "$USER_IDS" ] && USER_IDS="0"

  PKG_CACHE=""
  [ ! -r "/data/system/packages.list" ] && PKG_CACHE=$(cmd package list packages -U 2>/dev/null || pm list packages -U 2>/dev/null)

  for P in $ALL_PACKAGES; do
    _aid=""
    if [ -r "/data/system/packages.list" ]; then
      _aid=$(awk -v p="$P" '$1 == p { print $2; exit }' /data/system/packages.list 2>/dev/null | tr -dc '0-9')
    else
      _aid=$(printf '%s\n' "$PKG_CACHE" | grep -E "^package:${P}($|[[:space:]])" | head -n 1 | grep -oE "uid:[0-9]+" | cut -d':' -f2 | tr -dc '0-9')
    fi

    if [ -n "$_aid" ]; then
      for U in $USER_IDS; do
        _uid=$((U * 100000 + _aid))
        cmd netpolicy remove restrict-background-blacklist "$_uid" >/dev/null 2>&1
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

      # 4. Surgically restore AppOps (NEVER 'cmd appops reset' -> MIUI/HyperOS safe)
      for U in $USER_IDS; do
        for OP in $ALL_APPOPS; do
          cmd appops set --user "$U" "$P" "$OP" allow >/dev/null 2>&1 || cmd appops set "$P" "$OP" allow >/dev/null 2>&1
        done
        am set-standby-bucket --user "$U" "$P" active >/dev/null 2>&1 || am set-standby-bucket "$P" active >/dev/null 2>&1
      done

      # 5. Re-whitelist in deviceidle
      cmd deviceidle whitelist +"$P" >/dev/null 2>&1
    fi
  done

  # 6. Re-enable safe telemetry components
  for U in $USER_IDS; do
    for COMP in $SAFE_TELEMETRY_COMPONENTS; do
      pm enable --user "$U" "$COMP" >/dev/null 2>&1
    done
  done

  # 7. Clean up all Miyabi Core persistent state, flags, and fallback CLI binaries
  rm -rf /data/adb/miyabi_core
  rm -f /data/adb/miyabi_disabled
  rm -f /data/adb/ksu/bin/miyabi
  rm -f /data/adb/apatch/bin/miyabi
  rm -f /data/adb/ap/bin/miyabi
) &

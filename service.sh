#!/system/bin/sh
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core

(
# Wait for boot completion
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

# Wait for system services to settle
sleep 15

# Reset CLI temporary flag on boot to ensure GMS Breaker is always active after a reboot (Self-Healing)
rm -f /data/adb/miyabi_disabled

# Define target packages to isolate
TARGET_PACKAGES="
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
"

# Define target processes to freeze (matches command line patterns)
PROCESS_PATTERNS="
com.google.android.gms
com.google.process.gservices
com.android.vending
com.google.android.gsf
com.google.android.apps.gcs
com.google.android.projection.gearhead
"

# Helper to find all active Android users (Owner, Dual Apps, Work Profile, etc.)
# Highly compatible implementation using standard grep and cut (avoids grep -oE)
get_users() {
  pm list users 2>/dev/null | grep "UserInfo{" | cut -d'{' -f2 | cut -d':' -f1
}

# Function to run the full block and isolation setup
initialize_gms_breaker() {
  USER_IDS=$(get_users)
  if [ -z "$USER_IDS" ]; then
    USER_IDS="0"
  fi

  # Filter only installed packages to avoid throwing errors on non-existent ones
  INSTALLED_PACKAGES=""
  for P in $TARGET_PACKAGES; do
    if pm path "$P" >/dev/null 2>&1; then
      INSTALLED_PACKAGES="$INSTALLED_PACKAGES $P"
    fi
  done

  # Remove from deviceidle whitelist (globally)
  for P in $INSTALLED_PACKAGES; do
    cmd deviceidle whitelist -"$P" >/dev/null 2>&1
  done

  # Apply AppOps and Standby Bucket for all users
  for U in $USER_IDS; do
    for P in $INSTALLED_PACKAGES; do
      
      # Block critical AppOps that GMS uses to wake up and run background tasks
      for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK START_FOREGROUND ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION GET_USAGE_STATS SYSTEM_ALERT_WINDOW WRITE_SETTINGS; do
        cmd appops set --user "$U" "$P" "$OP" ignore >/dev/null 2>&1 || cmd appops set "$P" "$OP" ignore >/dev/null 2>&1
      done
      
      # Restrict standby bucket (restricted for Android 12+, rare for older versions)
      sdk=$(getprop ro.build.version.sdk)
      bucket="rare"
      if [ -n "$sdk" ] && [ "$sdk" -ge 31 ] 2>/dev/null; then
        bucket="restricted"
      fi
      am set-standby-bucket --user "$U" "$P" "$bucket" >/dev/null 2>&1 || am set-standby-bucket "$P" "$bucket" >/dev/null 2>&1
    done
  done

  # Network Isolation: Block IPv4 and IPv6 traffic for all target UIDs (all users)
  # Caches the UIDs globally to prevent Java VM execution inside the 20-second loop
  BLOCKED_UIDS=""
  for P in $INSTALLED_PACKAGES; do
    uids=$( (cmd package list packages -U 2>/dev/null || pm list packages -U 2>/dev/null) | grep -E "^package:$P($|[[:space:]])" | grep -oE "uid:[0-9,]+" | cut -d':' -f2 | tr ',' ' ' | tr -d '\r' )
    for UID in $uids; do
      if [ -n "$UID" ]; then
        BLOCKED_UIDS="$BLOCKED_UIDS $UID"
        # Block IPv4 - check first to avoid duplicate rule stacking leak
        iptables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
        # Block IPv6 - check first to avoid duplicate rule stacking leak
        ip6tables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
      fi
    done
  done
}

# State tracking for live toggles
CURRENT_STATE="active"

# Run the initial deep isolation setup if enabled on boot
if [ ! -f "/data/adb/miyabi_disabled" ]; then
  initialize_gms_breaker
else
  CURRENT_STATE="disabled"
fi

# Counter for periodic deep checks (every 5 minutes / 300 seconds)
DEEP_CHECK_INTERVAL=15
COUNTER=0

while true; do
  # Check if breaker is temporarily disabled via CLI
  if [ -f "/data/adb/miyabi_disabled" ]; then
    if [ "$CURRENT_STATE" = "active" ]; then
      # Turn off breaker: unsuspend packages, restore appops, remove firewall rules
      USER_IDS=$(get_users)
      if [ -z "$USER_IDS" ]; then
        USER_IDS="0"
      fi
      
      # Clean up network blocks
      for P in $TARGET_PACKAGES; do
        uids=$( (cmd package list packages -U 2>/dev/null || pm list packages -U 2>/dev/null) | grep -E "^package:$P($|[[:space:]])" | grep -oE "uid:[0-9,]+" | cut -d':' -f2 | tr ',' ' ' | tr -d '\r' )
        for UID in $uids; do
          if [ -n "$UID" ]; then
            while iptables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null; do
              iptables -D OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
            done
            while ip6tables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null; do
              ip6tables -D OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
            done
          fi
        done
        
        # Restore AppOps
        for U in $USER_IDS; do
          for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK START_FOREGROUND ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION GET_USAGE_STATS SYSTEM_ALERT_WINDOW WRITE_SETTINGS; do
            cmd appops set --user "$U" "$P" "$OP" allow >/dev/null 2>&1 || cmd appops set "$P" "$OP" allow >/dev/null 2>&1
          done
        done
        
        # Re-whitelist in deviceidle
        cmd deviceidle whitelist +"$P" >/dev/null 2>&1
      done
      
      CURRENT_STATE="disabled"
    fi
    sleep 20
    continue
  else
    if [ "$CURRENT_STATE" = "disabled" ]; then
      # Re-enable breaker
      initialize_gms_breaker
      CURRENT_STATE="active"
    fi
  fi

  # 1. Force-stop running packages
  for P in $TARGET_PACKAGES; do
    if pgrep -f "$P" >/dev/null 2>&1 || { [ "$P" = "com.google.android.gsf" ] && pgrep -f com.google.process.gservices >/dev/null 2>&1; }; then
      for U in $USER_IDS; do
        am force-stop --user "$U" "$P" >/dev/null 2>&1 || am force-stop "$P" >/dev/null 2>&1
      done
    fi
  done



  # 2. Enforce network blocks using pre-resolved UIDs (zero Java vm overhead!)
  for UID in $BLOCKED_UIDS; do
    iptables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
    ip6tables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
  done

  # 3. Force deep device idle (every 120 seconds / 6 loop cycles to save battery)
  if [ $((COUNTER % 6)) -eq 0 ]; then
    dumpsys deviceidle force-idle >/dev/null 2>&1
  fi

  # 4. Run full deep check to re-apply package/appop restrictions (every 5 minutes)
  COUNTER=$((COUNTER + 1))
  if [ "$COUNTER" -ge "$DEEP_CHECK_INTERVAL" ]; then
    initialize_gms_breaker
    COUNTER=0
  fi

  sleep 20
done
) &


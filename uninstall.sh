#!/system/bin/sh
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core

(
# Wait for boot completion so system services (pm/cmd) are active
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

# Wait for system services to stabilize
sleep 10

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

get_users() {
  pm list users 2>/dev/null | grep "UserInfo{" | cut -d'{' -f2 | cut -d':' -f1
}

USER_IDS=$(get_users)
if [ -z "$USER_IDS" ]; then
  USER_IDS="0"
fi

for P in $TARGET_PACKAGES; do
  # Get UIDs dynamically for this package and clean carriage returns (\r)
  uids=$( (cmd package list packages -U 2>/dev/null || pm list packages -U 2>/dev/null) | grep -E "^package:$P($|[[:space:]])" | grep -oE "uid:[0-9,]+" | cut -d':' -f2 | tr ',' ' ' | tr -d '\r' )
  for UID in $uids; do
    if [ -n "$UID" ]; then
      # Delete all instances of the IPv4 block rule
      while iptables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null; do
        iptables -D OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
      done
      # Delete all instances of the IPv6 block rule
      while ip6tables -C OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null; do
        ip6tables -D OUTPUT -m owner --uid-owner "$UID" -j DROP 2>/dev/null
      done
    fi
  done

  # Unsuspend and reset AppOps for all active users
  for U in $USER_IDS; do
    cmd package unsuspend --user "$U" "$P" >/dev/null 2>&1 || cmd package unsuspend "$P" >/dev/null 2>&1
    cmd appops reset --user "$U" "$P" >/dev/null 2>&1 || cmd appops reset "$P" >/dev/null 2>&1
  done

  # Add back to deviceidle whitelist
  cmd deviceidle whitelist +"$P" >/dev/null 2>&1
done

# Resume any frozen Google/GSF/Store processes (SIGCONT)
for PROC in com.google.android.gms com.google.process.gservices com.android.vending com.google.android.gsf com.google.android.apps.gcs com.google.android.projection.gearhead; do
  pkill -CONT -f "$PROC" >/dev/null 2>&1
done

# Clean up terminal command flag and copied CLI binaries if they remain
rm -f /data/adb/miyabi_disabled
rm -f /data/adb/ksu/bin/miyabi
rm -f /data/adb/apatch/bin/miyabi
) &


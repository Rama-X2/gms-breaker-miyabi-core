# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core

#!/data/adb/magisk/busybox sh
set -o standalone

(
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

sleep 20

NULL="/dev/null"

PACKAGES="
com.google.android.gms
com.google.android.gms.unstable
com.google.android.gsf
com.android.vending
"

# Get UID for network isolation
GMS_UID=$(cmd package list packages -U | grep com.google.android.gms | awk -F: '{print $3}')

while true; do

  for P in $PACKAGES; do
    
    # Block all AppOps
    cmd appops set $P RUN_ANY_IN_BACKGROUND ignore &> $NULL
    cmd appops set $P RUN_IN_BACKGROUND ignore &> $NULL
    cmd appops set $P WAKE_LOCK ignore &> $NULL
    cmd appops set $P START_FOREGROUND ignore &> $NULL
    cmd appops set $P ACCESS_FINE_LOCATION ignore &> $NULL
    cmd appops set $P ACCESS_COARSE_LOCATION ignore &> $NULL
    
    # Restricted standby bucket
    cmd appops set $P RUN_ANY_IN_BACKGROUND ignore &> $NULL
    
    # Force-stop
    am force-stop $P &> $NULL
    
    # Suspend
    cmd package suspend $P &> $NULL
    
  done

  # Network isolation (iptables drop)
  if [ ! -z "$GMS_UID" ]; then
    iptables -I OUTPUT -m owner --uid-owner $GMS_UID -j DROP
  fi

  # Force deep idle
  dumpsys deviceidle force-idle &> $NULL

  sleep 20

done
)&

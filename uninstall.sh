#!/system/bin/sh

PACKAGES="
com.google.android.gms
com.google.android.gsf
com.android.vending
"

for P in $PACKAGES; do
  cmd package unsuspend $P
  cmd appops reset $P
  cmd deviceidle whitelist +$P
done

# Remove iptables rule
iptables -D OUTPUT -m owner --uid-owner 10012 -j DROP 2>/dev/null

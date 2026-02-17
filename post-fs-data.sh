#!/data/adb/magisk/busybox sh
set -o standalone

NULL="/dev/null"

PACKAGES="
com.google.android.gms
com.google.android.gsf
com.android.vending
"

for P in $PACKAGES; do
  cmd deviceidle whitelist -$P &> $NULL
done

exit 0

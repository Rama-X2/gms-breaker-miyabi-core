#!/system/bin/sh
# GMS Breaker Miyabi Core - customize.sh
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0

ui_print "- Setting executable permissions for Miyabi CLI..."
set_perm $MODPATH/system/bin/miyabi 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/system/bin/miyabi
set_perm $MODPATH/service.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/service.sh
set_perm $MODPATH/uninstall.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/uninstall.sh

# Helper for KernelSU and APatch bin path fallback
if [ -d "/data/adb/ksu/bin" ]; then
  ui_print "- Linking Miyabi CLI to KernelSU bin directory..."
  ln -sf $MODPATH/system/bin/miyabi /data/adb/ksu/bin/miyabi
  chmod 0755 /data/adb/ksu/bin/miyabi 2>/dev/null
fi

if [ -d "/data/adb/apatch/bin" ]; then
  ui_print "- Linking Miyabi CLI to APatch bin directory..."
  ln -sf $MODPATH/system/bin/miyabi /data/adb/apatch/bin/miyabi
  chmod 0755 /data/adb/apatch/bin/miyabi 2>/dev/null
fi

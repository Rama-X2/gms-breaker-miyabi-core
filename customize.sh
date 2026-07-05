#!/system/bin/sh
# GMS Breaker Miyabi Core - customize.sh
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0

ui_print "- Setting executable permissions for Miyabi CLI..."
set_perm $MODPATH/system/bin/miyabi 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/system/bin/miyabi
set_perm $MODPATH/service.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/service.sh
set_perm $MODPATH/uninstall.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/uninstall.sh

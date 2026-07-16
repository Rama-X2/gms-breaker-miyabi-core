#!/system/bin/sh
# GMS Breaker Miyabi Core - customize.sh
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0

# Print banner
ui_print "=================================================="
ui_print "                     (≧◡≦)                       "
ui_print "                  Miyabi Core                     "
ui_print "                     /l、                          "
ui_print "                   (ﾟ､ ｡ 7                        "
ui_print "                   l、 ~ヽ                        "
ui_print "                   じしf_, )ノ                     "
ui_print "     『 GMS Breaker Miyabi Core v2.6.5 』          "
ui_print "=================================================="
ui_print " - Target Environment: Universal (Magisk/KSU/APatch)"

# Force-extract the entire ZIP file to ensure KSU/APatch/Magisk compatibility
ui_print "- Extracting module files..."
unzip -o "$ZIPFILE" -d "$MODPATH" 2>/dev/null

# Remove skip_mount if it was automatically created by a previous failed install
rm -f "$MODPATH/skip_mount"

# Detect and fix nested zip extraction (common issue when zipping parent folder)
for dir in "$MODPATH"/*; do
  if [ -d "$dir" ] && [ -f "$dir/module.prop" ]; then
    ui_print "- Fixing nested zip structure..."
    mv "$dir"/* "$MODPATH/" 2>/dev/null
    rm -rf "$dir" 2>/dev/null
    break
  fi
done

# Clean carriage returns (dos2unix) on all executable scripts to prevent boot/run failures
ui_print "- Cleaning carriage returns (dos2unix)..."
for file in "$MODPATH"/system/bin/miyabi "$MODPATH"/service.sh "$MODPATH"/uninstall.sh "$MODPATH"/post-fs-data.sh; do
  if [ -f "$file" ]; then
    tr -d '\r' < "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done

ui_print "- Setting executable permissions..."
set_perm $MODPATH/system/bin/miyabi 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/system/bin/miyabi
set_perm $MODPATH/service.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/service.sh
set_perm $MODPATH/uninstall.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/uninstall.sh

# Restore SELinux contexts to prevent execution blocks
ui_print "- Restoring SELinux contexts..."
restorecon -R $MODPATH/system/bin/miyabi 2>/dev/null
restorecon -R $MODPATH/service.sh 2>/dev/null
restorecon -R $MODPATH/uninstall.sh 2>/dev/null

# Helper for KernelSU and APatch bin path fallback (Copy instead of symlink)
if [ -d "/data/adb/ksu/bin" ]; then
  ui_print "- Copying Miyabi CLI to KernelSU bin directory..."
  cp -f $MODPATH/system/bin/miyabi /data/adb/ksu/bin/miyabi
  chmod 0755 /data/adb/ksu/bin/miyabi 2>/dev/null
  restorecon /data/adb/ksu/bin/miyabi 2>/dev/null
fi

if [ -d "/data/adb/apatch/bin" ]; then
  ui_print "- Copying Miyabi CLI to APatch bin directory..."
  cp -f $MODPATH/system/bin/miyabi /data/adb/apatch/bin/miyabi
  chmod 0755 /data/adb/apatch/bin/miyabi 2>/dev/null
  restorecon /data/adb/apatch/bin/miyabi 2>/dev/null
fi

ui_print "==================『 REBOOT DEVICE 』=================="
ui_print " "

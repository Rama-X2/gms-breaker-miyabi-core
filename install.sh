# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core

#!/system/bin/sh

print_modname() {
  ui_print "======================================================"
  sleep 0.5
  ui_print " "
  ui_print "   Created by : Rama-X2"
  sleep 0.5
  ui_print "   github     : https://github.com/Rama-X2"
  ui_print " "
  sleep 0.5
  ui_print "⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀"
  sleep 0.5
  ui_print "           ╔══════════════════════╗               "
  ui_print "           ║           (≧◡≦)          ║              "
  ui_print "           ║        Miyabi Core       ║              "
  ui_print "           ╚══════════════════════╝               "
  sleep 0.5  
  ui_print "                      ／l、                          "
  ui_print "                    （ﾟ､ ｡ ７                        "
  ui_print "                     l、  ~ヽ                        "
  ui_print "                     じしf_, )ノ                     "
  sleep 0.5
  ui_print "     『 GMS Breaker Miyabi Core v2.6.2 』          "
  sleep 0.5
  ui_print "⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀⢀"
  sleep 0.5
  ui_print " - Target Environment: Universal (Magisk/KSU/APatch)"
  sleep 0.5
  ui_print " - Initializing Runtime Engine..."
  sleep 0.5
  ui_print " - Preparing GMS Network & Process Isolation..."
  ui_print " - Finalizing settings..."
  sleep 0.5
  ui_print " - Done."
  sleep 0.5
  ui_print "==================『 REBOOT DEVICE 』=================="
  ui_print " "
}

set_permissions() {
  # Clean carriage returns (dos2unix) on all executable scripts
  for file in "$MODPATH"/system/bin/miyabi "$MODPATH"/service.sh "$MODPATH"/uninstall.sh "$MODPATH"/post-fs-data.sh; do
    if [ -f "$file" ]; then
      tr -d '\r' < "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
  done

  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm $MODPATH/system/bin/miyabi 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/system/bin/miyabi
  set_perm $MODPATH/service.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/service.sh
  set_perm $MODPATH/uninstall.sh 0 0 0755 2>/dev/null || chmod 0755 $MODPATH/uninstall.sh
}

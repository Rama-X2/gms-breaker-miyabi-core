#!/system/bin/sh
# ==============================================================================
# GMS Breaker Miyabi Core v3.0.0 - 1-Tap Action Button (Magisk 28+ / KSU / APatch)
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# ==============================================================================

MODDIR="${0%/*}"
export MODDIR

if [ ! -f "$MODDIR/core.sh" ]; then
  echo "[!] Error: core.sh not found in $MODDIR"
  exit 1
fi

# shellcheck disable=SC1091
. "$MODDIR/core.sh"

load_config

echo "=================================================="
echo "          GMS Breaker Miyabi Core v3.0.0          "
echo "=================================================="

if [ "$ENABLED" -eq 1 ]; then
  ENABLED=0
  save_config
  echo " - Switching state: ACTIVE -> PAUSED (GMS Restoring...)"
  apply_miyabi_state 0
  echo " [+] Status : PAUSED (Google Services Active)"
  echo " [i] Tap Action again anytime to re-enable."
else
  ENABLED=1
  save_config
  echo " - Switching state: PAUSED -> ACTIVE (Mode: $MODE)"
  apply_miyabi_state 1
  echo " [+] Status : ENABLED (Mode: $MODE)"
fi

get_gms_process_stats
_fw_eng=$(cat "$FW_ENGINE_FILE" 2>/dev/null)
[ -z "$_fw_eng" ] && _fw_eng="none"

echo "--------------------------------------------------"
echo " Active Mode    : $MODE"
echo " Firewall       : $_fw_eng"
echo " GMS Processes  : $GMS_PROC_COUNT running (~${GMS_RAM_MB} MB RAM)"
echo "--------------------------------------------------"
echo " Tip: Use WebUI (KSU/APatch/MMRL) or terminal:"
echo "   su -c miyabi mode doze|balanced|extreme"
echo "   su -c miyabi status | su -c miyabi doctor"
echo "=================================================="
exit 0

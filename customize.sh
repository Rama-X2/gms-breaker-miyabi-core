#!/system/bin/sh
# ==============================================================================
# GMS Breaker Miyabi Core v3.0.0 - Universal Installer
# Copyright (C) 2026 Rama-X2
# Licensed under the GNU General Public License, Version 3.0
# Source: https://github.com/Rama-X2/gms-breaker-miyabi-core
# ==============================================================================

ui_print "=================================================="
ui_print "                     (≧◡≦)                       "
ui_print "                  Miyabi Core                     "
ui_print "                     /l、                          "
ui_print "                   (ﾟ､ ｡ 7                        "
ui_print "                   l、 ~ヽ                        "
ui_print "                   じしf_, )ノ                     "
ui_print "     『 GMS Breaker Miyabi Core v3.0.0 』          "
ui_print "=================================================="

# 1. Detect Environment & Root Manager
ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null)
SDK_VER=$(getprop ro.build.version.sdk 2>/dev/null)
DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null)

if [ "$KSU" = "true" ]; then
  ui_print " - Root Manager : KernelSU (${KSU_VER:-Active})"
  ui_print " - WebUI Support: Native KSU WebUI Ready!"
elif [ "$APATCH" = "true" ]; then
  ui_print " - Root Manager : APatch (${APATCH_VER:-Active})"
  ui_print " - WebUI Support: Native APatch WebUI Ready!"
else
  ui_print " - Root Manager : Magisk (${MAGISK_VER:-Active})"
  ui_print " - Quick Toggle : 1-Tap Action Button + CLI Ready!"
fi
ui_print " - Device Info  : ${DEVICE_MODEL:-Android} (Android ${ANDROID_VER:-?} / SDK ${SDK_VER:-?})"

if command -v nft >/dev/null 2>&1; then
  ui_print " - Firewall API : nftables + iptables fallback"
else
  ui_print " - Firewall API : iptables/ip6tables + netpolicy"
fi

# 2. Remove any leftover skip_mount flag
rm -f "$MODPATH/skip_mount"

# 3. Auto-fix nested ZIP extraction (if user compressed the parent folder)
for dir in "$MODPATH"/*; do
  if [ -d "$dir" ] && [ -f "$dir/module.prop" ]; then
    ui_print " - Fixing nested ZIP folder structure..."
    cp -af "$dir"/. "$MODPATH/" 2>/dev/null
    rm -rf "$dir" 2>/dev/null
    break
  fi
done

# 4. Auto-clean Windows CRLF line endings on all scripts & configs
ui_print " - Sanitizing Unix LF line endings..."
for file in \
  "$MODPATH/core.sh" \
  "$MODPATH/service.sh" \
  "$MODPATH/action.sh" \
  "$MODPATH/uninstall.sh" \
  "$MODPATH/post-fs-data.sh" \
  "$MODPATH/system/bin/miyabi" \
  "$MODPATH/module.prop" \
  "$MODPATH/sepolicy.rule"; do
  if [ -f "$file" ]; then
    tr -d '\r' < "$file" > "$file.tmp" && mv -f "$file.tmp" "$file"
  fi
done

# 5. Prepare Persistent State Directory (preserves user settings across upgrades)
STATE_DIR="/data/adb/miyabi_core"
mkdir -p "$STATE_DIR" 2>/dev/null
if [ ! -f "$STATE_DIR/config.sh" ]; then
  ui_print " - Creating default configuration..."
  cat <<'EOF' > "$STATE_DIR/config.sh"
# GMS Breaker Miyabi Core v3.0.0 Configuration
ENABLED=1
MODE="extreme"
FIREWALL=1
SMART_DOZE=1
TELEMETRY_MUTE=1
BOOT_SELF_HEAL=1
LIVE_DESC=1
BOOT_DELAY=45
EXCLUDE_VENDING=0
CUSTOM_EXCLUDE=""
EOF
else
  ui_print " - Preserving existing Miyabi Core configuration."
fi

# 6. Universal Multi-Partition Sysconfig XML Doze Patcher (Conflict-Safe)
ui_print " - Checking for conflicting GMS Doze modules..."
CONFLICT_MOD=""
for m in /data/adb/modules/*; do
  [ -d "$m" ] || continue
  mid=$(basename "$m")
  [ "$mid" = "gms-breaker-miyabi-core" ] && continue
  [ -f "$m/disable" ] || [ -f "$m/remove" ] && continue
  if find "$m" -name "*google*.xml" -path "*/sysconfig/*" 2>/dev/null | grep -q .; then
    CONFLICT_MOD="$mid"
    break
  fi
done

PATCH_COUNT=0
if [ -n "$CONFLICT_MOD" ]; then
  ui_print " [!] Existing sysconfig module found ($CONFLICT_MOD)."
  ui_print "     Skipping XML overlay to prevent module conflicts."
else
  ui_print " - Scanning partitions for GMS power-save XML whitelists..."
  SEEN_REALPATHS=""
  for ENTRY in \
    "/system/etc/sysconfig:system/etc/sysconfig" \
    "/product/etc/sysconfig:system/product/etc/sysconfig" \
    "/system_ext/etc/sysconfig:system/system_ext/etc/sysconfig" \
    "/vendor/etc/sysconfig:system/vendor/etc/sysconfig"; do

    SRC_DIR="${ENTRY%%:*}"
    REL_DST="${ENTRY#*:}"
    [ -d "$SRC_DIR" ] || continue

    # Deduplicate symlinked partitions (e.g. /system/product -> /product)
    REAL_DIR=$(realpath "$SRC_DIR" 2>/dev/null || echo "$SRC_DIR")
    case " $SEEN_REALPATHS " in
      *" $REAL_DIR "*) continue ;;
    esac
    SEEN_REALPATHS="$SEEN_REALPATHS $REAL_DIR"

    for XML in "$SRC_DIR"/*.xml; do
      [ -f "$XML" ] || continue
      if grep -qE 'allow-in-(power|data-usage)-save[[:space:]][^>]*package="com\.google\.android\.gms"' "$XML" 2>/dev/null; then
        XML_NAME=$(basename "$XML")
        DST_DIR="$MODPATH/$REL_DST"
        DST_FILE="$DST_DIR/$XML_NAME"
        mkdir -p "$DST_DIR"
        cp -f "$XML" "$DST_FILE"

        # Safely strip single-line GMS power-save & data-usage-save exemption tags (preserves allow-in-power-save-except-idle & valid XML)
        sed -i '/<allow-in-power-save[[:space:]][^>]*package="com\.google\.android\.gms"[^>]*\/>/d' "$DST_FILE" 2>/dev/null
        sed -i '/<allow-in-data-usage-save[[:space:]][^>]*package="com\.google\.android\.gms"[^>]*\/>/d' "$DST_FILE" 2>/dev/null

        # Validate patched XML integrity (anti-bootloop safety guard)
        if [ -s "$DST_FILE" ] && grep -q '</config>' "$DST_FILE" 2>/dev/null; then
          set_perm "$DST_FILE" 0 0 0644 2>/dev/null || chmod 0644 "$DST_FILE"
          PATCH_COUNT=$((PATCH_COUNT + 1))
          ui_print "   [+] Patched: $SRC_DIR/$XML_NAME"
        else
          rm -f "$DST_FILE"
          ui_print "   [!] Skipped invalid XML candidate: $XML_NAME"
        fi
      fi
    done
  done

  # Preserve existing patched sysconfig XMLs on dirty re-flash / OTA upgrade (when current overlay hides original tags)
  OLD_MOD="/data/adb/modules/gms-breaker-miyabi-core"
  if [ "$PATCH_COUNT" -eq 0 ] && [ -d "$OLD_MOD/system" ]; then
    for OLD_XML in \
      "$OLD_MOD"/system/etc/sysconfig/*.xml \
      "$OLD_MOD"/system/product/etc/sysconfig/*.xml \
      "$OLD_MOD"/system/system_ext/etc/sysconfig/*.xml \
      "$OLD_MOD"/system/vendor/etc/sysconfig/*.xml; do
      [ -f "$OLD_XML" ] || continue
      REL_XML="${OLD_XML#$OLD_MOD/}"
      DST_FILE="$MODPATH/$REL_XML"
      mkdir -p "$(dirname "$DST_FILE")"
      cp -f "$OLD_XML" "$DST_FILE"
      set_perm "$DST_FILE" 0 0 0644 2>/dev/null || chmod 0644 "$DST_FILE"
      PATCH_COUNT=$((PATCH_COUNT + 1))
      ui_print "   [+] Preserved existing patch: $REL_XML"
    done
  fi
  ui_print " - Sysconfig Doze Overlay: $PATCH_COUNT XML file(s) active."
fi
echo "$PATCH_COUNT" > "$STATE_DIR/sysconfig_patched" 2>/dev/null

# 7. Set Executable & Asset Permissions
ui_print " - Setting permissions & SELinux contexts..."
set_perm_recursive "$MODPATH" 0 0 0755 0644 2>/dev/null
for exec_file in \
  "$MODPATH/core.sh" \
  "$MODPATH/service.sh" \
  "$MODPATH/action.sh" \
  "$MODPATH/uninstall.sh" \
  "$MODPATH/post-fs-data.sh" \
  "$MODPATH/system/bin/miyabi"; do
  if [ -f "$exec_file" ]; then
    set_perm "$exec_file" 0 0 0755 2>/dev/null || chmod 0755 "$exec_file"
    restorecon "$exec_file" 2>/dev/null
  fi
done
[ -d "$MODPATH/webroot" ] && set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644 2>/dev/null

# 8. Install CLI Binary Fallbacks for KernelSU / APatch (works even without metamodule!)
for BIN_DIR in "/data/adb/ksu/bin" "/data/adb/apatch/bin" "/data/adb/ap/bin"; do
  if [ -d "$BIN_DIR" ]; then
    cp -f "$MODPATH/system/bin/miyabi" "$BIN_DIR/miyabi"
    chmod 0755 "$BIN_DIR/miyabi" 2>/dev/null
    restorecon "$BIN_DIR/miyabi" 2>/dev/null
    ui_print " - Installed Miyabi CLI to $BIN_DIR/miyabi"
  fi
done

ui_print "=================================================="
ui_print "       Installation Complete - Reboot Device      "
ui_print "  - WebUI  : Open via KernelSU / APatch / MMRL    "
ui_print "  - Action : Tap 'Action' for instant ON/OFF      "
ui_print "  - CLI    : Run 'su -c miyabi' in Termux         "
ui_print "=================================================="
ui_print " "

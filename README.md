# 🌸 GMS Breaker Miyabi Core

### Universal & Ultimate Account-Safe Google Services Isolation

GMS Breaker Miyabi Core is an advanced, ultra-performance Magisk/KernelSU/APatch module designed to aggressively isolate Google Play Services at runtime. It completely halts background telemetry, wakelocks, and sync without deleting Google accounts or modifying system partitions.

Built for users who prioritize **maximum gaming consistency, lower thermal throttling, reduced RAM footprint, and maximum battery life.**

---

##  Key Upgrades in v2.6.7

### 100% Universal Root Compatibility
- Works out-of-the-box on **Magisk**, **KernelSU**, and **APatch**.
- Uses system-native `/system/bin/sh` shebangs and standard shell POSIX syntax rather than hardcoded Magisk-only paths.

### Dual Apps & Multi-User Support
- Automatically scans and isolates GMS instances across all users on the device (User 0, Work Profiles, Parallel Space, Island, Shelter, Xiaomi Dual Apps, etc.).

### IPv4 + IPv6 Network Isolation
- Dynamically resolves UIDs for all target packages and drops both IPv4 (`iptables`) and IPv6 (`ip6tables`) traffic.
- **Leak Fix**: Implements safety checks to prevent rule duplication, solving networking overhead and memory leaks present in older versions.

### Ultra-Lightweight Native Daemon Loop
- Heavy Java VM commands (`cmd` / `am`) are replaced with lightweight native `pkill`/`pgrep` checks.
- Runs with virtually zero CPU overhead, executing periodic deep audits only if GMS is detected waking up or every 5 minutes.

---

## Targeted Packages
The module dynamically isolates the following packages if they are installed:
- `com.google.android.gms` (Google Play Services)
- `com.google.android.gsf` (Google Services Framework)
- `com.android.vending` (Google Play Store)
- `com.google.android.gms.setup` (GMS Setup Wizard)
- `com.google.android.feedback` (Google Feedback/Crash Reporting)
- `com.google.android.partnersetup` (Google Partner Setup)
- `com.google.android.onetimeinitializer` (One-Time Initializer)
- `com.google.android.backuptransport` (Backup Transport)
- `com.google.android.syncadapters.contacts` (Contacts Sync)
- `com.google.android.syncadapters.calendar` (Calendar Sync)
- `com.google.android.projection.gearhead` (Android Auto)
- `com.google.android.apps.gcs` (Google Connectivity Services)
- `com.google.android.gms.policy_sidecar` (GMS Policy Sidecar)
- `com.google.android.printservice.recommendation` (Print Service Recommendation)

---

## How It Works

1. **Initial Setup (At Boot)**:
   - Removes target packages from the global deviceidle whitelist.
   - Sets App Standby Buckets to `restricted` (Android 12+) or `rare` (Android < 12).
   - Suspends packages across all user profiles.
   - Sets critical AppOps to `ignore` (`RUN_IN_BACKGROUND`, `WAKE_LOCK`, `START_FOREGROUND`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `GET_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `WRITE_SETTINGS`).
   - Appends firewall rules to block network access for target UIDs.

2. **Daemon Loop (Every 20 Seconds)**:
   - Uses native `pgrep` to check if any GMS components are running.
   - If running, terminates them immediately via `pkill -9` and re-suspends them.
   - Enforces firewall rules and triggers a device deep-idle cycle.
   - Runs a full deep restriction re-apply cycle every 5 minutes.

---

## Compatibility

- **Android Versions**: Android 10, 11, 12, 13, 14, 15+
- **OS Flavors**: Stock Android, AOSP, MIUI, HyperOS, ColorOS, RealmeUI, OneUI, custom ROMs (SuperiorOS, LineageOS, Pixel Experience, etc.)
- **Chipsets**: Snapdragon, MediaTek, Exynos, Tensor, Unisoc

---

## Expected Behavior & Disclaimer

- Google Play Services will be completely suspended.
- Google push notifications (FCM) will stop working.
- Play Store downloading and sync will be paused.
- Google apps requiring sign-in or GMS (like YouTube, Drive, Maps) may not function correctly while the module is active.
- **Account-Safe**: Disabling the module in your root manager and rebooting fully restores normal behavior instantly without logging out.

---

## Miyabi CLI (Dynamic Live Toggle)

GMS Breaker Miyabi Core v2.6.7 features a command-line terminal utility to control the GMS blocking status in real-time **without needing a device reboot**. You can run these commands from any terminal emulator (such as Termux) with root access.

### Terminal Commands:
* **Temporarily Disable GMS Breaker** (Activate GMS for Google Maps/GPS location tracking, ride-hailing apps, Play Store downloads, or contact sync):
  ```bash
  su -c miyabi off
  ```
* **Re-enable GMS Breaker** (Instantly freeze GMS and optimize background environment for maximum gaming performance):
  ```bash
  su -c miyabi on
  ```
* **Check Isolation & Firewall Status**:
  ```bash
  su -c miyabi status
  ```

> [!NOTE]
> **Self-Healing Boot Reset**: If you temporarily disable GMS (`su -c miyabi off`) and forget to turn it back on, GMS Breaker will automatically re-enable itself and freeze GMS upon the next device reboot to safeguard your gaming performance and battery life.

---

## Clean Uninstallation

When you disable/remove the module and reboot, the dynamic uninstallation script automatically:
1. Dynamic UID lookup removes all IPv4 & IPv6 firewall rules.
2. Un-suspends all target packages across all active user profiles.
3. Resets AppOps back to default values.
4. Restores packages to the deviceidle whitelist.



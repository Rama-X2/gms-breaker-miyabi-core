# 🌸 GMS Breaker Miyabi Core

### Universal & Ultimate Account-Safe Google Services Isolation

GMS Breaker Miyabi Core is an advanced, ultra-performance Magisk/KernelSU/APatch module designed to aggressively isolate Google Play Services at runtime. It completely halts background telemetry, wakelocks, and sync without deleting Google accounts or modifying system partitions.

Built for users who prioritize **maximum gaming consistency, lower thermal throttling, reduced RAM footprint, and maximum battery life.**

---

## Key Upgrades in v3.0.0

### 100% Universal Root Compatibility
- Works out-of-the-box on **Magisk**, **KernelSU**, **KernelSU-Next**, and **APatch** (plus standard `META-INF` installer support for TWRP/OrangeFox).
- Uses system-native `/system/bin/sh` shebangs and standard POSIX shell syntax rather than hardcoded Magisk-only paths.

### Built-in WebUI & 1-Tap Action Button
- Includes a lightweight, 100% offline **WebUI** (`webroot/index.html`) for KernelSU, APatch, MMRL, and WebUI-X with automatic Light/Dark system theme support, live GMS RAM monitoring, profile switching, package exclusions, and operational logs.
- Includes a **1-Tap Action Button** (`action.sh`) for Magisk 28+, KernelSU, and APatch to pause or resume GMS isolation immediately from the module card without opening a terminal.

### 3 Live-Switchable Isolation Profiles
- Defaults to **Extreme** mode on fresh installation so users get full isolation immediately after flashing and rebooting.
- Switch live without rebooting between **`doze`** (Smart Doze, push notifications & Play Store working), **`balanced`** (background restricted, foreground ready), and **`extreme`** (full network & runtime isolation).

### Triple-Layer Network Isolation (nftables + iptables + netpolicy)
- Prioritizes native **`nftables`** (`inet miyabi_core` with `meta skuid`) on modern Android 14/15/16 kernels for IPv4 and IPv6 simultaneously.
- Falls back cleanly to a dedicated **`iptables` / `ip6tables` custom chain (`MIYABI_BLOCK`)** with `-w` lock handling—preventing rule duplication, memory leaks, and conflicts with VPNs, Clash, AdAway, or AFWall+.
- Pairs with Android native eBPF background data restriction (`cmd netpolicy`).

### Multi-Partition Sysconfig XML Doze Overlay
- Automatically scans `/system`, `/product`, `/system_ext`, and `/vendor` during installation to systemlessly remove hardcoded `com.google.android.gms` power-save whitelists.
- Includes XML integrity checks, conflict detection against other GMS Doze modules, and automatic patch preservation across upgrades.

### Dual Apps & Multi-User Support
- Automatically scans and isolates GMS instances across all users on the device (User 0, Work Profiles, Parallel Space, Island, Shelter, Xiaomi Dual Apps, etc.).

### Ultra-Lightweight Watchdog & Screen-Off Smart Doze
- Resolves package UIDs directly from `/data/system/packages.list` with zero Java VM overhead and atomic locking.
- Replaces heavy periodic re-apply loops with a lightweight 60-second watchdog that verifies firewall integrity and triggers deep Doze **only when the screen is off and unplugged** (zero mid-game stutter or Zygisk deadlock).

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
- `com.google.android.gms.location.history` (Google Location History)

---

## How It Works

1. **Initial Setup (At Boot)**:
   - Waits safely for system services to settle (`45s` default) to prevent early-boot Binder thread exhaustion.
   - Removes target packages from the global `deviceidle` whitelist (backed by the systemless `sysconfig` XML Doze overlay).
   - Sets App Standby Buckets to `restricted` (Android 12+) or `rare` (Android < 12).
   - Sets critical AppOps to `ignore` (`RUN_IN_BACKGROUND`, `RUN_ANY_IN_BACKGROUND`, `WAKE_LOCK`, `START_FOREGROUND`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `GET_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `WRITE_SETTINGS`) across all user profiles.
   - Performs a single clean `am force-stop` on target packages (never inside rapid loops, avoiding Zygisk deadlocks).
   - Optionally mutes strictly telemetry-only GMS sub-components (Analytics, Measurement, Ads ID, UsageReporting) without affecting OAuth, FCM core, or Play Integrity.
   - Applies UID-level network isolation via `nftables` (`inet miyabi_core`) or dedicated `iptables`/`ip6tables` chains (`MIYABI_BLOCK`) plus `cmd netpolicy`.

2. **Watchdog Daemon Loop (Every 60 Seconds)**:
   - Runs with virtually zero CPU and Binder overhead.
   - Monitors firewall table integrity and automatically re-applies rules if flushed by VPN or network changes.
   - Triggers deep device idle only when the screen is off and the device is not charging.

---

## Compatibility

- **Root Managers**: Magisk (v20.4–v28+), KernelSU, KernelSU-Next, APatch, SukiSU, MMRL
- **Android Versions**: Android 10, 11, 12, 13, 14, 15, 16+
- **OS Flavors**: Stock Android, AOSP, MIUI, HyperOS, ColorOS, RealmeUI, OneUI, custom ROMs (SuperiorOS, LineageOS, Pixel Experience, crDroid, etc.)
- **Chipsets**: Snapdragon, MediaTek, Exynos, Tensor, Unisoc

---

## Expected Behavior & Disclaimer

- By default, the module starts in **Extreme** mode for maximum gaming and battery isolation.
- In **Extreme** mode, Google push notifications (FCM), Play Store downloads, and background sync are paused while active (switch to `doze` mode or exclude `com.android.vending` anytime if you want notifications or Play Store active).
- Google apps requiring live GMS connectivity (such as Maps, Drive, or Play Store) may not function properly in **Extreme** mode until paused or switched to `doze` / `balanced`.
- **Stability Safe**: Never uses `SIGSTOP`, `cmd package suspend`, or `cmd appops reset`—safe for Magisk Manager, Zygisk, DenyList, HMA, Play Integrity, and MIUI/HyperOS app permissions.
- **Account-Safe**: Pausing via WebUI/Action/CLI or removing the module and rebooting restores normal behavior instantly without logging out of your Google account.

---

## Miyabi CLI (Dynamic Live Toggle)

GMS Breaker Miyabi Core v3.0.0 features an instant command-line utility to control isolation status, profiles, and settings in real-time **without needing a device reboot**. You can run these commands from any terminal emulator (such as Termux) with root access.

### Terminal Commands:

- **Temporarily Disable GMS Breaker** (Activate GMS for Google Maps/GPS location tracking, ride-hailing apps, Play Store downloads, or contact sync):
  ```
  su -c miyabi off
  ```

- **Re-enable GMS Breaker** (Instantly isolate GMS and optimize background environment for maximum gaming performance):
  ```
  su -c miyabi on
  ```

- **Quick Toggle ON / OFF**:
  ```
  su -c miyabi toggle
  ```

- **Check Isolation, RAM & Firewall Status**:
  ```
  su -c miyabi status
  ```

- **Switch Isolation Profile Live** (`doze` for push-notif safe daily use, `balanced` for hybrid, `extreme` for max gaming):
  ```
  su -c miyabi mode doze
  su -c miyabi mode balanced
  su -c miyabi mode extreme
  ```

- **One-Shot Gaming Boost or Clean Sweep**:
  ```
  su -c miyabi gaming
  su -c miyabi clean
  ```

- **Exclude or Re-include a Specific Package** (for example, keep Play Store working while isolating GMS):
  ```
  su -c miyabi exclude com.android.vending
  su -c miyabi include com.android.vending
  ```

- **Run System Diagnostics or View Logs**:
  ```
  su -c miyabi doctor
  su -c miyabi log
  ```

> [!NOTE]
> **Self-Healing Boot Reset**: If you temporarily disable GMS (`su -c miyabi off`) and forget to turn it back on, GMS Breaker will automatically re-enable itself upon the next device reboot to safeguard your gaming performance and battery life. You can toggle this behavior anytime via WebUI or `su -c miyabi config boot_self_heal 0`.

---

## Clean Uninstallation

When you disable/remove the module and reboot, the dynamic uninstallation script automatically:

1. Deletes the `inet miyabi_core` `nftables` table, `MIYABI_BLOCK` `iptables`/`ip6tables` chains, legacy `OUTPUT` rules, and `cmd netpolicy` entries.
2. Surgically restores all targeted Google AppOps back to `allow` across all active user profiles without touching third-party app permissions.
3. Resets App Standby Buckets back to `active` and restores packages to the `deviceidle` whitelist.
4. Re-enables all muted telemetry sub-components.
5. Cleans up `/data/adb/miyabi_core` state files and KernelSU/APatch CLI fallback binaries.

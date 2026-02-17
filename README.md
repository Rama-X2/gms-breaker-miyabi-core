# 🌸 GMS Breaker Miyabi Core

### Account-Safe Maximum Performance Mode

GMS Breaker Miyabi Core is a Magisk module designed to aggressively isolate Google Play Services at runtime without deleting Google accounts or modifying system partitions.

This module is built for users who prioritize:

- Maximum performance
- Lower CPU wake cycles
- Reduced RAM usage
- Minimal background telemetry
- Gaming-focused optimization
- Better idle battery life

---

## Features

### Runtime Isolation Engine
- Suspend Google Play Services packages
- Continuous force-stop loop
- Remove device idle whitelist entries
- Enforce deep doze state

### AppOps Hard Restriction
- Deny background execution
- Deny wakelocks
- Deny alarm scheduling
- Deny boot completion
- Deny background service start

### Network Isolation
- UID-based iptables isolation
- Blocks silent background sync
- Prevents hidden telemetry activity

### Account-Safe Design
- Does NOT remove Google accounts
- Does NOT delete data partitions
- Fully reversible by disabling module

---

## Target Compatibility

- Android 11
- Android 12
- Android 13
- Android 14
- Android 15

Optimized for:
- MIUI
- SuperiorOS

Universal AOSP compatible.

---

## Expected Behavior

After installation:

- Google Play Services will be suspended
- Push notifications will stop working
- Play Store background sync disabled
- Google apps may not function correctly
- System performance becomes more consistent under load
- Reduced idle battery drain

---

## Who Should Use This?

- Gamers
- Performance enthusiasts
- Users who do not rely on Google push services
- Users who toggle module ON/OFF manually

---

## Who Should NOT Use This?

- Banking app users
- Real-time notification dependent users
- Users requiring Google authentication services constantly

---

## Safety Design

- No system.prop modifications
- Minimal SELinux policy rules
- No permissive mode
- No system partition changes
- Fully reversible

---

## How To Restore Normal Behavior

Simply disable the module in Magisk and reboot.

Your Google account remains intact.
No need to login again.

---

## Disclaimer

This module is aggressive by design.
Use at your own risk.


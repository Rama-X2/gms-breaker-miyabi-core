#!/system/bin/sh
# GMS Breaker Miyabi Core v3.0.0 - post-fs-data.sh
# System services (pm/cmd/netpolicy/appops) are not initialized during post-fs-data.
# All runtime isolation logic runs safely in service.sh + core.sh after boot completion.
exit 0

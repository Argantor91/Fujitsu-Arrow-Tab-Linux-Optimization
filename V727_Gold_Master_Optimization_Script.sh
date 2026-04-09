#!/bin/bash

# ==============================================================================
# V727 Gold Master Implementation Script
# Version: 2026.04.09 (Fedora 43 Optimized)
# Target: Fujitsu Arrows Tab V727 (Intel Kaby Lake-Y)
# Goal: Maximize S0ix/PC10 Residency (Sub-0.8W SoC Idle)
# ==============================================================================

set -e

# 1. Root Privilege Check
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script must be executed as root (sudo)." 
   exit 1
fi

echo "INITIALIZING: V727 S0ix/PC10 Terminal Optimization Stack..."

# 2. Neutralize Power-Profiles-Daemon
# We mask it to ensure Tuned has exclusive control over hardware governors.
echo "STEP 1: Masking power-profiles-daemon to prevent conflicts."
systemctl disable --now power-profiles-daemon.service || true
systemctl mask power-profiles-daemon.service

# 3. Dependency Installation
# tuned-ppd provides the D-Bus bridge for KDE Plasma 6's power slider.
echo "STEP 2: Installing core power management utilities."
dnf install -y tuned tuned-ppd kernel-tools intel-pmc-core powertop

# 4. Create Tuned Profile Directory
PROFILE_DIR="/etc/tuned/v727-ultra-low-power"
mkdir -p "$PROFILE_DIR"

# 5. Deploy Tuned Profile Configuration
# Uses [bootloader] plugin for atomic parameter injection into BLS entries.
echo "STEP 3: Deploying [bootloader] and [pm] profile definitions."
cat << 'EOF' > "$PROFILE_DIR/tuned.conf"
[main]
summary=V727 S0ix/PC10 Terminal Optimization
include=laptop-battery-powersave

[bootloader]
# Atomic injection via BLS; survives kernel updates.
cmdline=+i915.enable_psr=1 +i915.enable_fbc=1 +i915.enable_dc=2 +intel_idle.max_cstate=10 +pcie_aspm=force +nvme_core.default_ps_max_latency_us=5500

[cpu]
governor=powersave
energy_perf_bias=powersave

[pm]
runtime_pm=auto
pcie_aspm=force

[sysctl]
kernel.nmi_watchdog=0
vm.dirty_writeback_centisecs=1500
vm.laptop_mode=5
EOF

# 6. Deploy Udev Rule for Realtek SD Controller
# The rtsx_pci device is the #1 blocker of PC10 on the V727.
echo "STEP 4: Deploying udev rule for rtsx_pci autosuspend."
cat << 'EOF' > /etc/udev/rules.d/50-rtsx-autosuspend.rules
# Unblock PC10 by forcing runtime PM on the Realtek PCIe controller
ACTION=="add", SUBSYSTEM=="pci", DRIVER=="rtsx_pci", ATTR{power/control}="auto"
EOF

# Apply udev rules immediately
udevadm control --reload-rules && udevadm trigger

# 7. Deploy PC10 Delta Logging System
echo "STEP 5: Deploying diagnostic logging units."
mkdir -p /var/cache
touch /var/cache/v727_pc10_last /var/log/v727_power.log

cat << 'EOF' > /etc/systemd/system/v727-residency-log.service
[Unit]
Description=Log PC10 Residency Delta
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'NOW=$(cat /sys/kernel/debug/intel_pmc_core/pc10_counter 2>/dev/null || echo 0); LAST=$(cat /var/cache/v727_pc10_last 2>/dev/null || echo $NOW); DELTA=$((NOW - LAST)); echo "$NOW" > /var/cache/v727_pc10_last; echo "$(date +%%FT%%T%%z) | ΔPC10: $DELTA ticks | Abs: $NOW" >> /var/log/v727_power.log'
EOF

cat << 'EOF' > /etc/systemd/system/v727-residency-log.timer
[Unit]
Description=Hourly PC10 Residency Check

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 8. Initialization & Activation
echo "STEP 6: Activating profile and systemd timers."
systemctl daemon-reload
systemctl enable --now v727-residency-log.timer

# Activate Tuned Profile (This handles the bootloader parameters)
tuned-adm profile v727-ultra-low-power

echo "--------------------------------------------------------------------------------"
echo "COMPLETE: V727 Gold Master Configuration applied."
echo "ACTION REQUIRED: Perform a 'sudo reboot' to initialize [bootloader] parameters."
echo "--------------------------------------------------------------------------------"
echo "VERIFICATION (After Reboot):"
echo "1. Check GPU DC6: sudo cat /sys/kernel/debug/dri/0/i915_dmc_info"
echo "2. Check ASPM L1.2: sudo lspci -vvv | grep -i 'L1SubCtl'"
echo "3. Monitor residency: tail -f /var/log/v727_power.log"
echo "--------------------------------------------------------------------------------"

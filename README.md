# Fujitsu-Arrow-Tab-Linux-Optimization

This script implements the Gold Master optimization stack for the Fujitsu Arrows Tab V727 on Fedora KDE 43. It targets the Kaby Lake-Y architecture to achieve sub-0.8W SoC idle power by unblocking PCIe, GPU, and CPU power states.

Post-Installation Verification
Governor Control: KDE Plasma 6 will still show the battery slider, but tuned-ppd ensures that moving the slider communicates with tuned instead of the masked power-profiles-daemon.

PCIe State: Run sudo lspci -vvv and ensure that the NVMe and Wireless controllers show L1.2 Enabled.

SoC Package Power: After 5 minutes of idle, run sudo powertop. Under the Power est. or Package tab, the "SoC Package Power" should fluctuate between 0.6W and 0.8W.

Logging: Every hour, /var/log/v727_power.log will record if the hardware successfully transitioned into PC10. If ΔPC10 is 0, a background process or connected USB-C device is blocking deep sleep.

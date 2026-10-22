#!/bin/bash
cat << 'EOF' > /etc/udev/rules.d/52-mtk.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0e8d", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="tty", ATTRS{idVendor}=="0e8d", MODE="0666", TAG+="uaccess"
EOF
udevadm control --reload-rules
udevadm trigger
echo "udev rules installed and reloaded successfully!"

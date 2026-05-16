#!/bin/bash
sudo tee /etc/dnf/plugins/post-transaction-actions.d/asusctl-fix.action > /dev/null <<EOF
asusd.* in dirname
mkdir -p /etc/asusd
chmod 755 /etc/asusd
touch /etc/asusd/asusd.conf
EOF

sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl supergfxctl rog-gui
sudo systemctl enable --now asusd supergfxd

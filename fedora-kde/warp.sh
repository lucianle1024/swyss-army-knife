#!/bin/bash

# Exit immediately if any command fails
set -e

PACKAGE_VERSION="2026.3.846.0"
RPM_FILE="cloudflare-warp-${PACKAGE_VERSION}.x86_64.rpm"
DOWNLOAD_URL="https://pkg.cloudflareclient.com/rpm/x86_64/${RPM_FILE}"

# 1. Download the specific working RPM version
curl -L -O "$DOWNLOAD_URL"

# 2. Install the local RPM package via DNF
sudo dnf install -y "./${RPM_FILE}"

# 3. Prevent DNF from breaking the package on future system updates
sudo dnf config-manager --save --setopt=cloudflare-warp-stable.excludepkgs=cloudflare-warp

# 4. Clean up the downloaded file
rm -f "./${RPM_FILE}"

# 5. Start and enable the system service
sudo systemctl enable --now warp-svc

# 6. Initialize registration (only if haven't registered before)
if ! warp-cli status | grep -q "Registration Missing"; then
    warp-cli registration new
fi

# 7. Connect to WARP
warp-cli connect

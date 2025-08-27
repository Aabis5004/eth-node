#!/bin/bash

echo ""
echo "============================================"
echo "  Installing Geth-Prysm Node Checker...    "
echo "============================================"
echo ""

# Download the checker script
echo "📥 Downloading node checker..."
curl -sSL https://raw.githubusercontent.com/Aabis5004/geth-prysm-checker/main/node-check.sh -o /tmp/node-check

if [ $? -ne 0 ]; then
    echo "❌ Failed to download!"
    exit 1
fi

# Make executable and install
chmod +x /tmp/node-check
sudo mv /tmp/node-check /usr/local/bin/node-check

echo ""
echo "✅ Installation Complete!"
echo ""
echo "Usage:"
echo "  node-check      - Run diagnostic"
echo "  sudo node-check - Full analysis with firewall"
echo ""

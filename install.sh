#!/bin/bash

echo "======================================"
echo "   Installing ETH Node Checker...    "
echo "======================================"
echo ""

# Download the diagnostic script
echo "⏬ Downloading diagnostic tool..."
curl -sSL https://raw.githubusercontent.com/Aabis5004/eth-node-checker/main/check.sh -o /tmp/eth-check 2>/dev/null

if [ $? -ne 0 ]; then
    echo "❌ Download failed. Please check your internet connection."
    exit 1
fi

# Make it executable
chmod +x /tmp/eth-check

# Move to system path (needs sudo)
echo "📦 Installing to system..."
sudo mv /tmp/eth-check /usr/local/bin/eth-check

if [ $? -ne 0 ]; then
    echo "❌ Installation failed. Try running with: curl ... | sudo bash"
    exit 1
fi

echo ""
echo "✅ Installation Complete!"
echo ""
echo "Usage:"
echo "  eth-check        # Run diagnostic"
echo "  sudo eth-check   # Run with full permissions"
echo ""

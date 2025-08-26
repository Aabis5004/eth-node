#!/bin/bash

# Ethereum Node Checker - Quick Installer

echo ""
echo "======================================"
echo "   ETH Node Checker Installation     "
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "⚠️  Running as root"
fi

# Download the diagnostic script
echo "📥 Downloading diagnostic tool..."
curl -sSL https://raw.githubusercontent.com/Aabis5004/eth-node-checker/main/check.sh -o /tmp/eth-check 2>/dev/null

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Error: Download failed!"
    echo "Please check:"
    echo "  1. Internet connection"
    echo "  2. GitHub username is correct"
    exit 1
fi

# Make executable
chmod +x /tmp/eth-check

# Install to system
echo "📦 Installing to system..."
if [ -w /usr/local/bin ]; then
    mv /tmp/eth-check /usr/local/bin/eth-check
else
    sudo mv /tmp/eth-check /usr/local/bin/eth-check
fi

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Error: Installation failed!"
    echo "Try running with sudo:"
    echo "  curl -sSL ... | sudo bash"
    exit 1
fi

echo ""
echo "✅ Installation Complete!"
echo ""
echo "═══════════════════════════════════════"
echo "  Usage:"
echo "    eth-check         - Run diagnostic"
echo "    sudo eth-check    - Full analysis"
echo "═══════════════════════════════════════"
echo ""
echo "Run 'eth-check' now to test your node!"
echo ""

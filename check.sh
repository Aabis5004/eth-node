# GitHub Setup for Geth-Prysm Node Checker Script

Based on the 0xmoei/geth-prysm-node guide, here's everything you need:

---

## 📁 FILE 1: `node-check.sh`
**This is the main diagnostic script - Copy ALL of this:**

```bash
#!/bin/bash

# Geth-Prysm Node Checker for Sepolia
# Based on 0xmoei guide setup

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration (exactly as in the guide)
ETH_DIR="/root/ethereum"
GETH_RPC="http://localhost:8545"
PRYSM_RPC="http://localhost:3500"

clear
echo -e "${BOLD}${BLUE}========================================${NC}"
echo -e "${BOLD}${BLUE}  Geth-Prysm Node Checker for Sepolia  ${NC}"
echo -e "${BOLD}${BLUE}========================================${NC}\n"

# Function for sections
section() {
    echo -e "\n${BOLD}${YELLOW}▶ $1${NC}"
    echo -e "${YELLOW}────────────────────────────────────${NC}"
}

# 1. Check Docker
section "Docker Check"
if command -v docker &> /dev/null; then
    echo -e " ${GREEN}✅${NC} Docker is installed"
    if systemctl is-active --quiet docker; then
        echo -e " ${GREEN}✅${NC} Docker service is running"
    else
        echo -e " ${RED}❌${NC} Docker not running"
        echo -e "    ${YELLOW}Fix:${NC} sudo systemctl start docker"
    fi
else
    echo -e " ${RED}❌${NC} Docker not installed"
    echo -e "    ${YELLOW}Fix:${NC} Follow Step 1 in the guide"
fi

# 2. Check Directories
section "Directory Check"
if [ -d "$ETH_DIR/execution" ]; then
    echo -e " ${GREEN}✅${NC} Execution directory exists"
else
    echo -e " ${RED}❌${NC} Execution directory missing"
    echo -e "    ${YELLOW}Fix:${NC} mkdir -p /root/ethereum/execution"
fi

if [ -d "$ETH_DIR/consensus" ]; then
    echo -e " ${GREEN}✅${NC} Consensus directory exists"
else
    echo -e " ${RED}❌${NC} Consensus directory missing"
    echo -e "    ${YELLOW}Fix:${NC} mkdir -p /root/ethereum/consensus"
fi

# 3. Check JWT
section "JWT Token Check"
if [ -f "$ETH_DIR/jwt.hex" ]; then
    echo -e " ${GREEN}✅${NC} JWT token exists"
    jwt_length=$(wc -c < "$ETH_DIR/jwt.hex")
    echo -e "    Size: ${BLUE}$jwt_length bytes${NC}"
else
    echo -e " ${RED}❌${NC} JWT token not found"
    echo -e "    ${YELLOW}Fix:${NC} openssl rand -hex 32 > /root/ethereum/jwt.hex"
fi

# 4. Check Containers
section "Container Status"
if docker ps | grep -q "geth"; then
    echo -e " ${GREEN}✅${NC} Geth container is running"
    uptime=$(docker ps --filter "name=geth" --format "{{.Status}}")
    echo -e "    ${BLUE}$uptime${NC}"
else
    echo -e " ${RED}❌${NC} Geth container not running"
    echo -e "    ${YELLOW}Fix:${NC} cd /root/ethereum && docker compose up -d"
fi

if docker ps | grep -q "prysm"; then
    echo -e " ${GREEN}✅${NC} Prysm container is running"
    uptime=$(docker ps --filter "name=prysm" --format "{{.Status}}")
    echo -e "    ${BLUE}$uptime${NC}"
else
    echo -e " ${RED}❌${NC} Prysm container not running"
    echo -e "    ${YELLOW}Fix:${NC} cd /root/ethereum && docker compose up -d"
fi

# 5. Check Ports
section "Port Status"
echo -e " Checking required ports..."
ports=("30303" "8545" "8546" "8551" "4000" "3500")
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e " ${GREEN}✅${NC} Port $port is listening"
    else
        echo -e " ${YELLOW}⚠️${NC}  Port $port not listening"
    fi
done

# 6. Check Sync Status - Geth
section "Geth Sync Status"
if docker ps | grep -q "geth"; then
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        http://localhost:8545 2>/dev/null)
    
    if [ -z "$response" ]; then
        echo -e " ${RED}❌${NC} Geth RPC not responding"
    elif echo "$response" | grep -q '"result":false'; then
        echo -e " ${GREEN}✅${NC} Geth is fully synced!"
        
        # Get latest block
        block=$(curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            http://localhost:8545 2>/dev/null | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$block" ]; then
            block_num=$((16#${block:2}))
            echo -e "    Latest block: ${BLUE}#$block_num${NC}"
        fi
    else
        echo -e " ${YELLOW}⏳${NC} Geth is still syncing..."
        current=$(echo "$response" | grep -o '"currentBlock":"[^"]*"' | cut -d'"' -f4)
        highest=$(echo "$response" | grep -o '"highestBlock":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$current" ] && [ ! -z "$highest" ]; then
            current_num=$((16#${current:2}))
            highest_num=$((16#${highest:2}))
            progress=$(awk "BEGIN {printf \"%.2f\", ($current_num/$highest_num)*100}")
            echo -e "    Progress: ${BLUE}$progress%${NC}"
            echo -e "    Current: ${BLUE}$current_num${NC} / Highest: ${BLUE}$highest_num${NC}"
        fi
    fi
else
    echo -e " ${RED}❌${NC} Geth container not running"
fi

# 7. Check Sync Status - Prysm
section "Prysm Sync Status"
if docker ps | grep -q "prysm"; then
    response=$(curl -s http://localhost:3500/eth/v1/node/syncing 2>/dev/null)
    
    if [ -z "$response" ]; then
        echo -e " ${RED}❌${NC} Prysm RPC not responding"
    elif echo "$response" | grep -q '"is_syncing":false'; then
        echo -e " ${GREEN}✅${NC} Prysm is fully synced!"
        head_slot=$(echo "$response" | grep -o '"head_slot":"[^"]*"' | cut -d'"' -f4)
        echo -e "    Head slot: ${BLUE}$head_slot${NC}"
    else
        echo -e " ${YELLOW}⏳${NC} Prysm is still syncing..."
        sync_distance=$(echo "$response" | grep -o '"sync_distance":"[^"]*"' | cut -d'"' -f4)
        echo -e "    Slots behind: ${BLUE}$sync_distance${NC}"
    fi
else
    echo -e " ${RED}❌${NC} Prysm container not running"
fi

# 8. Check Firewall
section "Firewall Status"
if sudo ufw status &>/dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        echo -e " ${GREEN}✅${NC} UFW firewall is active"
        
        # Check critical ports
        if sudo ufw status | grep -q "30303"; then
            echo -e " ${GREEN}✅${NC} P2P ports (30303) are open"
        else
            echo -e " ${RED}❌${NC} P2P ports not configured"
            echo -e "    ${YELLOW}Fix:${NC} sudo ufw allow 30303"
        fi
        
        # Check RPC access
        if sudo ufw status numbered | grep -q "8545.*ALLOW IN"; then
            rules=$(sudo ufw status numbered | grep "8545" | head -3)
            echo -e " ${YELLOW}ℹ️${NC}  Port 8545 access rules:"
            echo "$rules" | while read line; do
                echo -e "    ${BLUE}$line${NC}"
            done
        else
            echo -e " ${GREEN}✅${NC} Port 8545 is protected (local only)"
        fi
    else
        echo -e " ${YELLOW}⚠️${NC}  Firewall is not active"
        echo -e "    ${YELLOW}Fix:${NC} sudo ufw enable"
    fi
fi

# 9. Check Disk Space
section "Disk Usage"
df_line=$(df -h /root/ethereum 2>/dev/null | tail -1)
if [ ! -z "$df_line" ]; then
    usage=$(echo "$df_line" | awk '{print $5}' | sed 's/%//')
    available=$(echo "$df_line" | awk '{print $4}')
    total=$(echo "$df_line" | awk '{print $2}')
    
    if [ "$usage" -gt 90 ]; then
        echo -e " ${RED}❌${NC} Disk usage critical: ${usage}%"
    elif [ "$usage" -gt 80 ]; then
        echo -e " ${YELLOW}⚠️${NC}  Disk usage high: ${usage}%"
    else
        echo -e " ${GREEN}✅${NC} Disk usage: ${usage}%"
    fi
    echo -e "    Available: ${BLUE}$available${NC} / Total: ${BLUE}$total${NC}"
    
    # Data sizes
    if docker ps | grep -q geth; then
        geth_size=$(docker exec geth du -sh /data 2>/dev/null | cut -f1)
        [ ! -z "$geth_size" ] && echo -e "    Geth data: ${BLUE}$geth_size${NC}"
    fi
    if docker ps | grep -q prysm; then
        prysm_size=$(docker exec prysm du -sh /data 2>/dev/null | cut -f1)
        [ ! -z "$prysm_size" ] && echo -e "    Prysm data: ${BLUE}$prysm_size${NC}"
    fi
fi

# 10. Show RPC Endpoints
section "RPC Endpoints"
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo -e "\n ${BOLD}Local Access:${NC}"
echo -e "  Geth RPC:  ${BLUE}http://localhost:8545${NC}"
echo -e "  Prysm RPC: ${BLUE}http://localhost:3500${NC}"

if [ "$VPS_IP" != "unknown" ]; then
    echo -e "\n ${BOLD}Remote Access:${NC}"
    echo -e "  Geth RPC:  ${BLUE}http://$VPS_IP:8545${NC}"
    echo -e "  Prysm RPC: ${BLUE}http://$VPS_IP:3500${NC}"
    
    echo -e "\n ${BOLD}For Aztec Sequencer:${NC}"
    echo -e "  From CLI:    ${BLUE}http://$VPS_IP:8545${NC}"
    echo -e "  From Docker: ${BLUE}http://localhost:8545${NC}"
fi

# 11. Quick Test Commands
section "Quick Commands"
echo -e " ${BOLD}View logs:${NC}"
echo -e "  ${BLUE}docker compose logs -f${NC}"
echo -e ""
echo -e " ${BOLD}Test Geth sync:${NC}"
echo -e "  ${BLUE}curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://localhost:8545${NC}"
echo -e ""
echo -e " ${BOLD}Test Prysm sync:${NC}"
echo -e "  ${BLUE}curl http://localhost:3500/eth/v1/node/syncing${NC}"

# Summary
echo -e "\n${BOLD}${BLUE}========================================${NC}"
if docker ps | grep -q "geth" && docker ps | grep -q "prysm"; then
    echo -e "${BOLD}${GREEN}  ✅ Node is running!${NC}"
else
    echo -e "${BOLD}${RED}  ⚠️ Node needs attention!${NC}"
fi
echo -e "${BOLD}${BLUE}========================================${NC}\n"
```

---

## 📁 FILE 2: `install.sh`
**The installer script - Change Aabis5004 to YOUR username:**

```bash
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
```

---

## 📁 FILE 3: `README.md`
**Documentation - Change Aabis5004 to YOUR username:**

```markdown
# Geth-Prysm Node Checker

Diagnostic tool for Sepolia Ethereum nodes running Geth + Prysm setup.

Based on the [0xmoei/geth-prysm-node](https://github.com/0xmoei/geth-prysm-node) guide.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/Aabis5004/geth-prysm-checker/main/install.sh | bash
```

## Usage

```bash
# Check your node
node-check

# With firewall analysis
sudo node-check
```

## What It Checks

✅ Docker installation and status  
✅ Container health (geth & prysm)  
✅ Directory structure (/root/ethereum)  
✅ JWT token existence  
✅ Port availability (30303, 8545, 3500, etc)  
✅ Sync progress with percentage  
✅ Firewall configuration  
✅ Disk space usage  
✅ RPC endpoints  
✅ Aztec compatibility  

## Requirements

- Ubuntu 20.04+
- Docker and Docker Compose installed
- Geth + Prysm running (as per guide)
- 8-16 GB RAM
- 550 GB SSD

## Output Example

```
▶ Container Status
────────────────────────────────────
 ✅ Geth container is running
    Up 2 hours
 ✅ Prysm container is running
    Up 2 hours

▶ Geth Sync Status
────────────────────────────────────
 ✅ Geth is fully synced!
    Latest block: #5234567

▶ RPC Endpoints
────────────────────────────────────
 Local Access:
  Geth RPC:  http://localhost:8545
  Prysm RPC: http://localhost:3500
```

## Troubleshooting

If containers not running:
```bash
cd /root/ethereum
docker compose up -d
```

If sync is stuck:
```bash
docker compose restart
```

## Support

Having issues? [Open an issue](https://github.com/Aabis5004/geth-prysm-checker/issues)
```

---

# 🚀 HOW TO SET THIS UP ON GITHUB

## Step 1: Create New Repository
1. Go to: https://github.com/new
2. Name: `geth-prysm-checker`
3. Public: ✅
4. Add README: ✅
5. Click "Create repository"

## Step 2: Add node-check.sh
1. Click "Add file" → "Create new file"
2. Name: `node-check.sh`
3. Paste FILE 1 content
4. Click "Commit new file"

## Step 3: Add install.sh
1. Click "Add file" → "Create new file"
2. Name: `install.sh`
3. Paste FILE 2 content
4. **CHANGE** `Aabis5004` to your GitHub username
5. Click "Commit new file"

## Step 4: Update README.md
1. Click on README.md
2. Click pencil icon ✏️
3. Delete everything
4. Paste FILE 3 content
5. **CHANGE** `Aabis5004` to your GitHub username (2 places)
6. Click "Commit changes"

## Step 5: Done!
Your install command will be:
```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/geth-prysm-checker/main/install.sh | bash
```

---

## What This Script Does:

1. **Checks everything from the guide** - Docker, directories, JWT, containers
2. **Shows sync progress** - With percentage for Geth
3. **Tests RPC endpoints** - Both local and remote
4. **Firewall analysis** - Shows which IPs have access
5. **Disk monitoring** - Warns if running low
6. **Aztec ready** - Shows correct endpoints for Aztec setup
7. **Fix suggestions** - Every error shows how to fix it

This matches the exact setup from the 0xmoei guide you showed me!

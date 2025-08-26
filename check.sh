#!/bin/bash

# Ethereum Node Diagnostics Tool - Simple Version
# For Geth + Prysm Sepolia Setup

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Config
GETH_RPC="http://localhost:8545"
PRYSM_RPC="http://localhost:3500"
ETH_DIR="$HOME/ethereum"
[ -d "/root/ethereum" ] && ETH_DIR="/root/ethereum"

clear
echo -e "${BOLD}${BLUE}======================================${NC}"
echo -e "${BOLD}${BLUE}   Ethereum Node Diagnostic Tool 🔍  ${NC}"
echo -e "${BOLD}${BLUE}======================================${NC}\n"

# Function to print sections
print_section() {
    echo -e "\n${BOLD}${YELLOW}▶ $1${NC}"
    echo -e "${YELLOW}──────────────────────────────────────${NC}"
}

# Check function
check() {
    if [ $1 -eq 0 ]; then
        echo -e " ${GREEN}✅ $2${NC}"
        [ ! -z "$3" ] && echo -e "    ${BLUE}$3${NC}"
    else
        echo -e " ${RED}❌ $2${NC}"
        [ ! -z "$3" ] && echo -e "    ${YELLOW}Fix: $3${NC}"
    fi
}

# 1. Docker Check
print_section "Docker Status"
if command -v docker &> /dev/null; then
    check 0 "Docker is installed"
    if systemctl is-active --quiet docker; then
        check 0 "Docker service is running"
    else
        check 1 "Docker service not running" "sudo systemctl start docker"
    fi
else
    check 1 "Docker not installed" "curl -fsSL https://get.docker.com | sudo sh"
fi

# 2. Container Status
print_section "Container Status"
if docker ps --format "{{.Names}}" | grep -q "^geth$"; then
    check 0 "Geth container is running"
else
    check 1 "Geth container not running" "cd $ETH_DIR && docker compose up -d"
fi

if docker ps --format "{{.Names}}" | grep -q "^prysm$"; then
    check 0 "Prysm container is running"
else
    check 1 "Prysm container not running" "cd $ETH_DIR && docker compose up -d"
fi

# 3. Directory Check
print_section "Configuration Check"
if [ -d "$ETH_DIR" ]; then
    check 0 "Ethereum directory exists" "$ETH_DIR"
else
    check 1 "Ethereum directory not found" "mkdir -p $ETH_DIR/{execution,consensus}"
fi

if [ -f "$ETH_DIR/jwt.hex" ]; then
    check 0 "JWT token exists"
else
    check 1 "JWT token not found" "openssl rand -hex 32 > $ETH_DIR/jwt.hex"
fi

# 4. Sync Status
print_section "Sync Status"

# Check Geth
if docker ps | grep -q geth; then
    geth_sync=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        $GETH_RPC 2>/dev/null)
    
    if [ -z "$geth_sync" ]; then
        check 1 "Geth RPC not responding"
    elif echo "$geth_sync" | grep -q '"result":false'; then
        check 0 "Geth is fully synced! 🎉"
        
        # Get block number
        block=$(curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            $GETH_RPC 2>/dev/null | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$block" ]; then
            block_dec=$((16#${block:2}))
            echo -e "    Latest block: ${BLUE}#$block_dec${NC}"
        fi
    else
        echo -e " ${YELLOW}⏳ Geth is syncing...${NC}"
        current=$(echo "$geth_sync" | grep -o '"currentBlock":"[^"]*"' | cut -d'"' -f4)
        highest=$(echo "$geth_sync" | grep -o '"highestBlock":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$current" ] && [ ! -z "$highest" ]; then
            current_dec=$((16#${current:2}))
            highest_dec=$((16#${highest:2}))
            progress=$(awk "BEGIN {printf \"%.2f\", ($current_dec/$highest_dec)*100}")
            echo -e "    Progress: ${BLUE}$progress%${NC} ($current_dec / $highest_dec)"
        fi
    fi
fi

# Check Prysm
if docker ps | grep -q prysm; then
    prysm_sync=$(curl -s $PRYSM_RPC/eth/v1/node/syncing 2>/dev/null)
    
    if [ -z "$prysm_sync" ]; then
        check 1 "Prysm RPC not responding"
    elif echo "$prysm_sync" | grep -q '"is_syncing":false'; then
        check 0 "Prysm is fully synced! 🎉"
    else
        echo -e " ${YELLOW}⏳ Prysm is syncing...${NC}"
        distance=$(echo "$prysm_sync" | grep -o '"sync_distance":"[^"]*"' | cut -d'"' -f4)
        echo -e "    Slots behind: ${BLUE}$distance${NC}"
    fi
fi

# 5. Port Check
print_section "Port Status"
ports=("30303" "8545" "3500")
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        check 0 "Port $port is listening"
    else
        echo -e " ${YELLOW}⚠️  Port $port not listening${NC}"
    fi
done

# 6. Disk Usage
print_section "Disk Usage"
df_output=$(df -h $ETH_DIR 2>/dev/null | tail -n 1)
if [ ! -z "$df_output" ]; then
    usage=$(echo $df_output | awk '{print $5}' | sed 's/%//')
    avail=$(echo $df_output | awk '{print $4}')
    
    if [ "$usage" -gt 90 ]; then
        check 1 "Disk usage critical: ${usage}%" "Clean up disk space"
    elif [ "$usage" -gt 80 ]; then
        echo -e " ${YELLOW}⚠️  Disk usage high: ${usage}%${NC}"
    else
        check 0 "Disk usage: ${usage}%" "Available: $avail"
    fi
fi

# 7. Firewall Check
print_section "Firewall Status"
if command -v ufw &> /dev/null; then
    if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        check 0 "UFW firewall is active"
        
        if sudo ufw status | grep -q "30303"; then
            check 0 "P2P port (30303) is open"
        else
            check 1 "P2P port not configured" "sudo ufw allow 30303"
        fi
    else
        echo -e " ${YELLOW}⚠️  Firewall is inactive${NC}"
    fi
fi

# 8. RPC Endpoints
print_section "RPC Endpoints"
external_ip=$(curl -s ifconfig.me 2>/dev/null)

echo -e "\n ${BOLD}Local Access:${NC}"
echo -e "  Geth:  ${BLUE}http://localhost:8545${NC}"
echo -e "  Prysm: ${BLUE}http://localhost:3500${NC}"

if [ ! -z "$external_ip" ]; then
    echo -e "\n ${BOLD}Remote Access:${NC}"
    echo -e "  Geth:  ${BLUE}http://$external_ip:8545${NC}"
    echo -e "  Prysm: ${BLUE}http://$external_ip:3500${NC}"
fi

# 9. Aztec Ready Check
print_section "Aztec Compatibility"

aztec_ready=true
geth_ready=false
prysm_ready=false

if docker ps | grep -q geth; then
    if curl -s -X POST $GETH_RPC -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' 2>/dev/null | \
        grep -q '"result":false'; then
        geth_ready=true
    fi
fi

if docker ps | grep -q prysm; then
    if curl -s $PRYSM_RPC/eth/v1/node/syncing 2>/dev/null | \
        grep -q '"is_syncing":false'; then
        prysm_ready=true
    fi
fi

if [ "$geth_ready" = true ] && [ "$prysm_ready" = true ]; then
    echo -e " ${GREEN}✅ Node is ready for Aztec!${NC}"
    echo -e "\n ${BOLD}Aztec Configuration:${NC}"
    echo -e "  ETHEREUM_HOST=${BLUE}http://$external_ip:8545${NC}"
    echo -e "  L1_RPC_URL=${BLUE}http://$external_ip:8545${NC}"
else
    echo -e " ${YELLOW}⏳ Node not ready - wait for sync to complete${NC}"
fi

# Summary
echo -e "\n${BOLD}${BLUE}======================================${NC}"
echo -e "${BOLD}Quick Commands:${NC}"
echo -e " View logs:    ${BLUE}docker compose logs -f${NC}"
echo -e " Restart:      ${BLUE}docker compose restart${NC}"
echo -e " Check sync:   ${BLUE}curl http://localhost:8545 -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}'${NC}"
echo -e "${BOLD}${BLUE}======================================${NC}\n"

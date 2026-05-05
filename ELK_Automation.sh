#!/bin/bash

# --- Color & Style Definitions ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
CHECKMARK="${GREEN}✔${NC}"

# --- Progress Bar Function ---
draw_progress() {
    local step=$1
    local total=$2
    local message=$3
    local width=30
    local percent=$(( (step * 100) / total ))
    local completed=$(( (step * width) / total ))
    local remaining=$(( width - completed ))

    printf "\r${CYAN}%d. %-27s${NC} ${BLUE}[${NC}" "$step" "$message"
    printf "%${completed}s" | tr ' ' '#'
    printf "%${remaining}s" | tr ' ' '-'
    printf "${BLUE}]${NC} ${YELLOW}%3d%%${NC}" "$percent"
}

# --- Completion Function ---
mark_done() {
    local step=$1
    local message=$2
    printf "\r\033[K${CYAN}%d. %-35s${NC}   ${GREEN}[ DONE ]${NC}\n" "$step" "$message"
}

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (sudo su –)${NC}"
  exit
fi

clear

# --- ASCII Header ---
echo -e "${CYAN}${BOLD}"
echo "  ______ _      _  __  ___  "
echo " |  ____| |    | |/ / / _ \ "
echo " | |__  | |    | ' / | (_) |"
echo " |  __| | |    |  <   \__, |"
echo " | |____| |____| . \    / / "
echo " |______|______|_|\_\  /_/  "
echo -e "      STACK AUTO-INSTALLER${NC}"
echo -e "     AUTHOR: Nand Gajera${NC}\n"


TOTAL_STEPS=8
CURRENT_STEP=0

# 1. Update & Dependencies
STEP_MSG="Updating Repositories..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg2 wget > /dev/null 2>&1
mark_done $CURRENT_STEP "$STEP_MSG"

# 2. Add GPG & Source
STEP_MSG="Adding Elastic Repos..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /etc/apt/trusted.gpg.d/elastic.gpg > /dev/null 2>&1
echo "deb https://artifacts.elastic.co/packages/9.x/apt stable main" > /etc/apt/sources.list.d/elastic-9.x.list
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
mark_done $CURRENT_STEP "$STEP_MSG"

# 3. Elasticsearch Installation
STEP_MSG="Installing Elasticsearch..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
DEBIAN_FRONTEND=noninteractive apt-get install -y elasticsearch > /dev/null 2>&1
mark_done $CURRENT_STEP "$STEP_MSG"

# 4. Elasticsearch Config & Password Reset
STEP_MSG="Configuring Elasticsearch..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#http.port: 9200/http.port: 9200/' /etc/elasticsearch/elasticsearch.yml
echo -e "-Xms4g\n-Xmx4g" > /etc/elasticsearch/jvm.options.d/jvm-heap.options
systemctl daemon-reload > /dev/null 2>&1
systemctl enable --now elasticsearch > /dev/null 2>&1

# Wait for service then Reset Password
sleep 10
ELASTIC_PASSWORD=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s)
mark_done $CURRENT_STEP "$STEP_MSG"

# 5. Kibana Installation
STEP_MSG="Installing Kibana..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
DEBIAN_FRONTEND=noninteractive apt-get install -y kibana > /dev/null 2>&1
mark_done $CURRENT_STEP "$STEP_MSG"

# 6. Kibana Config
STEP_MSG="Configuring Kibana..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
/usr/share/kibana/bin/kibana-encryption-keys generate | tail -n 4 >> /etc/kibana/kibana.yml 2>/dev/null
systemctl enable --now kibana > /dev/null 2>&1
mark_done $CURRENT_STEP "$STEP_MSG"

# 7. Token & OTP Generation
STEP_MSG="Generating Tokens..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"
MAX_RETRIES=30
RETRY_COUNT=0
KIBANA_OTP=""
while [ -z "$KIBANA_OTP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 3
    KIBANA_OTP=$(journalctl -u kibana --no-pager | grep -oP 'code=\K[0-9]+' | tail -1)
    RETRY_COUNT=$((RETRY_COUNT+1))
done
TOKEN=$(/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana 2>/dev/null)
IP_ADDR=$(hostname -I | awk '{print $1}')
mark_done $CURRENT_STEP "$STEP_MSG"

# 8. Saving Credentials
STEP_MSG="Finalizing Files..."
((CURRENT_STEP++))
draw_progress $CURRENT_STEP $TOTAL_STEPS "$STEP_MSG"

# Create Credentials File with Wrapped Token Table
FILE_PATH="./ELK_password.txt"
{
    echo "+-------------------------------------------------------------------------+"
    printf "| %-71s |\n" "ELK 9.X INSTALLATION CREDENTIALS"
    echo "+----------------------+--------------------------------------------------+"
    printf "| %-20s | %-48s |\n" "ITEM" "VALUE"
    echo "+----------------------+--------------------------------------------------+"
    printf "| %-20s | http://%-41s |\n" "Kibana URL" "$IP_ADDR:5601"
    printf "| %-20s | %-48s |\n" "Kibana OTP" "$KIBANA_OTP"
    printf "| %-20s | %-48s |\n" "Elastic User" "elastic"
    printf "| %-20s | %-48s |\n" "Elastic Password" "$ELASTIC_PASSWORD"
    echo "+----------------------+--------------------------------------------------+"
    printf "| %-71s |\n" "Enrollment Token:"
    
    # Wrap the token at 68 characters to fit within table borders
    echo "$TOKEN" | fold -w 68 | while read -r line; do
        printf "| %-71s |\n" "$line"
    done
    echo "+-------------------------------------------------------------------------+"
} > "$FILE_PATH"

mark_done $CURRENT_STEP "$STEP_MSG"

echo -e "\n${GREEN}${CHECKMARK} All steps completed successfully!${NC}\n"
cat "$FILE_PATH"

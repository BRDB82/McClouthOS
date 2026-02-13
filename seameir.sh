#!/bin/bash

#prototype installer for AlmaLinux

# "Luck is what happens when preparation meets opportunity."

#root-check
if [[ "$(id -u)" != "0" ]]; then
    echo -ne "!!ERROR!! This script must be as root, not with sudo.\n"
    exit 0
fi

if [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/seameir.sh?v=$RANDOM" -o "./seameir.new" || {
		echo "update failed"
	    rm "./seameir.new"
	    exit 1
	}
	chmod +x "seameir.new"
	mv -f "./seameir.new" "./seameir.sh"
	echo "seameir updated, please restart..."
	exit 0
fi

log_file="/root/seamair.log"
set_fixed_ip="N"

# --- Color Palette ---
NEON='\033[38;5;46m'
WHITE='\033[1;37m'
GOLD='\033[38;5;226m'
NC='\033[0m'

# --- Configuration ---
chars="0101☘01☘"
duration=5 

# Get dimensions with hardcoded fallbacks if stty fails
cols=$(stty size 2>/dev/null | awk '{print $2}')
lines=$(stty size 2>/dev/null | awk '{print $1}')
: ${cols:=80}
: ${lines:=24}

# Clean start
printf "\e[2J\e[H\e[?25l"

# --- The Rain Loop ---
start_time=$(date +%s)
while [ $(( $(date +%s) - start_time )) -lt $duration ]; do
    col=$((RANDOM % cols))
    len=$(( (RANDOM % lines) / 2 + 5 ))
    
    for ((j=0; j<len; j++)); do
        row=$((j % lines))
        
        # Position cursor using ANSI
        printf "\e[${row};${col}H"
        
        if [ $j -eq $((len-1)) ]; then
            printf "${WHITE}${chars:$((RANDOM%${#chars})):1}${NC}"
        else
            if [ $((RANDOM % 20)) -eq 0 ]; then
                printf "${GOLD}☘${NC}"
            else
                printf "${NEON}${chars:$((RANDOM%${#chars})):1}${NC}"
            fi
        fi
        sleep 0.001
    done
done

# --- The Finale ---
printf "\e[2J\e[H\e[?25h"
echo -e "${NEON}"
cat << "EOF"
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝
EOF

echo -e "              ${GOLD}-- Powered by AlmaLinux with SEAMAIR Installer --${NC}"
echo -e "\n"

exec > >(tee -i $log_file)
exec 2>&1

#set local admin
export USERNAME="lsa001mi"

while true
    do
        read -rs -p "Please enter password for lsa00mi: " PASSWORD1
        echo -ne "\n"
        read -rs -p "Please re-enter password: " PASSWORD2
        echo -ne "\n"
        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            break
        else
            echo -ne "ERROR! Passwords do not match. \n"
        fi
    done
export uPASSWORD=$PASSWORD1



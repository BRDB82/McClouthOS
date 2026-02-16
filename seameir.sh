#!/bin/bash

#prototype installer for AlmaLinux

# "Luck is what happens when preparation meets opportunity."

select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    while true; do
        # Move cursor up to the start of the menu
        if [ $last_selected -ne -1 ]; then
            echo -ne "\033[${num_options}A"
        fi

        if [ $last_selected -eq -1 ]; then
            echo "Please select an option using the arrow keys and Enter:"
        fi
        for i in "${!options[@]}"; do
            if [ "$i" -eq $selected ]; then
                echo "> ${options[$i]}"
            else
                echo "  ${options[$i]}"
            fi
        done

        last_selected=$selected

        # Read user input
        read -rsn1 key
        case $key in
            $'\x1b') # ESC sequence
                read -rsn2 -t 0.1 key
                case $key in
                    '[A') # Up arrow
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        ;;
                    '[B') # Down arrow
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
                            selected=0
                        fi
                        ;;
                esac
                ;;
            '') # Enter key
                break
                ;;
        esac
    done

    return $selected
}

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

# --- McClouthOS Matrix: Minimalist Edition ---
NEON='\033[38;5;46m'
WHITE='\033[1;37m'
GOLD='\033[38;5;226m'
NC='\033[0m'

# Chars: Safe ASCII for minimal environments
CHARS="01#X%&@+<>ABCDEFGHIJKLMNOPQRSTUVWXYZ"
WORDS=("ALMALINUX" "MCCLOUTHOS")

# 1. Get terminal size using ANSI (Since tput/stty are missing)
# Move cursor to bottom right, then query position
echo -ne "\e[999;999H\e[6n"
read -sdR pos
pos=${pos#*[} # Strip prefix
lines=${pos%;*}
cols=${pos#*;}

# Reset cursor to top-left and hide it
echo -ne "\e[H\e[J\e[?25l"

# Initialize columns
for ((i=0; i<cols; i+=2)); do
    y[$i]=$((RANDOM % lines))
    l[$i]=$((RANDOM % 10 + 5))
done

# --- 10 Second Matrix Rain ---
start_time=$(date +%s)
while [ $(( $(date +%s) - start_time )) -lt 10 ]; do
    for ((i=0; i<cols; i+=2)); do
        # Head
        echo -ne "\e[${y[$i]};${i}H${WHITE}${CHARS:$((RANDOM%${#CHARS})):1}${NC}"
        
        # Body
        prev_y=$((y[$i] - 1))
        if [ $prev_y -gt 0 ]; then
             echo -ne "\e[${prev_y};${i}H${NEON}${CHARS:$((RANDOM%${#CHARS})):1}${NC}"
        fi

        # Tail Erase
        erase_y=$((y[$i] - l[$i]))
        if [ $erase_y -gt 0 ]; then echo -ne "\e[${erase_y};${i}H "; fi
        
        ((y[$i]++))
        if [ ${y[$i]} -ge $lines ]; then
            y[$i]=1
            l[$i]=$((RANDOM % 10 + 5))
        fi
    done
    sleep 0.05
done

# --- The Finale ---
echo -ne "\e[2J\e[H\e[?25h"
echo -e "${NEON}"

cat << 'EOF'
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

while true
	do
    	read -r -p "Please enter new hostname (e.g. 11-103-W001): " name_of_machine
		# Regex breakdown:
    	# ^[1-3][1-2]    -> Country (1-3) and City (1-2)
   		# -              -> Hyphen
   		# [0-1]{2}[0-3]  -> Env(0-1), HW(0-1), Role(0-3)
    	# -              -> Hyphen
    	# [NSW]          -> Device type (Network, Server, Workstation)
    	# [0-9]{3}$      -> Exactly 3 digits
    
    	if [[ "$name_of_machine" =~ ^[1-3][1-2]-[0-1]{2}[0-3]-[NSW][0-9]{3}$ ]]
    	then
        	break
    	fi

    	echo "Format error! Ensure it matches: [Location]-[Spec]-[DeviceID]"
    	read -r -p "Do you still want to save it? (y/n): " force
    	[[ "${force,,}" == "y" ]] && break
    done
export NAME_OF_MACHINE=$name_of_machine

echo -ne "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
    *****BACKUP YOUR DATA BEFORE CONTINUING*****
    ***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
------------------------------------------------------------------------

"

    PS3='
    Select the disk to install on: '
    options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select_option "${options[@]}"
    disk=${options[$?]%|*}

    echo -e "\n${disk%|*} selected \n"
    export DISK=${disk%|*}

    echo -ne "
Is this an SSD? yes/no:
"
    options=("Yes" "No")
    select_option "${options[@]}"

    case $? in
        0)
            export MOUNT_OPTIONS="noatime,commit=120"
            ;;
        1)
            export MOUNT_OPTIONS="noatime,commit=120"
            ;;
        *)
            echo "Wrong option. Try again"
            drivessd
            ;;
    esac

	export FS=ext4

	 time_zone="$(curl --fail -s https://ipapi.co/timezone)"
    echo -ne "
System detected your timezone to be '$time_zone' \n"
    echo -ne "Is this correct?
    "
    options=("Yes" "No")
    select_option "${options[@]}"

    case $? in
        0)
            echo "${time_zone} set as timezone"
            export TIMEZONE=$time_zone
            timedatectl set-timezone "$time_zone"
            ;;
        1)
            echo "Please enter your desired timezone e.g. Europe/Brussels :"
            read -r new_timezone
            echo "${new_timezone} set as timezone"
            export TIMEZONE=$new_timezone
            timedatectl set-timezone "$new_timezone"
            ;;
        *)
            echo "Wrong option. Try again"
            timezone
            ;;
    esac

	echo -ne "
Please select keyboard layout from this list
"
    options=(us be fr)

    select_option "${options[@]}"
    keymap=${options[$?]}

    echo -ne "Your keyboard layout: ${keymap} \n"
    export KEYMAP=$keymap

    # Apply the selected keymap using localectl
    localectl set-keymap "$keymap"

	echo -ne "
Please select which system you want to install from this list
"
    # These are default key maps commonly supported on Rocky Linux
    options=(server workstation)

    select_option "${options[@]}"
    system_choice=${options[$?]}

    echo -ne "Your system of choice: ${system_choice} \n"

    #./mcclouth-setup
    export SYSTEM_OF_CHOICE=$system_choice

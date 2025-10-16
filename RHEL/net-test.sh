#!/bin/bash

#*****************************************************************************
#* emblancher: McClouth OS Installation program                              *
#* Copyright (C) 2025 McClouth Incorporated                                  *
#* BRDB82                                                                    *
#*****************************************************************************

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#sticky
#======
pidfile="/var/run/emblancher.pid"
logfile="/root/emblancher.log"

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

#main
	
if [[ $UID -ne 0 ]]; then
  echo "emblancher must be run as root"
  exit 1
fi
	
echo "Starting installer, one moment..."

if [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/net-test.sh" -o "net-test.new" || {
		echo "update failed"
	    rm "net-test.new"
	    exit 1
	}
	chmod +x "net-test.new"
	mv -f "net-test.new" "net-test.sh"
	echo ""
	echo "Update installed. Please restart net-test.sh."
	exit 0
fi
	
sleep 0.1

exec 3> >(tee -a "$logfile")
exec 1>&3 2>&3

echo "* log file is in /root/emblancher.log"
echo ""
	
echo -ne "
===========================================================================================
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝
Powered by RHEL
===========================================================================================

"

#Create a PID file
if [ -e "$pdfile" ]; then
	echo "$pidfile already exists, exiting"
	exit 1
fi

#check memory
mem_total=$(grep MemTotal /proc/meminfo | awk '{print int($2 /1024)}')
if [[ 8192 -gt "$mem_total" ]]; then
	echo "The installation cannot continue and the system will be rebooted."
	echo "Press Enter to continue..."
	read -r
	exit 1 #for debug
	#reboot
fi

#run spokes
	
	#network settings here, for now we'll assume that the system has two NICs
	while true
	do
	    read -r -p "Please enter the IP address for the first NIC (format 0.0.0.0): " ip_address
	    # First, check if the format matches the regular expression
	    if [[ $ip_address =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	        # If the format is correct, split the IP address into octets
	        OIFS=$IFS
	        IFS='.'
	        read -ra octets <<< "$ip_address"
	        IFS=$OIFS
	
	        # Check if all four octets are numbers between 0 and 255
	        if (( octets[0] <= 255 && octets[1] <= 255 && octets[2] <= 255 && octets[3] <= 255 )); then
	            break # Exit the loop if the IP address is valid
	        else
	            echo "Error: Each number in the IP address must be between 0 and 255."
	        fi
	    else
	        echo "Error: The IP address format is invalid. Please use the format 0.0.0.0."
	    fi
	done
	export IP_ADDRESS=$ip_address

	#rhel-chroot /mnt /bin/bash -c "KEYMAP='${KEYMAP}' /bin/bash" <<EOF
	rhel-chroot /mnt /bin/bash <<EOF
	
	echo -ne "-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
	systemctl disable network.service 2>/dev/null || true
	systemctl enable NetworkManager.service
	echo "  NetworkManager enabled"

	SUBNET_MASK="24"
	DNS_SERVERS="1.1.1.1 8.8.8.8"
	GATEWAY=$(echo "$IP_ADDRESS" | sed 's/\.[0-9]\+$/.1/')
	ACTIVE_ETHERNET_LINE=$(nmcli -t -f active,name,type connection show --active | grep 'yes:.*:802-3-ethernet' | head -n 1)
	
		echo "[DEBUG-L001]::$ACTIVE_ETHERNET_LINE"

	if [ -z "$ACTIVE_ETHERNET_LINE" ]; then
		echo "!! No active ethernet connection found. Aborting network setup !!"
	else
		CONNECTION_NAME=$(echo "$ACTIVE_ETHERNET_LINE" | cut -d':' -f2)
		#gonna assume we'll have an active NIC, there is in my case, because else, how could we've gotten this far anyway, right? ;-)
  			echo "[DEBUG-L002]::$CONNECTION_NAME"
		nmcli connection modify "$CONNECTION_NAME" ipv4.method manual
		nmcli connection modify "$INTERFACE_NAME" ipv4.method manual
		nmcli connection modify "$INTERFACE_NAME" ipv4.addresses "$IP_ADDRESS/$SUBNET_MASK"
		nmcli connection modify "$INTERFACE_NAME" ipv4.gateway "$GATEWAY"
		nmcli connection modify "$INTERFACE_NAME" ipv4.dns "$DNS_SERVERS"
		nmcli connection up "$INTERFACE_NAME"
	fi

EOF

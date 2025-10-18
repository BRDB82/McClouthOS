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

INSTALL_TYPE="server"

#before we can set the software to be installed we need to make sure on what hardware we are running
if [ "$(systemd-detect-virt)" = "kvm" ]; then
        echo "We are running on virtual hardware"
elif [ "$(systemd-detect-virt)" = "none" ]; then
        echo "We are running on physical hardware" 
fi


#run spokes

  #determine if we are running on physical or virtual hardware

        #rhel-chroot /mnt /bin/bash <<EOF --- we're testing without chroot

       	echo -ne "-------------------------------------------------------------------------
                    Enabling Server Services
-------------------------------------------------------------------------
"

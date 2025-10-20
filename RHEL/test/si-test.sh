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
export WAREHOUSE_DEVICE="/dev/md0"
export WAREHOUSE_VG="vg_warehouse"
export WAREHOUSE_LV="vl_warehouse"

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
        curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/si-test.sh" -o "si-test.new" || {
                echo "update failed"
            rm "si-test.new"
            exit 1
        }
	chmod +x "si-test.new"
        mv -f "si-test.new" "si-test.sh"
        echo ""
        echo "Update installed. Please restart si-test.sh."
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
        MIN_HDDS=4
		MIN_CACHE_SSD=1

		OOT_PARTITION=$(df -P / | awk 'END{print $1}')
        ROOT_DISK_NAME=$(lsblk -no pkname "$ROOT_PARTITION" | head -n 1)

       	if [ -z "$ROOT_DISK_NAME" ]; then
                ROOT_DISK_NAME=$(basename "$ROOT_PARTITION")
        fi

		if [ -z "$ROOT_DISK_NAME" ]; then
                echo "Could not determine root disk."
                exit
        fi

		while read -r device rota; do
                #skip the root disk
                if [ "$device" == "$ROOT_DISK_NAME" ]; then
                        continue
                fi
                if [ "$rota" -eq 1 ]; then
                        HDD_DEVICES+=("/dev/$device")
                elif [ "$rota"  -eq 0 ]; then
                        CACHE_DEVICES+=("/dev/$device")
                fi
        done < <(lsblk -d -o NAME,ROTA --noheadings)

        if [ "${#HDD_DEVICES[@]}" -ge "$MIN_HDDS" ] && [ "${#CACHE_DEVICES[@]}" -ge "$MIN_CACHE_SSD" ]; then
                export HDD_DEVICES_EXPORTED="$(declare -p HDD_DEVICES)"
                export CACHE_DEVICES_EXPORTED="$(declare -p CACHE_DEVICES)"
        else
            	echo "Insufficient drives found. Require at least $MIN_HDDS HDDs and $MIN_SSDS SSDs."
                exit 1
        fi

fi


#run spokes

  #determine if we are running on physical or virtual hardware

        #rhel-chroot /mnt /bin/bash <<EOF --- we're testing without chroot

       	echo -ne "-------------------------------------------------------------------------
                    Enabling Server Services
-------------------------------------------------------------------------
"
echo "* FILE STORAGE SERVER"
if [[ -n "$HDD_DEVICES_EXPORTED" ]]; then
	eval "$HDD_DEVICES_EXPORTED"
	eval "$CACHE_DEVICES_EXPORTED"

	# 1. Install necessary packages
		echo "Installing storage management tools..."
		sudo dnf install mdadm lvm2 xfsprogs -y
	
		# 2. Prepare HDD disks for RAID
		echo "Preparing HDD disks for RAID array..."
		for device in "${HDD_DEVICES[@]}"; do
			echo "Clearing superblock on $device..."
			sudo mdadm --zero-superblock --force "$device"
		done
	
		# 3. Create mdadm RAID 5 array
		WAREHOUSE_DEVICE="/dev/md0"
		echo "Creating RAID 5 array on ${HDD_DEVICES[*]} as $WAREHOUSE_DEVICE..."
		sudo mdadm --create "$WAREHOUSE_DEVICE" --level=5 --raid-devices="${#HDD_DEVICES[@]}" "${HDD_DEVICES[@]}" --auto=yes
	
		# 4. Wait for RAID array to finish syncing (optional, but recommended)
		echo "Waiting for RAID to sync..."
		while grep -q "resync" /proc/mdstat; do
			sleep 10
		done
		echo "RAID sync complete."
	
		# 5. Create LVM logical volume on the RAID array
		echo "Setting up LVM on the RAID array..."
		sudo pvcreate "$WAREHOUSE_DEVICE"
		sudo vgcreate "$WAREHOUSE_VG" "$WAREHOUSE_DEVICE"
		sudo lvcreate -l 100%FREE -n "$WAREHOUSE_LV" "$WAREHOUSE_VG"
	
		# 6. Configure SSD caching with dm-cache (optional, assumes 1 SSD for simplicity)
	   
			# 6.1. Add the cache SSD to the volume group
			sudo pvcreate "$${CACHE_DEVICES[0]}
			sudo vgextend "$WAREHOUSE_VG" "$${CACHE_DEVICES[0]}"
	
			# Get the total size of the SSD device for sizing
			SSD_SIZE_GB=$(lsblk -b -n -o SIZE "${CACHE_DEVICES[0]}" | awk '{print $1/1024^3}')
	
			# A general guideline for metadata is 1% of the cache size, but minimum 8MB
			# To be safe for production, it's better to give it a dedicated size like 1GB or more, as recommended by some sources.
			CACHE_META_LV_SIZE="1G"
		
			# Calculate the size of the cache data volume by subtracting the metadata size
			CACHE_DATA_LV_SIZE_GB=$(echo "scale=2; $SSD_SIZE_GB - 1" | bc)
		
			# 6.2. Create the cache data and metadata logical volumes
			echo "Creating cache data logical volume (${CACHE_DATA_LV_SIZE_GB}G)..."
			sudo lvcreate -L ${CACHE_DATA_LV_SIZE_GB}G -n lv_cache_data "$WAREHOUSE_VG" "$CACHE_SSD_DEVICE"
		
			echo "Creating cache metadata logical volume (${CACHE_META_LV_SIZE})..."
			sudo lvcreate -L "$CACHE_META_LV_SIZE" -n lv_cache_meta "$WAREHOUSE_VG" "$CACHE_SSD_DEVICE"
	
			# 6.3. Create the cache pool by combining data and metadata
			echo "Creating cache pool from data and metadata volumes..."
			sudo lvconvert --type cache-pool --poolmetadata "vg_nas/lv_cache_meta" "vg_nas/lv_cache_data"
	
			# 6.4. Attach the cache pool to the main logical volume
			echo "Attaching cache pool to main volume..."
			sudo lvconvert --type cache --cachemode writeback --cachepool "vg_nas/lv_cache_data" "vg_nas/lv_nas"
	
			# 6.5. Install tools needed for a clean cache shutdown
			echo "Installing thin-provisioning tools..."
			sudo dnf install thin-provisioning-tools -y
		fi
	
		# 7. Create an XFS filesystem on the logical volume
		echo "Creating XFS filesystem..."
		sudo mkfs.xfs "/dev/$WAREHOUSE_VG/$WAREHOUSE_LV"
else
        echo "Arays were not passed or could not be recreated."
        exit 1
fi

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
logfile="/root/emblancher.log"
pidfile="/var/run/emblancher.pid"

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

if [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/emblancher.sh" -o "/usr/bin/emblancher.new" || {
		echo "update failed"
	    rm "/usr/bin/emblancer.new"
	    exit 1
	}
	chmod +x "/usr/bin/emblancher.new"
	mv -f "/usr/bin/emblancher.new" "/usr/bin/emblancher"
	exit 0
fi

#main
#----

if [[ $UID -ne 0 ]]; then
  echo "emblancher must be run as root"
  exit 1
fi

echo "emblancher for McClouth OS"
echo "=========================="
echo ""

sleep 0.1

exec 3> >(tee -a "logfile")
exec 1>&3 2>&3

echo "* log file is in /root/emblancher.log"
echo ""

if [ -e "$pdfile" ]; then
	echo "$pidfile already exists, exiting"
	exit 1
fi

if [ ! -d "/sys/firmware/efi" ]; then
	echo "Legacy boot is not supported"
fi

echo -ne "
Please select keyboard layout from this list
"
    # These are default key maps commonly supported on RHEL
    options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

    select_option "${options[@]}"
    keymap=${options[$?]}

    echo -ne "Your keyboard layout: ${keymap} \n"
    export KEYMAP=$keymap

    # Apply the selected keymap using localectl
    localectl set-keymap "$keymap"

# hopefull the network is just "up", else we've got a problem.

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
        disk_type
        ;;
esac

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

while true
do
		read -r -p "Please enter username: " username
		if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
		then
				break
		fi
		echo "Incorrect username."
done
export USERNAME=$username

while true
do
	read -rs -p "Please enter password: " PASSWORD1
	echo -ne "\n"
	read -rs -p "Please re-enter password: " PASSWORD2
	echo -ne "\n"
	if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
		break
	else
		echo -ne "ERROR! Passwords do not match. \n"
	fi
done
export PASSWORD=$PASSWORD1

while true
do
		read -r -p "Please name your machine: " name_of_machine
		# hostname regex (!!couldn't find spec for computer name!!)
		if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
		then
				break
		fi
		# if validation fails allow the user to force saving of the hostname
		read -r -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
		if [[ "${force,,}" = "y" ]]
		then
				break
		fi
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
umount -A --recursive /mnt
wipefs -a "${DISK}"
parted -s "${DISK}" mklabel gprt
parted -s "${DISK}" mkpart BOOT 1MiB 1025MiB
parted -s "${DISK}" set 1 bios_grub on
parted -s "${DISK}" mkpart EFIBOOT 1025MiB 2049MiB
parted -s "${DISK}" set 2 esp on
parted -s "${DISK}" mkpart root 2049MiB 100%
if [[ ! -d "/sys/firmware/efi" ]]; then
	parted -s "${DISK}" set 1 boot on
fi
partprobe "${DISK}"

if [[ "${DISK}" =~ "nvme" ]]; then
	partition1=${DISK}p1
	partition2=${DISK}p2
	partition3=${DISK}p3
else
	partition1=${DISK}1
	partition2=${DISK}2
	partition3=${DISK}3
fi

mkfs.ext4 -L BOOT "${partition1}"
mkfs.fat -F32 -n "EFIBOOT" "${partition2}"

if [[ "${FS}" == "xfs" ]]; then 
	mkfs.xfs -f -L ROOT "${partition3}"
	mount -t xfs "${partition3}" /mnt
elif [[ "${FS}" == "ext4" ]]; then
	mkfs.ext4 "${partition3}"
	mount -t ext4 "${partition3}" /mnt
fi

BOOT_UUID=$(blkid -s UUID -o value "${partition1}")
EFI_UUID=$(blkid -s UUID -o value "${partition2}")

sync
if ! mountpoint -q /mnt; then
	echo "ERROR! Failed to mount ${partition3} to /mnt after multiple attempts."
	exit 1
fi

mkdir -p /mnt/boot
mount -U "${BOOT_UUID}" /mnt/boot/
mkdir -p /mnt/boot/efi
mount -U "${EFI_UUID}" /mnt/boot/efi

if ! grep -qs '/mnt' /proc/mounts; then
	echo "Drive is not mounted, cannot continue"
	echo "Rebooting in 3 Seconds ..." && sleep 1
	echo "Rebooting in 2 Seconds ..." && sleep 1
	echo "Rebooting in 1 Second ..." && sleep 1
	reboot now
fi
#disk_create_filesystems
#setup_mirrors
#setup_install_environment
#setup_install_environment
#disk_installation
#disk_installbootloader

#--setopt=reposdir=/mnt/sysimage/etc/yum.repos.d \
#--setopt=sslclientcert=/mnt/sysimage/etc/pki/entitlement/entitlement.pem \
#--setopt=sslclientkey=/mnt/sysimage/etc/pki/entitlement/entitlement-key.pem
#--disablerepo='*'


#001-0002

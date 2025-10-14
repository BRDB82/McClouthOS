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
local_user="loa001mi"
logfile="/root/emblancher.log"
RHEL_VERSION="10"

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
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/emblancher.sh" -o "/usr/bin/emblancher.new" || {
		echo "update failed"
	    rm "/usr/bin/emblancer.new"
	    exit 1
	}
	chmod +x "/usr/bin/emblancher.new"
	mv -f "/usr/bin/emblancher.new" "/usr/bin/emblancher"
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
if [[ 8192 -gt "$total_ram" ]]; then
	echo "The installation cannot continue and the system will be rebooted."
	echo "Press Enter to continue..."
	read -r
	reboot
fi

#init locale
echo -ne "
Please select key board layout from this list"
# These are default key maps as presented in official arch repo archinstall
# shellcheck disable=SC1010
options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

select_option "${options[@]}"
keymap=${options[$?]}

echo -ne "Your key boards layout: ${keymap} \n"
export KEYMAP=$keymap

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone ${TIMEZONE}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# Set keymaps
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
echo "Keymap set to: ${KEYMAP}"
	
#set disk
PS3='
Select the disk to install on: '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} selected \n"
export DISK=${disk%|*}

echo -ne "
Please Select your file system for both boot and root
"
options=("xfs" "ext4" "exit")
select_option "${options[@]}"

case $? in
0) export FS=xfs;;
1) export FS=ext4;;
2) exit ;;
*) echo "Wrong option please select again"; filesystem;;
esac

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

#init system clock
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

#start subscription handling
mkdir -p /etc/yum.repos.d

#Check if we have registered system
if ! subscription-manager status 2>/dev/null | grep -q "Overall Status: Registered"; then
  read -p "CDN Username: " RHEL_USER
  read -s -p "CDN Password: " RHEL_PASS
  echo

  echo "Registring with Red Hat..."
  output=$(subscription-manager register --username="$RHEL_USER" --password="$RHEL_PASS" 2>&1) && rc=$? || rc=$?
  echo "$output"

  if [[ $rc -ne 0 ]]; then
	echo "!! Registration failed !!"
	exit $rc
  fi

fi

subscription-manager refresh

subscription-manager repos --enable="rhel-$RHEL_VERSION-for-x86_64-baseos-rpms" --enable="rhel-$RHEL_VERSION-for-x86_64-appstream-rpms"

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

dnf --releasever=10 update -y
dnf --releasever=10 clean all
dnf --releasever=10 makecache
dnf --releasever=10 -y install rpm
dnf --releasever=10 -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm --nogpgcheck
dnf --releasever=10 install -y grub2 grub2-tools grub2-efi-x64 grub2-efi-x64-modules kbd systemd-resolved
dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
setfont ter-118b

systemctl enable systemd-resolved
systemctl start systemd-resolved

if [ ! -d "/mnt" ]; then
	mkdir /mnt
fi
	
dnf --releasever=10 install -y gdisk

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

#user for install, this will be loa001mi (LOcal Admin)
export USERNAME=$local_user
while true
do
	echo -ne "\n"
	read -rs -p "Please enter password for $USERNAME: " PASSWORD1
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



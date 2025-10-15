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
	echo ""
	echo "Update installed. Please restart emblancher."
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
	#reboot
fi

#run spokes
	#local - will be set after timezone & keyboard
	#date & time
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

	#keyboard
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

	#select Software
	echo -ne "
	Please select install type
	"
	
	options=("Server" "Workstation")
	
	select_option "${options[@]}"
	
	case $? in
	0) export INSTAL_TYPE=server;;
	1) export INSTALL_TYPE=workstation;;
	*) echo "Wrong option, please select again"; machine_type_selection;;
	esac
	
	#set install target
	PS3='
	Select the disk to install on: '
	options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))
	
	select_option "${options[@]}"
	disk=${options[$?]%|*}
	
	echo -e "\n${disk%|*} selected \n"
	export DISK=${disk%|*}

	#set target filesystem
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

	#SSD?
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

	#get new hostname
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

	#password for root
	while true
	do
		echo -ne "\n"
		read -rs -p "Please enter password for root: " PASSWORD1
		echo -ne "\n"
		read -rs -p "Please re-enter password: " PASSWORD2
		echo -ne "\n"
		if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
			break
		else
			echo -ne "ERROR! Passwords do not match. \n"
		fi
	done
	export rootPASSWORD=$PASSWORD1
	
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

	#initial install inside the install environment
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

	#format target disk
	echo -ne "
------------------------------------------------------------------------
THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
Please make sure you know what you are doing because
after formatting your disk there is no way to get data back
*****BACKUP YOUR DATA BEFORE CONTINUING*****
***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
------------------------------------------------------------------------

"
	umount -A --recursive /mnt # make sure everything is unmounted before we start
	# disk prep
	sgdisk -Z "${DISK}" # zap all on disk
	sgdisk -a 2048 -o "${DISK}" # new gpt disk 2048 alignment
	
	# create partitions
	sgdisk -n 1::+1G --typecode=1:8300 --change-name=1:'BOOT' "${DISK}" # partition 1 (BIOS Boot Partition)
	sgdisk -n 2::+1G --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}" # partition 2 (UEFI Boot Partition)
	sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}" # partition 3 (Root), default start, remaining
	if [[ ! -d "/sys/firmware/efi" ]]; then # Checking for bios system
		sgdisk -A 1:set:2 "${DISK}"
	fi
	partprobe "${DISK}" # reread partition table to ensure it is correct
	
	if [[ "${DISK}" =~ "nvme" ]]; then
		partition1=${DISK}p1
		partition2=${DISK}p2
		partition3=${DISK}p3
	else
		partition1=${DISK}1
		partition2=${DISK}2
		partition3=${DISK}3
	fi
	
	for dev in "${partition1}" "${partition2}" "${partition3}"; do
	    for i in {1..10}; do
	        [[ -b "$dev" ]] && break
	        sleep 0.5
	    done
	done

	#create FS
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

	#install system on drive (dnfstrap, genfstab)
	wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/dnfstrap.sh
	  chmod +x dnfstrap.sh
	  mv dnfstrap.sh /usr/bin/dnfstrap
	wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/common
	  mv common /usr/bin/dnfcommon
	wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/rhel-chroot.sh
	  chmod +x rhel-chroot.sh
	  mv rhel-chroot.sh /usr/bin/rhel-chroot
	wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/genfstab.sh
	  chmod +x genfstab.sh
	  mv genfstab.sh /usr/bin/genfstab
	wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/fstab-helpers
	  mv fstab-helpers /usr/bin/fstab-helpers
		  
	dnfstrap /mnt @core @"Development Tools" kernel linux-firmware grub2 efibootmgr grub2-efi-x64 grub2-efi-x64-modules subscription-manager redhat-release nano dnf dnf-plugins-core --assumeyes --releasever=10

	genfstab -U /mnt >> /mnt/etc/fstab
    echo "
      Generated /etc/fstab:
    "
    cat /mnt/etc/fstab

	#install bootloader
	efibootmgr -v | grep Boot
    
	echo ""
	read -p "Give all entries to remove, or enter stop to continue: " input
	
	if [[ "$input" == "stop" ]]; then
	  echo ""
	else
	 for bootnum in $input; do
		  if [[ "$bootnum" =~ ^[0-9]+$ ]]; then
			  echo "Removing entry $bootnum..."
			  efibootmgr -B -b "$bootnum"
		  else
			  echo "Invalid entry: '$bootnum'"
		  fi
	  done
	fi
	
	grub2-install \
	  --target=x86_64-efi \
	  --efi-directory=/mnt/boot/efi \
	  --bootloader-id=McClouthOS \
	  --boot-directory=/mnt/boot \
	  --recheck \
	  --force

	#run chroot with rhel-chroot in EOF (must be adapted later for software install, currently only base system install)
	if [[ "$RHEL_USER" == "" ]]; then
		read -p "CDN Username: " RHEL_USER
		read -s -p "CDN Password: " RHEL_PASS
		echo
	fi

	rhel-chroot /mnt /bin/bash -c "RHEL_USER='${RHEL_USER}' RHEL_PASS='${RHEL_PASS}' rootPASSWORD='${rootPASSWORD}' IP_ADDRESS='${IP_ADDRESS}' KEYMAP='${KEYMAP}' /bin/bash" <<EOF
	
		echo 'nameserver 1.1.1.1' > /etc/resolv.conf
	
		mkdir -p /etc/yum.repos.d
		
		echo "Registring with Red Hat with $RHEL_USER..."
		/usr/sbin/subscription-manager register --username="$RHEL_USER" --password="$RHEL_PASS" 2>&1
		
		/usr/sbin/subscription-manager status
		
		unset RHEL_USER
		unset RHEL_PASS
		
		RHEL_VERSION="10" #Currently hardcoded, lost my initial code
		
		subscription-manager refresh
		
		subscription-manager repos --enable="rhel-$RHEL_VERSION-for-x86_64-baseos-rpms" --enable="rhel-$RHEL_VERSION-for-x86_64-appstream-rpms"
		
		rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
		
		dnf --releasever=10 update -y
		dnf --releasever=10 clean all
		dnf --releasever=10 makecache
		dnf --releasever=10 -y install rpm
	
		dnf install -y NetworkManager --nogpgcheck
		systemctl enable NetworkManager
		systemctl start NetworkManager
	
		dnf install -y curl git wget chrony
		dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
		dnf install -y rsync grub2
		wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/dnfstrap.sh
		  chmod +x dnfstrap.sh
		  mv dnfstrap.sh /usr/bin/dnfstrap
		wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/common
		  mv common /usr/bin/dnfcommon
		wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/rhel-chroot.sh
		  chmod +x rhel-chroot.sh
		  mv rhel-chroot.sh /usr/bin/rhel-chroot
		wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/genfstab.sh
		  chmod +x genfstab.sh
		  mv genfstab.sh /usr/bin/genfstab
		wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/fstab-helpers
		  mv fstab-helpers /usr/bin/fstab-helpers
		wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/Rocky/mcclouth-setup.sh
		  chmod +x mcclouth-setup.sh
		  mv mcclouth-setup.sh /usr/bin/mcclouth-setup
		dnf install -y ntp
	
		#nc=$(grep -c ^processor /proc/cpuinfo)
	
		#TOTAL_MEM=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]*')
		#if [[  $TOTAL_MEM -gt 8000000 ]]; then
		#	sed -i "s%#MAKEFLAGS=\"-j2\"%MAKEFLAGS=\"-j$nc\"%g" /etc/makepkg.conf
		#	sed -i "s%COMPRESSXZ=(xz -c -z -)%COMPRESSXZ=(xz -c -T $nc -z -)%g" /etc/makepkg.conf
		#fi
	
		locale -a | grep -q en_US.UTF-8 || localedef -i en_US -f UTF-8 en_US.UTF-8
		timedatectl --no-ask-password set-timezone "${TIMEZONE}"
		timedatectl --no-ask-password set-ntp 1
		localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
		ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
	
		localectl --no-ask-password set-keymap "${KEYMAP}"
		echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
		echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
		echo "Keymap set to: ${KEYMAP}"
	
		sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
		sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
	
		echo "max_parallel_downloads=5" >> /etc/dnf/dnf.conf
		echo "color=always" >> /etc/dnf/dnf.conf
	
		dnf makecache
	
		if grep -q "GenuineIntel" /proc/cpuinfo; then
		    echo "Installing Intel microcode"
		    dnf install -y microcode_ctl
		elif grep -q "AuthenticAMD" /proc/cpuinfo; then
		    echo "Installing AMD microcode"
		    dnf install -y linux-firmware
		else
		    echo "Unable to determine CPU vendor. Skipping microcode installation."
		fi
	
	echo -ne "
	-------------------------------------------------------------------------
	                    Installing Graphics Drivers
	-------------------------------------------------------------------------
	"
	
	# Graphics Drivers find and install
	if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
	    echo "Installing NVIDIA drivers via dnf module"
	    dnf clean all
	    dnf module install -y nvidia-driver:latest-dkms
	    dnf install -y nvidia-gds cuda
	elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
	    echo "Installing AMD drivers (bundled in linux-firmware)"
	    dnf install -y linux-firmware mesa-dri-drivers mesa-vulkan-drivers
	elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
	    echo "Installing Intel drivers"
	    dnf config-manager --add-repo https://repositories.intel.com/graphics/rhel/8.6/flex/intel-graphics.repo
	    dnf clean all
	    dnf makecache
	    dnf install -y intel-opencl intel-media intel-mediasdk libvpl2 level-zero intel-level-zero-gpu \
	                   mesa-dri-drivers mesa-vulkan-drivers mesa-vdpau-drivers libva libva-utils
	else
	    echo "Unknown GPU type. Skipping graphics driver installation."
	fi
	
	echo -ne "
	-------------------------------------------------------------------------
	                    Adding User
	-------------------------------------------------------------------------
	"
	echo "root:$rootPASSWORD"| chpasswd
	getent group libvirt >/dev/null || groupadd libvirt
	useradd -m -G wheel,libvirt -s /bin/bash "$USERNAME"
	echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"
	echo "$USERNAME:$PASSWORD" | chpasswd
	echo "$USERNAME password set"
	echo "$NAME_OF_MACHINE" > /etc/hostname
	hostnamectl set-hostname "$NAME_OF_MACHINE"

	echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
	chronyd -q
	systemctl enable chronyd.service
	echo "  Chrony (NTP) enabled"
	systemctl disable network.service 2>/dev/null || true
	systemctl enable NetworkManager.service
	echo "  NetworkManager enabled"

	SUBNET_MASK="24"
	DNS_SERVERS="1.1.1.1 8.8.8.8"
	GATEWAY=$(echo "$IP_ADDRESS" | sed 's/\.[0-9]\+$/.1/')
	CONNECTION_NAME=$(nmcli -t -f active,name,type connection show --active | grep '^yes:.*:ethernet' | head -n 1 | cut -d':' -f2)
	#gonna assume we'll have an active NIC, there is in my case, because else, how could we've gotten this far anyway, right? ;-)
	nmcli connection modify "$CONNECTION_NAME" ipv4.method manual
	nmcli connection modify "$INTERFACE_NAME" ipv4.method manual
	nmcli connection modify "$INTERFACE_NAME" ipv4.addresses "$IP_ADDRESS/$SUBNET_MASK"
	nmcli connection modify "$INTERFACE_NAME" ipv4.gateway "$GATEWAY"
	nmcli connection modify "$INTERFACE_NAME" ipv4.dns "$DNS_SERVERS"
	nmcli connection up "$INTERFACE_NAME"

	echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
	# Remove no password sudo rights
	visudo -c >/dev/null && sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# &/' /etc/sudoers
	visudo -c >/dev/null && sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# &/' /etc/sudoers
	# Add sudo rights
	visudo -c >/dev/null && sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
	visudo -c >/dev/null && sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
	EOF

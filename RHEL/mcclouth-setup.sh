#!/bin/bash

# ---------
# VARIABLES
# ---------
sms_hardware=""
sms_hdd_list=()
sms_ssd_list=()
readonly sms_version="0.01-a001"
readonly sms_warehouse="/srv/warehouse"
readonly sms_warehouse_conf="$sms_warehouse/njord.conf"
readonly CONFIG_FILE="/etc/mcclouthos/server.conf"

clear() {
  printf "\033[H\033[J" #clear
}

logo() {
  echo -ne "
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝
Powered by RHEL

"
}

usage() {
  cat <<EOF
Usage: ${0##*/} [option]

Options:
  --help        Print this help message
  --update      Update to the latest version

Description:
  This script configures McClouth OS Server.

EOF
  exit 1
}

base_setup() {
	#due to password issue due to SELinux
	if ! semodule -l | grep -q "^passwd_full_fix"; then
    dnf install -y policycoreutils-python-utils
    chmod 600 /etc/shadow
    restorecon -v /etc/shadow
		ausearch -c passwd --raw | audit2allow -M passwd_full_fix
		semodule -i passwd_full_fix.pp
	fi
}

cockpit_setup() {
	if ! rpm -q cockpit &>/dev/null; then
		dnf install cockpit cockpit-networkmanager cockpit-storaged -y
	fi
	
	if ! systemctl is-enabled cockpit.socket &>/dev/null; then
		systemctl enable --now cockpit.socket
	fi
	if ! systemctl is-active cockpit.socket &>/dev/null; then
		systemctl start cockpit.socket
	fi
	if ! firewall-cmd --list-services | grep -qw cockpit; then
		firewall-cmd --add-service=cockpit --permanent
		firewall-cmd --reload
	fi
}

display_logo() {
	clear
	logo
	
	#update will be added later
	
	echo "GNU Bash, version $BASH_VERSION"
	. /etc/os-release
	echo "$NAME $VERSION"
}

file_storage_setup() {
#Disk Information
		root_device=$(df / | tail -1 | awk '{print $1}') #get root device
		root_disk=$(lsblk -no pkname "$root_device") #identify root disk
  		hdd_count=0 #spinning drives count
		ssd_count=0 #flash drives count (non-usb)

  		for disk in /sys/block/sd*; do #loop thought all block devices and filter
			disk_name=$(basename "$disk")
		    
		    # Skip the OS disk
		    if [[ "$disk_name" == "$root_disk" ]]; then
		        continue
		    fi
	  
    		# Skip USB drives
		    if udevadm info --query=property --name="/dev/$disk_name" | grep -q '^ID_BUS=usb'; then
		        continue
		    fi
		
		    rotational=$(cat "$disk/queue/rotational")  # check if disk is rotational
		    if [[ "$rotational" == "1" ]]; then
		        hdd_list+=("/dev/$disk_name")
		    else
		        ssd_list+=("/dev/$disk_name")
		    fi
		done

  		if (( ${#hdd_list[@]} < 4 )); then #validate spinning disks
			echo "System can only be used with 4 spinning disks."
   			exit 1
		fi
  		if (( ${#ssd_list[@]} < 1 )); then
			echo "System needs a cache drive for Warehouse Services"
   			exit 1
		fi

 	# Check if WAREHOUSE is already set up
	# Start setting up
	echo "[*] Setting up Storage Services..."
 	echo "    - HDDs to be used: ${hdd_list[*]}"
  	echo "    - SSD to be used as cache: ${ssd_list[0]}"
   	# Ask for confirmation
   	read -p "    Proceed? [y/N] " confirm; [[ "$confirm" == "y" ]] || exit 1

	#wipe and partition disks
	for disk in "${hdd_list[@]}"; do
 		wipefs -a "$disk"
   		parted "$disk" --script mklabel gpt
	done

 	#create physical volumes
  	for disk in "${hdd_list[@]}"; do
   		pvcreate "$disk"
	done

 	#create volume group
 	vgcreate warehouse_vg "${hdd_list[@]}"

  	#create main WAREHOUSE logical volume
	lvcreate -l 100%FREE -n warehouse_lv warehouse_vg

 	#add SSD as cache
	pvcreate "${ssd_list[0]}"
	vgextend warehouse_vg "${ssd_list[0]}"
	lvcreate -L 100G -n cache_lv warehouse_vg "${ssd_list[0]}"
	lvconvert --type writecache --cachevol cache_lv warehouse_vg/warehouse_lv

 	#format and mount
  	mkfs.xfs /dev/warehouse_vg/warehouse_lv
	mkdir -p "$sms_warehouse"
 	mount /dev/warehouse_vg/warehouse_lv "$sms_warehouse"
	echo "/dev/warehouse_vg/warehouse_lv $sms_warehouse xfs defaults 0 0" >> /etc/fstab
}

hypervisor_install() {
	dnf install -y qemu-kvm libvirt virt-install bridge-utils cockpit-machines
	systemctl enable --now libvirtd
}

main_menu() {
	if [ $sms_hardware -eq "physcial" ]; then
		echo "STATUS :: physical hw detected"
	fi
	echo ""
	echo "================================================================================"
	echo " Server Setup - v$sms_version"
	echo "================================================================================"
	echo ""
	echo "Hostname: $HOSTNAME"
	echo ""
	echo "1. Update 'mcclouth-setup'"
	echo "2. Update system"
	echo ""
	echo "3. Storage Service"
	echo "4. Hypervisor"
	echo ""
	echo "0. Reboot"
}

hw_detect() {
if { command -v systemd-detect-virt &> /dev/null && [ "$(systemd-detect-virt)" = "none" ]; } \
   && { ! command -v dmidecode &> /dev/null || ! [[ "$(dmidecode -s system-product-name 2>/dev/null)" =~ (VMware|KVM|HVM|Bochs|QEMU) ]]; } \
   && ! grep -qi hypervisor /proc/cpuinfo; then
	sms_hardware = "physical"
else
	sms_hardware = "virtual"
fi
}

#main
if [ "$EUID" -ne 0 ]; then
	exec su -c "bash \"$0\" \"$@\"" root
	echo "Failed to run as root."
	exit 1
fi

hw_detect
sleep 5

while true; do
	display_logo
	main_menu
	read -r -p "Choose an option: " menu_option
	
	case $menu_option in
		0)
			read -r -p "Are you sure you want to reboot[y/N]? " sys_reboot
			case $sys_reboot in
				y|Y)
					reboot
					;;
			esac
			;;
		1) 
			read -r -p "Are you sure you want to update 'mcclouth-setup'[y/N]? " app_update
			update_failed=0
			case $app_update in
				y|Y)
					curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/mcclouth-setup.sh" -o "./mcclouth-setup.new" || {
						echo "update filed"
						rm "./mcclouth-setup.new"
						update_failed=1
						read -r -p "Press any key to continue..." continue
					}
					;;
			esac

			if [ "$update_failed" -eq 0 ]; then
				chmod +x "./mcclouth-setup.new"
				mv -f "./mcclouth-setup.new" "/usr/bin/mcclouth-setup"
				echo "mcclouth-setup updated..."
				read -r -p "Press any key to continue..." continue
				exec "mcclouth-setup" "$0"
			fi
			;;
		2)
			read -r -p "Are you sure you want to update this system[y/N]? " sys_update
			case $sys_update in
				y|Y)
					echo ""
					dnf update
					echo ""
					;;
			esac
			;;
		*)
			echo ""
			echo "!!INVALID INPUT!!"
			sleep 1.5
			;;
	esac
done

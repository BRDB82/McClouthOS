#!/bin/bash

# ---------
# VARIABLES
# ---------
sms_hdd_list=()
sms_ssd_list=()
readonly sms_version="0.01-a"
readonly sms_warehouse="/srv/warehouse"
readonly sms_warehouse_conf="$sms_warehouse/njord.conf"
readonly CONFIG_FILE="/etc/mcclouth/mcclouth.conf"

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
Usage: ${0##*/} [system_type]

Arguments:
  server        Install server components
  workstation   Install workstation environment

Options:
  --help        Print this help message
  --update      Update to the latest version

Description:
  This script installs McClouth OS components into the current system context.
  If no system_type is provided, the script attempts to read from the config file.

Examples:
  ${0##*/} server
  ${0##*/} workstation

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
	dnf install cockpit cockpit-networkmanager cockpit-storaged -y
	systemctl enable --now cockpit.socket
	firewall-cmd --add-service=cockpit --permanent
	firewall-cmd --reload
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

server_install() {
if { command -v systemd-detect-virt &> /dev/null && [ "$(systemd-detect-virt)" = "none" ]; } \
   && { ! command -v dmidecode &> /dev/null || ! [[ "$(dmidecode -s system-product-name 2>/dev/null)" =~ (VMware|KVM|HVM|Bochs|QEMU) ]]; } \
   && ! grep -qi hypervisor /proc/cpuinfo; then
	echo "Real hardware"

	#CPU information
	if [ "$(nproc)" -lt 4 ]; then #should be at least 12 but for testiing only 4
		echo "System doesn't have enough cores."
		exit 1
	fi

	#Memory Information
	total_mem=$(free -m | awk '/^Mem:/ { print $2 }')
	total_mem=$((total_mem / 1024 / 1024))
	
	if [ "$total_mem" -lt 16 ]; then #should be at least 16 for testing only 8
		echo "System needs at least 32 GB of RAM."
		exit 1
	fi
	
	cockpit_setup

	file_storage_setup
else
  echo "Virtual hardware"
fi
}

#main
clear
logo
echo -ne "
--------------------------------------------------------------------------------------------
             Automated McClouth OS Extended Installer
--------------------------------------------------------------------------------------------
"

if [ -z "$1" ]; then
  if [ -f "$CONFIG_FILE" ]; then
        system_type=$(grep '^system_type=' "$CONFIG_FILE" | cut -d'=' -f2)
    else
  		mih=$(hostname)
  		if [ "${mih:4:1}" == "S" ]; then
  			system_type="server"
  		else
        echo "Error: No system type provided and config file not found."
        usage
        exit 1
  		fi
    fi
else
  case "$1" in
    server|workstation)
      system_type="$1"
      ;;
    --update)
		echo -ne "
--------------------------------------------------------------------------------------------
             Updating mcclouth-setup
--------------------------------------------------------------------------------------------
"
      curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/mcclouth-setup.sh" -o "/usr/bin/mcclouth-setup.new" || {
	      echo "update failed"
	      rm "/usr/bin/mcclouth-setup.new"
	      exit 1
	    }
	    chmod +x "/usr/bin/mcclouth-setup.new"
	    mv -f "/usr/bin/mcclouth-setup.new" "/usr/bin/mcclouth-setup"
	    exit 0
      ;;
    *)
      echo "Unknown system type: '$1'"
      usage
      exit 1
      ;;
  esac
fi

case "$system_type" in
  server)
    echo "Installing server components..."
	base_install
    server_install
    ;;
  workstation)
    echo "Installing workstation environment..."
    #workstation install logic here
    ;;
  *)
    echo "Unknown system type: '$system_type'"
    exit 1
    ;;
esac

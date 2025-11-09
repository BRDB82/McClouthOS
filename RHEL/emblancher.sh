#!/bin/bash

set_fixed_ip="N"
local_user="loa001mi"

get_repo_id() {
    local keyword="$1"
    local repo_id=""
    
    # Use a refined grep command to exclude source, debug, and eus repos
    repo_id=$(subscription-manager repos --list | grep -B1 "Repo Name:.*$keyword" | grep "Repo ID:" | grep -v "source" | grep -v "debug" | grep -v "eus" | head -n1 | cut -d':' -f2 | tr -d '[:space:]')
    
    echo "$repo_id"
}

install_apps() {
    local options=()
    local packages_to_install=()
    local urls_to_install=()
    local all_args=("$@")
    
    # Separate options, packages, and URLs
    for arg in "${all_args[@]}"; do
        if [[ "$arg" =~ ^- ]]; then
            # Options like --nogpgcheck
            options+=("$arg")
        elif [[ "$arg" =~ ^https?:// ]]; then
            # URLs
            urls_to_install+=("$arg")
        else
            # Standard package names
            packages_to_install+=("$arg")
        fi
    done

    # --- Handle standard packages (grub2, kbd, etc.) ---
    local missing_packages=()
    for package in "${packages_to_install[@]}"; do
        # We can only check installation status for normal package names via rpm -q
        #if ! rpm -q "$package" &>/dev/null; then
		if ! dnf list installed "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        #echo "Installing missing packages: ${missing_packages[*]}"
        # Note: dnf install accepts URLs alongside package names if they are RPM files/repo files
		if [ ${#options[@]} -eq 0 ]; then
        	dnf -y install "${missing_packages[@]}" &>/dev/null 2>&1
		else
			dnf -y install "${options[@]}" "${missing_packages[@]}" &>/dev/null 2>&1
		fi
        if [ $? -ne 0 ]; then
            echo "Failed to install standard packages: ${missing_packages[@]}, options: ${options[@]}" >&2
        fi
    fi

    # --- Handle URLs (EPEL repo files, specific RPM files) ---
    # URLs must be passed to dnf install directly. 
    # DNF will download and install them immediately, usually requiring no pre-check via rpm -q
    if [ ${#urls_to_install[@]} -gt 0 ]; then
        #echo "Installing URLs/Remote RPMs: ${urls_to_install[*]}"
        # DNF can handle a list of URLs directly as inputs
        dnf -y install "${options[@]}" "${urls_to_install[@]}" &>/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to install one or more remote files/URLs." >&2
        fi
    fi
}

is_registered() {
    subscription-manager status | grep -q 'Overall Status: Registered'
}

is_repo_enabled() {
	subscription-manager repos --list-enabled | grep -q "$1"
}

rhel_version() {
	echo $(grep -oE '[0-9]+' /etc/redhat-release | head -n1)
}

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

# Check if the user is root
if [ $(id -u) -ne 0 ]; then
    echo "emblancher must be run as root."
    exit 1
fi

#check for parameters (--help or --version)
if [ "$1" == "--help" ]; then
    echo "Usage: emblancher [options]"
    echo "Options:"
    echo "  --help     Show this help message and exit"
    echo "  --version  Show the version and exit"
    exit 0
fi

if [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/emblancher.sh" -o "./emblancher.new" || {
		echo "update failed"
	    rm "./emblancher.new"
	    exit 1
	}
	chmod +x "./emblancher.new"
	mv -f "./emblancher.new" "./emblancher.sh"
	echo "emblancher updated, please restart..."
	exit 0
fi

if [ "$1" == "--version" ]; then
    echo "emblancher 1.0.0"
    exit 0
fi

#MAIN
printf '\033%G'
logo_string='
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝

--------------------------------------------------------------------------------------------
                Automated McClouth OS Base Installer (powered by RHEL)
--------------------------------------------------------------------------------------------

'
printf "%s\n" "$logo_string"

echo "Starting installer, one moment..."
echo ""

#LOCALIZATION
	#Keyboard
		echo -ne "* Please select a keyboard layout from this list [us,ca,de,fr,nl,uk]: "
		read -r keymap
		export KEYMAP=$keymap
	#Language Support
		#For the time being we only support English
	#Time & Data
		time_zone="$(curl --fail -s https://ipapi.co/timezone)"
		echo -ne "* System detected your timezone to be '$time_zone' \n"
		echo -ne "  Is this correct (y/n)? "
		read -r options
		
		case "$options" in
			y|Y)
				export TIMEZONE=$time_zone
				timedatectl set-timezone "$time_zone"
				;;
			n|N)
				echo "- Please enter your desired timezone e.g. Europe/Brussels :"
				read -r new_timezone
				export TIMEZONE=$new_timezone
				timedatectl set-timezone "$new_timezone"
				;;
			*)
				echo "!! Wrong option. Try again"
				timezone
				;;
		esac

		echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
		timedatectl --no-ask-password set-timezone ${TIMEZONE}
		timedatectl --no-ask-password set-ntp 1
		localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
		ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
		
		# Set keymaps
		echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
		echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf

#SOFTWARE
	# Connect to Red Hat
		read -p "* Enter your Red Hat Subscription username: " RH_USER
		read -sp "  Enter your Red Hat Subscription password: " RH_PASS
		echo ""
		
		if is_registered; then
		    echo "[STATUS] :: System already registered"
		else
		    echo "[STATUS] :: System unregistered"
		    subscription-manager register --username="$RH_USER" --password="$RH_PASS"
			if is_registered; then
				echo "[STATUS] :: System registered"
			else
			    echo "[STATUS] :: System can't be registered"
			    exit 1
			fi
		fi
		export REP_USER=$RH_USER
		export REP_PASS=$RH_PASS
	#Installation Source
		BASEOS_REPO_ID=$(get_repo_id "BaseOS")
		APPSTREAM_REPO_ID=$(get_repo_id "AppStream")
		CRB_REPO_ID=$(get_repo_id "CodeReady Linux Builder")
		REPO_VERSION=$(rhel_version)
		
		if [[ -z "$BASEOS_REPO_ID" || -z "$APPSTREAM_REPO_ID" ]]; then
		    echo "Error: Could not find BaseOS or AppStream repository IDs."
		    exit 1
		elif [[ -z "$CRB_REPO_ID" ]]; then
			echo "Error: Could not find CRB repository ID."
			exit 1
		elif [[ -z "$REPO_VERSION" ]]; then
		    echo "Error: Could not determine RHEL release version."
		    exit 1
		fi
		
		if is_repo_enabled "$BASEOS_REPO_ID"; then
		    echo "[STATUS] :: BaseOS already enabled"
		else
		    subscription-manager repos --enable="$BASEOS_REPO_ID"
		fi
		
		if is_repo_enabled "$APPSTREAM_REPO_ID"; then
		    echo "[STATUS] :: AppStream already enabled"
		else
		   subscription-manager repos --enable="$APPSTREAM_REPO_ID"
		fi
		
		if is_repo_enabled "$CRB_REPO_ID"; then
		    echo "[STATUS] :: CRB already enabled"
		else
		   subscription-manager repos --enable="$CRB_REPO_ID"
		fi
		
		if [[ ! -f /etc/dnf/vars/releasever ]]; then
		    echo "$REPO_VERSION" > /etc/dnf/vars/releasever
		fi

		export REP_REP1=$BASEOS_REPO_ID
		export REP_REP2=$APPSTREAM_REPO_ID
		export REP_REP3=$CRB_REPO_ID
		export REP_REPO_VERSION=$REPO_VERSION
	#Software Selection
		echo -ne "* Please select install type [Server,Workstation]: "
		read -r install_type
		export INSTALL_TYPE=$install_type

#SYSTEM
	#Installation Destination
		#Destination
		PS3='* Select the disk to install on: '
		options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))
		
		select_option "${options[@]}"
		disk=${options[$?]%|*}
		
		export DISK=${disk%|*}
		#FileSystem
		echo -ne "* Please Select your file system for both boot and root [ext4,xfs]: "
		read -r fs
		export FS=$fs
		#SSD
		echo -ne "* Is this an SSD (y/n): "
		read -r options
	
		case "$options" in
			y|Y)
		    	export MOUNT_OPTIONS="noatime,commit=120"
		    	;;
		    n|N)
		        export MOUNT_OPTIONS="noatime,commit=120"
		        ;;
		    *)
		        echo "!! Wrong option. Try again"
		        disk_type
		        ;;
		esac
	#Network & Hostname
		PS3='* Select the network device to configure: '
		options=($(nmcli -t -f DEVICE,TYPE dev status | awk -F':' '$2=="ethernet" && $1!="lo" {print $1}'))
		
		# Check if any ethernet devices were found
		if [ ${#options[@]} -eq 0 ]; then
		    echo "!! No Ethernet devices were found. Aborting network configuration. !!"
		    exit 1
		fi
		
		select_option "${options[@]}"
		interface=${options[$?]}
		
		export INTERFACE_NAME=${interface}
	
		# Check INSTAL_TYPE
		INSTALL_TYPE_LOWER=$(echo "$INSTALL_TYPE" | tr '[:upper:]' '[:lower:]')

		if [ "$INSTALL_TYPE_LOWER" = "server" ]; then
		    set_fixed_ip="yes"
		else
		    # Ask user for input and store it in a variable named `user_choice`
		    read -p "- Do you want a fixed IP for your system? (y/n): " user_choice
		
		    # Convert the user's choice to lowercase for easier comparison
		    user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')
		
		    # Check the user's input and set the `set_fixed_ip` variable
		    if [ "$user_choice" = "yes" ] || [ "$user_choice" = "y" ]; then
		        set_fixed_ip="yes"
		    fi
		fi
		export SET_FIXED_IP=$set_fixed_ip
	
		if [[ "$SET_FIXED_IP" == "yes" ]]; then
			while true
			do
			    read -r -p "- Please enter the IP address for the first NIC (format 0.0.0.0): " ip_address
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
			            echo "!! Error: Each number in the IP address must be between 0 and 255."
			        fi
			    else
			        echo "!! Error: The IP address format is invalid. Please use the format 0.0.0.0."
			    fi
			done
			export IP_ADDRESS=$ip_address
			export SUBNET_MASK="24"
			export DNS_SERVERS="1.1.1.1 8.8.8.8"
			export GATEWAY=$(echo "$IP_ADDRESS" | sed 's/\.[0-9]\+$/.1/')
		fi

		while true
		do
				read -r -p "* Please name your machine: " name_of_machine
				# hostname regex (!!couldn't find spec for computer name!!)
				if [[ "${name_of_machine,,}" =~ ^[a-z0-9][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
				then
						break
				fi
				# if validation fails allow the user to force saving of the hostname
				read -r -p "!! Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
				if [[ "${force,,}" = "y" ]]
				then
						break
				fi
		done
		export NAME_OF_MACHINE=$name_of_machine	

#USER SETTINGS
	#Root Password
	while true
	do
		#echo ""
		read -rs -p "* Please enter password for root: " PASSWORD1
		echo ""
		read -rs -p "  Please re-enter password: " PASSWORD2
		if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
			break
		else
			echo -ne "!! ERROR! Passwords do not match. \n"
		fi
	done
	export rPASSWORD=$PASSWORD1
	#User Creation (loa001mi
	export USERNAME=$local_user
	while true
	do
		echo ""
		read -rs -p "* Please enter password for $USERNAME: " PASSWORD1
		echo ""
		read -rs -p "  Please re-enter password: " PASSWORD2
		if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
			break
		else
			echo -ne "ERROR! Passwords do not match. \n"
		fi
	done
	export PASSWORD=$PASSWORD1

	echo ""
	echo "SUMMARY"
	echo "-------"
	echo "* LOCALIZATION:"
	echo "	- keyboard layout: $KEYMAP"
	echo "	- language: English"
	echo "	- timezone: $TIMEZONE"
	echo "* SOFTWARE:"
	echo "	- Installation Source: RHEL Repositories"
	echo "	- Software Selection: $INSTALL_TYPE"
	echo "* SYSTEM:"
	echo "	- Installation Destination: $DISK"
	echo "	- Destination FilesSystem: $FS"
	echo "	- Network: $INTERFACE_NAME; $IP_ADDRESS/$SUBNET_MASK"
	echo "	- Hostname: $NAME_OF_MACHINE"
	echo ""
	while true; do
		read -r -p "Is this correct(y/n)?" options
	
		case "$options" in
			y|Y)
				break
				;;
			n|N)
				echo "Please restart installation."
				exit 0
				;;
		esac
	done
	
	#setup installation environment
	dnf -y upgrade --refresh  &>/dev/null
	dnf clean all  &>/dev/null
	dnf makecache  &>/dev/null
	sleep 3
	install_apps rpm
	install_apps https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm --nogpgcheck
	install_apps grub2 grub2-tools grub2-efi-x64 grub2-efi-x64-modules kbd systemd-resolved
	install_apps https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
	setfont ter-118b &>/dev/null
	
	systemctl enable systemd-resolved
	systemctl start systemd-resolved
	
	if ! rpm -q gdisk &>/dev/null; then
	    dnf list gdisk &>/dev/null
	
	    if [ $? -eq 0 ]; then
	        install_apps gdisk
		else
			echo "[STATUS] :: Can't install gdisk"
			exit 1
		fi
	fi

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
	
	echo "[STATUS] :: Install Environment [OK]"
	echo "...................................."

	#format disk
	echo -ne "------------------------------------------------------------------------
THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
Please make sure you know what you are doing because
after formatting your disk there is no way to get data back
*****BACKUP YOUR DATA BEFORE CONTINUING*****
***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
------------------------------------------------------------------------"
	while true; do
		echo ""
		read -r -p "Do you want to continue(y/n)?" options
	
		case "$options" in
			y|Y)
				break
				;;
			n|N)
				echo "Installation stopped by user."
				exit 0
				;;
		esac
	done
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
	
	#create filesystem
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

	#install on drive - this seems to need a registration? But it seems we can install
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

	#install grub
	grub2-install \
  --target=x86_64-efi \
  --efi-directory=/mnt/boot/efi \
  --bootloader-id=McClouthOS \
  --boot-directory=/mnt/boot \
  --recheck \
  --force

	#enter chroot
	rhel-chroot /mnt /bin/bash <<EOF

	#initial check to see if all variables are parsed to the chroot
	echo ""
	echo "SUMMARY"
	echo "-------"
	echo "* LOCALIZATION:"
	echo "	- keyboard layout: $KEYMAP"
	echo "	- language: English"
	echo "	- timezone: $TIMEZONE"
	echo "* SOFTWARE:"
	echo "	- Installation Source: RHEL Repositories"
	if [ ! -z "$REP_USER" ] && [ ! -z "$REP_PASS" ]; then
		echo "	  REP_INFO known"
	else
		echo "!! Error: REP_INFO is missing inside the script." >&2
    	exit 1
	fi
	echo "	- Software Selection: $INSTALL_TYPE"
	echo "* SYSTEM:"
	echo "	- Installation Destination: $DISK"
	echo "	- Destination FilesSystem: $FS"
	echo "	- Network: $INTERFACE_NAME; $IP_ADDRESS/$SUBNET_MASK"
	echo "	- Hostname: $NAME_OF_MACHINE"
	echo "	- Users:"
		if [ ! -z "$rPASSWORD" ] && [ ! -z "$PASSWORD" ]; then
		echo "	  INFO known"
	else
		echo "Error: INFO is missing inside the script." >&2
    	exit 1
	fi
	echo ""
	while true; do
		read -r -p "Is this correct(y/n)?" options
	
		case "$options" in
			y|Y)
				break
				;;
			n|N)
				echo "Please restart installation."
				exit 0
				;;
		esac
	done
	
		#network setup
		echo 'nameserver 1.1.1.1' > /etc/resolv.conf
	
		mkdir -p /etc/yum.repos.d
		
		echo "Registring with Red Hat with $REP_USER..."
		/usr/sbin/subscription-manager register --username="$REP_USER" --password="$REP_PASS" 2>&1

		if [[ -z "$REP_REPO1" || -z "$REP_REPO2" ]]; then
		    echo "Error: Could not find BaseOS or AppStream repository IDs."
		    exit 1
		elif [[ -z "$REP_REPO3" ]]; then
			echo "Error: Could not find CRB repository ID."
			exit 1
		elif [[ -z "$REP_REPO_VERSION" ]]; then
		    echo "Error: Could not determine RHEL release version."
		    exit 1
		fi
		
		subscription-manager repos --enable="$REP_REPO1"
		subscription-manager repos --enable="$REP_REPO2"
		subscription-manager repos --enable="$REP_REPO3"
		fi
		
		if [[ ! -f /etc/dnf/vars/releasever ]]; then
		    echo "$REP_REPO_VERSION" > /etc/dnf/vars/releasever
		fi

		subscription-manager refresh
		dnf update -y
		dnf clean all
		dnf makecache
		dnf install rpm -y
	
		dnf install -y NetworkManager --nogpgcheck
		systemctl enable NetworkManager
		systemctl start NetworkManager
	
		dnf install -y curl git wget chrony
		dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
		dnf install -y rsync grub2
		dnf install -y ntp

		chronyd -q
		systemctl enable chronyd.service
		echo "  Chrony (NTP) enabled"
		systemctl disable network.service 2>/dev/null || true
		systemctl enable NetworkManager.service
		echo "  NetworkManager enabled"
	
		# Check if a interface was found
		if [ -z "$INTERFACE_NAME" ]; then
		    echo "!! Failed to find an active ethernet connection after multiple attempts. Aborting network setup. !!"
		    exit 1
		else
			#gonna assume we'll have an active NIC, there is in my case, because else, how could we've gotten this far anyway, right? ;-)
			nmcli connection modify "$INTERFACE_NAME" ipv4.method manual ipv4.addresses "$IP_ADDRESS/$SUBNET_MASK" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS_SERVERS"
			nmcli connection up "$INTERFACE_NAME"
		fi

		
		#set language and local
		locale -a | grep -q en_US.UTF-8 || localedef -i en_US -f UTF-8 en_US.UTF-8
		timedatectl --no-ask-password set-timezone "${TIMEZONE}"
		timedatectl --no-ask-password set-ntp 1
		localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
		ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
	
		localectl --no-ask-password set-keymap "${KEYMAP}"
		echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
		echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
		#adding user
		sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
		sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
		echo "root:$rPASSWORD"| chpasswd
		getent group libvirt >/dev/null || groupadd libvirt
		useradd -m -G wheel,libvirt -s /bin/bash "$USERNAME"
		echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"
		echo "$USERNAME:$PASSWORD" | chpasswd
		echo "$USERNAME password set"

		# Remove no password sudo rights
		visudo -c >/dev/null && sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# &/' /etc/sudoers
		visudo -c >/dev/null && sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# &/' /etc/sudoers
		# Add sudo rights
		visudo -c >/dev/null && sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
		visudo -c >/dev/null && sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

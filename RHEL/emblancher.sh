#!/bin/bash

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
        if ! rpm -q "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        #echo "Installing missing packages: ${missing_packages[*]}"
        # Note: dnf install accepts URLs alongside package names if they are RPM files/repo files
        dnf -y install "${options[@]}" "${missing_packages[@]}" &>/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to install standard packages." >&2
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

read -p "Enter your Red Hat Subscription username: " RH_USER
read -sp "Enter your Red Hat Subscription password: " RH_PASS
echo ""

if is_registered; then
    echo "[STATUS] :: System already registered"
else
    echo "[STATUS]:: System unregistered"
    subscription-manager register --username="$RH_USER" --password="$RH_PASS"
	if is_registered; then
		echo "[STATUS]:: System registered"
	else
	    echo "[STATUS]:: System can't be registered"
	    exit 1
	fi
fi

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

dnf -y upgrade --refresh  &>/dev/null
dnf clean all  &>/dev/null
dnf makecache  &>/dev/null
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

echo "[STATUS] :: Install Environment [OK]

#LOCALIZATION
	#Keyboard
		echo -ne "Please select key board layout from this list"
		options=(us ca de fr nl uk)
		
		select_option "${options[@]}"
		keymap=${options[$?]}
		export KEYMAP=$keymap
	#Language Support
		#For the time being we only support English
	#Time & Data
		time_zone="$(curl --fail -s https://ipapi.co/timezone)"
		echo -ne "System detected your timezone to be '$time_zone' \n"
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

		sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
		timedatectl --no-ask-password set-timezone ${TIMEZONE}
		timedatectl --no-ask-password set-ntp 1
		localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
		ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
		
		# Set keymaps
		echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
		echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf

#SOFTWARE
	#Installation Source
		#already ok
	#Software Selection
		echo -ne "
		Please select install type
		"
		
		options=("Server" "Workstation")
		
		select_option "${options[@]}"
		
		case $? in
		0) export INSTALL_TYPE="server";;
		1) export INSTALL_TYPE="workstation";;
		*) echo "Wrong option, please select again"; machine_type_selection;;
		esac

#SYSTEM
	#Installation Destination
	#Network & Hostname

#USER SETTINGS
	#Root Password
	#User Creation

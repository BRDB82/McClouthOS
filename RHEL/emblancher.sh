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
    local all_args=("$@")
    
    # Separate options from packages
    for arg in "${all_args[@]}"; do
        if [[ "$arg" =~ ^- ]]; then
            options+=("$arg")
        else
            packages_to_install+=("$arg")
        fi
    done

	local missing_packages=()
    for package in "${packages_to_install[@]}"; do
        if ! rpm -q "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        dnf -y install "${options[@]}" "${missing_packages[@]}"
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
echo -ne "
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝

--------------------------------------------------------------------------------------------
                Automated McClouth OS Base Installer (powered by RHEL)
--------------------------------------------------------------------------------------------

"

echo "Starting installer, one moment..."
echo ""

read -p "Enter your Red Hat username: " RH_USER
read -sp "Enter your Red Hat password: " RH_PASS
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

dnf -y upgrade --refresh
dnf clean all
dnf makecache
install_apps rpm
install_apps https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm --nogpgcheck
install_apps grub2 grub2-tools grub2-efi-x64 grub2-efi-x64-modules kbd systemd-resolved
install_apps https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
setfont ter-118b

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

#!/bin/bash

get_repo_id() {
    local keyword="$1"
    local repo_id=""
    
    # Use a refined grep command to exclude source, debug, and eus repos
    repo_id=$(subscription-manager repos --list | grep -B1 "Repo Name:.*$keyword" | grep "Repo ID:" | grep -v "source" | grep -v "debug" | grep -v "eus" | head -n1 | cut -d':' -f2 | tr -d '[:space:]')
    
    echo "$repo_id"
}

is_registered() {
    subscription-manager status | grep -q 'Overall Status: Registered'
}

is_repo_enabled() {
	subscription-manager repos --list-enabled | grep -q "$1"
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
	    rm "./emblancer.new"
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
    #subscription-manager register --username="$RH_USER" --password="$RH_PASS"
	if is_registered; then
		echo "[STATUS]:: System registered"
	else
	    echo "[STATUS]:: System can't be registered"
	    exit 1
	fi
fi

BASEOS_REPO_ID=$(get_repo_id "BaseOS")
APPSTREAM_REPO_ID=$(get_repo_id "AppStream")
if [[ -z "$BASEOS_REPO_ID" || -z "$APPSTREAM_REPO_ID" ]]; then
    echo "Error: Could not find BaseOS or AppStream repository IDs."
    echo "Please check your subscription and network connection."
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

dnf -y upgrade

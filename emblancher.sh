#!/bin/bash

#set common's
local_user="stl001mi"
log_file="/root/emblancher.log"
set_fixed_ip="N"

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
    echo "emblancher 0.0.1-a"
    exit 0
fi

exec 3> >(tee -a "$logfile")
exec 1>&3 2>&3

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
                Automated McClouth OS Base Installer (powered by AlmaLinux)
--------------------------------------------------------------------------------------------

'
printf "%s\n" "$logo_string"

echo "Starting installer, one moment..."
echo ""

# LOCALIZATION
  # get keyboard
  # get language
  # set time & date

# SOFTWARE
  # installation source
  # Software Selection

# SYSTEM
  # installation destination
  # network & hostname

# USER SETTINGS
  # Root Password
  # User Creation


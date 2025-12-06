njord_choice=""
njord_exit=0
njord_hand="NJORD:0000_0000x0"
njord_hardware=""
readonly njord_version="0.01a"

app_update() {
	read -r -p "Are you sure you want to update 'mcclouth-setup' [y/N]? " njord_update
	update_failed=0
	case $njord_update in
		y|Y)
			curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/handler.sh" -o "./mcclouth-setup.new" || {
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

}

euid_check() {
	if [ "$EUID" -ne 0 ]; then
		exec su -c "bash \"$0\" \"$@\"" root
		echo "Failed to run as root."
		exit 1
	fi
}

detect_hardware() {
	if { command -v systemd-detect-virt &> /dev/null && [ "$(systemd-detect-virt)" = "none" ]; } \
   && { ! command -v dmidecode &> /dev/null || ! [[ "$(dmidecode -s system-product-name 2>/dev/null)" =~ (VMware|KVM|HVM|Bochs|QEMU) ]]; } \
   && ! grep -qi hypervisor /proc/cpuinfo; then
	njord_hardware="physical"
else
	njord_hardware="virtual"
fi
}

display_box() {
	if [[ $njord_hand == "NJORD:0000_0000x0" ]]; then
		echo ""
		echo "1. Hostname: 						$HOSTNAME"
		echo "2. Date & Time:					$(date %d-%m-%Y %H:%M)"
		echo "3. Network:						0.0.0.0/0"
		echo "									0.0.0.0"
		echo "									0.0.0.0, 0.0.0.0, 0.0.0.0"
		echo "4. Secure Shell:					disabled"
		echo "5. Update 'mcclouth-setup"
		echo "6. Update system"
		if [[ $njord_hardware == "physical" ]]; then
			echo ""
			echo "7. Storage Service"
			echo "8. Hypervisor"
			echo ""
			echo "D. Reboot"
			echo "E. Shutdown"
			echo "F. Exit"
			read -p "Make your choice: " njord_choice
		fi
	fi
}

display_logo() {
echo -ne "
                                                                            Powered by RHEL
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝
SERVER SETUP - v$njord_version

"
}

handler() {
	#phase_1
		if [[ $njord__hand == "NJORD:0000_0000xF" ]]; then
			njord_exit=1
		fi
	#phase_2
		#wait?
	#phase_3
		display_box
	#phase_4
		#menu_handler
		if [[ $njord_hand == "NJORD:0000_0000x0" ]]; then
			if [[ $njord_choice == "5" ]]; then
				app_update
			elseif [[ $njord_choice == "F" ]]; then
				$njord_hand="NJORD:0000_0000xF"
			fi
		fi
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
  exit 0
}

display_logo
euid_check

# Loop through all provided arguments (parameters)
for i in "$@"; do
    case $i in
        --help)
        usage
        shift # Shift past the argument
        ;;

        --update)
       	app_update
       	exit 0
        ;;
    esac
done

#detect_hardware
njord_hardware="physical"
#check config
while (( njord_exit != 1 )); do
    handler
done

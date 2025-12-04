sms_exit=0
sms_hand="MIO:0000_0000x0"
sms_hardware=""
sms_root=0
readyonly sms_version="0.01a"

app_update() {
	read -r -p "Are you sure you want to update 'mcclouth-setup' [y/N]? " app_update
	update_failed=0
	case $app_update in
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
	sms_hardware="physical"
else
	sms_hardware="virtual"
fi
}

display_box() {
	#nothing here yet
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
SERVER SETUP

"
}

handler() {
	#phase_1
		#initiate cmd's
	#phase_2
		#wait?
	#phase_3
		#display
	#phase_4
		#menu_handler
	sms_exit=1
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

detect_hardware
write-host $sms_hardware
#check config
while : ; do
	while (( $sms_exit != 1 )); do
		handler
	done
	break
loop

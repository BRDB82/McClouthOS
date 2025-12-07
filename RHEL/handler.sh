njord_choice=""
njord_exit=0
njord_hand="NJORD:0000_0000x0"

njord_dns=""
njord_gateway=""
njord_hardware=""
njord_ip=""
njord_ipcomment=""
njord_ssh=""

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

	local interface=""
    local ip_cidr=""
    local found_match=0
	#njord_dns=""
	#njord_gateway=""
	#njord_hardware=""
	#njord_ip=""
	#njord_ipcomment=""
	local all_ips=$(ip -o -f inet addr show | awk '/scope global/ {print $2, $4}')
	while read -r current_iface current_ip_cidr; do
        current_ip=$(echo "$current_ip_cidr" | cut -d'/' -f1)

        # Extract the last octet and perform an arithmetic check (integer comparison)
        IFS=. read -r oct1 oct2 oct3 last_octet <<< "$current_ip"

        if (( last_octet >= 200 && last_octet <= 254 )); then
            # Found a match! Use this interface's details.
            interface=$current_iface
            ip_cidr=$current_ip_cidr
            found_match=1
            njord_ipcomment="" # IP is within the desired range
            break # Exit the loop
        fi
    done <<< "$all_ips"
	if [ "$found_match" -eq 0 ]; then
        echo "Warning: No IP found in the 200-254 range. Falling back to the first available interface." >&2
        # Re-run the command but just grab the first line of output
        local first_nic_info=$(ip -o -f inet addr show | awk '/scope global/ {print $2, $4; exit}')

        if [[ -n "$first_nic_info" ]]; then
            interface=$(echo "$first_nic_info" | awk '{print $1}')
            ip_cidr=$(echo "$first_nic_info" | awk '{print $2}')
            njord_ipcomment="!!not fixed!!" # Mark this IP as non-standard/fallback
        else
            # Nothing worked
            echo "Error: Could not detect any active network interface." >&2
            return 1
        fi
    fi
	njord_ip=$(echo "$ip_cidr" | cut -d'/' -f1)
    njord_netmask=$(echo "$ip_cidr" | cut -d'/' -f2)

    # Get Gateway (This is usually system-wide via the default route)
    # This might fail if the fallback NIC isn't on the default route, but it's the standard way.
    njord_gateway=$(ip route show default | awk '{print $3; exit}')
    
    # Get DNS Servers (system-wide from /etc/resolv.conf)
    local dns_servers
    dns_servers=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/,$//')
    njord_dns=$dns_servers

	if systemctl is-enabled --quiet sshd; then
		njord_ssh="enabled"
	else
		njord_ssh="disabled"
	fi
}

display_box() {
	case "$njord_hand" in 
		"NJORD:0000_0000x0")
			echo ""
			echo "1. Hostname: 						$HOSTNAME"
			echo "2. Date & Time:						$(date +"%d-%m-%Y %H:%M")"
			echo "3. Network:						$njord_ip/$njord_netmask $njord_ipcomment"
			echo "							$njord_gateway"
			echo "							$njord_dns"
			echo "4. Secure Shell:					$njord_ssh"
			echo "5. Update 'mcclouth-setup"
			echo "6. Update system"
			echo "7. Terminal"
			if [[ $njord_hardware == "physical" ]]; then
				echo ""
				echo "8. Storage Service"
				echo "9. Hypervisor"
				echo ""
				echo "E. Reboot"
				echo "F. Shutdown"
				read -p "Make your choice: " njord_choice
			fi
			;;
	esac
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
		case "$njord_hand" in
			"NJORD:0000_0000x5")
					app_update
				;;
		esac
	#phase_2
		#wait?
	#phase_3
		display_box
	#phase_4
		#menu_handler
		case "$njord_hand" in
			"NJORD:0000_0000x0")
				if [[ $njord_choice == "5" ]]; then
					njord_hand="NJORD:0000_0000x5"
				elif [[ $njord_choice == "F" ]]; then
					njord_hand="NJORD:0000_0000xF"
				fi
				;;
		esac
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
njord_hardware="physical"
#check config
while (( $njord_exit == 0 )); do
    handler
done

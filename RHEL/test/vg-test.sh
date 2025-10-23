#!/bin/bash

# Define a list of devices to check and clean
HDD_DEVICES=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")

# 1st check: See if any volume groups already exist
echo "Scanning for existing LVM volume groups..."

# Use vgscan to find all currently known VGs and capture the output
vgscan_output=$(sudo vgscan --ignorelockingfailure 2>/dev/null)

# Extract the volume group names from the vgscan output
vg_list=$(echo "$vgscan_output" | grep 'Found volume group' | awk '{print $4}' | sed 's/"//g')

if [ -n "$vg_list" ]; then
    echo ""
    echo "WARNING: The following LVM volume groups were found:"
    echo "$vg_list"
    echo "Continuing with the installation will erase all data in these volume groups."

    while true; do
        read -r -p "Do you wish to remove these existing LVM volume groups? (yes/no): " user_response
        case "$user_response" in
            [Yy][Ee][Ss])
                echo "Removing existing LVM volume groups..."
                for vg_name in $vg_list; do
                    # Deactivate volume group
                    sudo vgchange -an "$vg_name" >/dev/null 2>&1
                    
                    # Remove volume group (forcefully removes LVs too)
                    sudo vgremove -f "$vg_name" >/dev/null 2>&1
                    echo "Removed volume group: $vg_name"
                done

                vgremove -f "$WAREHOUSE_VG" >/dev/null 2>&1

                mdadm --stop "$WAREHOUSE_VG"

                # Remove LVM physical volume labels from all devices
                echo "Removing LVM physical volume label from all devices..."
                for device in "${HDD_DEVICES[@]}" "${CACHE_DEVICES[@]}"; do
                    pvremove -ff "$device" >/dev/null 2>&1
                done

                # Refresh LVM cache
                echo "Refreshing LVM cache..."
                sudo vgscan --cache >/dev/null 2>&1
                
               	echo "LVM cleanup complete."
                break
                ;;
            [Nn][Oo])
                echo "Installation aborted by user. Exiting."
                exit 1
                ;;
            *)
              	echo "Invalid input. Please type 'yes' or 'no'."
                ;;
        esac
    done
fi

# 2nd check: See if any logical volumes exist
echo "Scanning for existing LVM logical volumes..."

# Use lvscan to find all currently known LVs and capture the output
lv_list=$(sudo lvscan --ignorelockingfailure 2>/dev/null | grep 'ACTIVE' | awk '{print $2}' | sed 's/"//g')

if [ -n "$lv_list" ]; then
    echo ""
    echo "WARNING: The following LVM logical volumes were found and may be active:"
    echo "$lv_list"
    echo "Continuing with the installation will erase all data in these logical volumes."

    while true; do
        read -r -p "Do you wish to remove these existing LVM logical volumes? (yes/no): " user_response
        case "$user_response" in
            [Yy][Ee][Ss])
            echo "Removing existing LVM logical volumes..."
                for lv_name in $lv_list; do
                    # Deactivate logical volume
                    sudo lvchange -an "$lv_name" >/dev/null 2>&1
                    
                    # Remove logical volume
                    sudo lvremove -f "$lv_name" >/dev/null 2>&1
                    echo "Removed logical volume: $lv_name"
                done

                # Refresh LVM cache
                echo "Refreshing LVM cache..."
                sudo vgscan --cache >/dev/null 2>&1
                
                echo "LVM logical volume cleanup complete."
                break
                ;;
            [Nn][Oo])
                echo "Installation aborted by user. Exiting."
                exit 1
                ;;
            *)
                echo "Invalid input. Please type 'yes' or 'no'."
                ;;
        esac
    done
fi

# 3rd check: See if any physical volumes exist
echo "Scanning for existing LVM physical volumes..."

# Use pvscan to find all currently known PVs and capture the output
pvscan_output=$(sudo pvscan --ignorelockingfailure 2>/dev/null)

# Extract the physical volume names from the pvscan output
pv_list=$(echo "$pvscan_output" | grep 'PV' | awk '{print $2}' | sed 's/"//g')

if [ -n "$pv_list" ]; then
    echo ""
    echo "WARNING: The following LVM physical volumes were found:"
    echo "$pv_list"
    echo "This is the final LVM cleanup step before reinstalling."

    while true; do
        read -r -p "Do you wish to remove these existing LVM physical volumes? (yes/no): " user_response
        case "$user_response" in
            [Yy][Ee][Ss])
                echo "Removing existing LVM physical volumes..."
                for pv_name in $pv_list; do
                    # Forcefully remove the physical volume label
                    sudo pvremove -ff "$pv_name" >/dev/null 2>&1
                    echo "Removed physical volume: $pv_name"
                done
                
                # Refresh LVM cache
                echo "Refreshing LVM cache..."
                sudo vgscan --cache >/dev/null 2>&1
                
                echo "LVM physical volume cleanup complete."
                break
                ;;
            [Nn][Oo])
                echo "Installation aborted by user. Exiting."
                exit 1
                ;;
            *)
                echo "Invalid input. Please type 'yes' or 'no'."
                ;;
        esac
    done
fi

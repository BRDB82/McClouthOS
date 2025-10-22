#!/bin/bash

# 1st check: See if any volume groups already exist
echo "Scanning for existing LVM volume groups..."
vgscan_output=$(sudo vgscan --ignorelockingfailure 2>/dev/null)
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
                    sudo vgchange -an "$vg_name" >/dev/null 2>&1
                    sudo vgremove -f "$vg_name" >/dev/null 2>&1
                    echo "Removed volume group: $vg_name"
                done
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
                    sudo lvchange -an "$lv_name" >/dev/null 2>&1
                    sudo lvremove -f "$lv_name" >/dev/null 2>&1
                    echo "Removed logical volume: $lv_name"
                done
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
pvscan_output=$(sudo pvscan --ignorelockingfailure 2>/dev/null)
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
                    sudo pvremove -ff "$pv_name" >/dev/null 2>&1
                    echo "Removed physical volume: $pv_name"
                done
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

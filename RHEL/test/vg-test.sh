#!/bin/bash

# --- Comprehensive LVM and RAID Cleanup Script ---
# This script is for TESTING PURPOSES ONLY and will ERASE ALL DATA on the specified devices.
# It is designed to be run manually to prepare a clean environment for installation.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define storage variables (modify these arrays as needed for your tests)
HDD_DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdd" "/dev/sde")
CACHE_DEVICES=("/dev/sdc")

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "WARNING: This script is DESTRUCTIVE and will erase ALL DATA on these devices."
echo "Target devices: ${HDD_DEVICES[*]} ${CACHE_DEVICES[*]}"
echo "This is for testing purposes only."

# Ask for confirmation
while true; do
    read -r -p "Do you wish to proceed with the full cleanup? (yes/no): " user_response
    case "$user_response" in
        [Yy][Ee][Ss])
            break
            ;;
	[Nn][Oo])
            echo "Cleanup aborted by user. Exiting."
            exit 1
            ;;
	*)
            echo "Invalid input. Please type 'yes' or 'no'."
            ;;
    esac
done

echo "Starting comprehensive cleanup..."

# Step 1: Deactivate and remove any active LVM components.
echo "Deactivating and removing all LVM volume groups..."
vgscan --ignorelockingfailure > /dev/null 2>&1
for vg_name in $(vgscan --noheadings --separator ":" 2>/dev/null | awk -F: '{print $1}'); do
    echo "  - Deactivating volume group: $vg_name"
    vgchange -an "$vg_name" >/dev/null 2>&1 || true
    echo "  - Removing volume group: $vg_name"
    vgremove -f "$vg_name" >/dev/null 2>&1 || true
done

# Step 2: Stop any active RAID arrays.
echo "Stopping any active RAID arrays..."
for md_device in $(cat /proc/mdstat | grep "md" | awk '{print "/dev/"$1}'); do
    if [ -b "$md_device" ]; then
        echo "  - Stopping RAID array: $md_device"
        mdadm --stop "$md_device" >/dev/null 2>&1 || true
    fi
done

# Step 3: Remove RAID and LVM metadata from physical devices.
echo "Removing LVM and RAID metadata from all target devices..."
for device in "${HDD_DEVICES[@]}" "${CACHE_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        echo "  - Processing device: $device"
        pvremove -ff "$device" >/dev/null 2>&1 || true
        mdadm --zero-superblock --force "$device" >/dev/null 2>&1 || true
    fi
done

# Step 4: Aggressively wipe any remaining signatures.
echo "Aggressively wiping all remaining filesystem and partition signatures..."
for device in "${HDD_DEVICES[@]}" "${CACHE_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        wipefs --all --force --backup "$device" >/dev/null 2>&1 || true
    fi
done

# Step 5: Refresh device-mapper and partition tables.
echo "Refreshing LVM cache and device-mapper entries..."
dmsetup remove_all --force >/dev/null 2>&1 || true
vgscan --cache >/dev/null 2>&1 || true
partprobe >/dev/null 2>&1 || true

echo "Cleanup finished. Disks should be ready for installation."

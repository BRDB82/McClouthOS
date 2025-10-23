#!/bin/bash

# --- Comprehensive LVM and RAID Cleanup Script ---
# This script is for TESTING PURPOSES ONLY and will ERASE ALL DATA on the specified devices.
# It is designed to be run manually to prepare a clean environment for installation.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define storage variables (modify these arrays as needed for your tests)
ALL_DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")

echo "WARNING: This script is DESTRUCTIVE and will erase ALL DATA on these devices."
echo "Target devices: ${ALL_DEVICES[*]}"
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

# Step 1: Stop any active services and flush cache metadata
echo "Stopping all services that might use the disks..."
# Adapt this to stop any services on your system that might be using the disks
systemctl stop smbd nmbd >/dev/null 2>&1 || true

# Step 2: Deactivate and remove any active LVM cache components.
echo "Deactivating and removing any LVM cache volumes..."
vgscan --ignorelockingfailure >/dev/null 2>&1 || true
for vg_name in $(vgscan --noheadings --separator ":" 2>/dev/null | awk -F: '{print $1}'); do
    # Find and detach all cache logical volumes
    for cache_lv in $(lvs --noheadings -o lv_name --type cache --options vg_name="$vg_name" 2>/dev/null | awk '{print $1}'); do
        echo "  - Detaching cache volume: $vg_name/$cache_lv"
        lvchange --detach "$vg_name/$cache_lv" >/dev/null 2>&1 || true
    done
    # Remove cache pool logical volumes
    for cpool_lv in $(lvs --noheadings -o lv_name --type cache-pool --options vg_name="$vg_name" 2>/dev/null | awk '{print $1}'); do
        echo "  - Removing cache pool volume: $vg_name/$cpool_lv"
        lvremove -f "$vg_name/$cpool_lv" >/dev/null 2>&1 || true
    done
done

# Step 3: Deactivate and remove all remaining LVM components.
echo "Deactivating and removing all LVM volume groups..."
vgscan --ignorelockingfailure >/dev/null 2>&1 || true
for vg_name in $(vgscan --noheadings --separator ":" 2>/dev/null | awk -F: '{print $1}'); do
    echo "  - Deactivating volume group: $vg_name"
    vgchange -an "$vg_name" >/dev/null 2>&1 || true
    echo "  - Removing volume group: $vg_name"
    vgremove -f "$vg_name" >/dev/null 2>&1 || true
done

# Step 4: Stop any active RAID arrays.
echo "Stopping any active RAID arrays..."
# We now use mdadm --stop --force for extra robustness.
for md_device in $(cat /proc/mdstat | grep "md" | awk '{print "/dev/"$1}'); do
    if [ -b "$md_device" ]; then
        echo "  - Stopping RAID array: $md_device"
        mdadm --stop --force "$md_device" >/dev/null 2>&1 || true
    fi
done

# Step 5: Remove RAID and LVM metadata from physical devices.
echo "Removing LVM and RAID metadata from all target devices..."
for device in "${ALL_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        echo "  - Processing device: $device"
        pvremove -ff -y "$device" >/dev/null 2>&1 || true
        mdadm --zero-superblock --force "$device" >/dev/null 2>&1 || true
    fi
done

# Step 6: Aggressively wipe any remaining signatures.
echo "Aggressively wiping all remaining filesystem and partition signatures..."
for device in "${ALL_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        wipefs --all --force --backup "$device" >/dev/null 2>&1 || true
    fi
done

# Step 7: Forcefully zap any lingering partition tables.
echo "Forcefully zapping all GPT and MBR partition tables..."
for device in "${ALL_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        echo "  - Zapping partition table: $device"
        sgdisk --zap-all "$device" >/dev/null 2>&1 || true
    fi
done

# Step 8: Final low-level wipe to guarantee a clean slate
echo "Performing a low-level wipe of device beginnings..."
for device in "${ALL_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        echo "  - : $device"
        dd if=/dev/zero of="$device" bs=1M count=100 >/dev/null 2>&1 || true
    fi
done

# Step 9: Refresh device-mapper and partition tables.
echo "Refreshing LVM cache and device-mapper entries..."
dmsetup remove_all --force >/dev/null 2>&1 || true
vgscan --cache >/dev/null 2>&1 || true
partprobe >/dev/null 2>&1 || true

echo "Cleanup finished. Disks should be ready for installation."

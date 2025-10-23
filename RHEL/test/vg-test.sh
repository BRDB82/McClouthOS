#!/bin/bash

# --- Comprehensive LVM and RAID Cleanup Script ---
# Designed to specifically handle LVM cache and leave disks in a pristine state
# for your working nas-config script.
# This script is for TESTING PURPOSES ONLY and will ERASE ALL DATA on the specified devices.

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

# Step 2: Gracefully remove LVM cache components.
echo "Gracefully removing any LVM cache components..."
vgscan --ignorelockingfailure >/dev/null 2>&1 || true
for vg_name in $(vgscan --noheadings --separator ":" 2>/dev/null | awk -F: '{print $1}'); do
    # First, detach all cache LVs from their origin LVs
    for cache_lv in $(lvs --noheadings -o lv_name,vg_name,origin --options vg_name="$vg_name" | grep "\[" | awk '{print $1}'); do
        echo "  - Detaching cache logical volume: $vg_name/$cache_lv"
        lvchange --detach "$vg_name/$cache_lv" >/dev/null 2>&1 || true
    done
    # Next, remove cache pool LVs
    for cpool_lv in $(lvs --noheadings -o lv_name --type cache-pool --options vg_name="$vg_name" 2>/dev/null | awk '{print $1}'); do
        echo "  - Removing cache pool logical volume: $vg_name/$cpool_lv"
        lvremove -f "$vg_name/$cpool_lv" >/dev/null 2>&1 || true
    done
done

# Step 3: Remove all other LVM components.
echo "Removing all other LVM logical volumes and volume groups..."
vgscan --ignorelockingfailure >/dev/null 2>&1 || true
for vg_name in $(vgscan --noheadings --separator ":" 2>/dev/null | awk -F: '{print $1}'); do
    # Deactivate and remove all LVs in the VG
    lvscan --noheadings --options vg_name="$vg_name" | awk '{print $NF}' | xargs -r lvchange -an >/dev/null 2>&1 || true
    lvscan --noheadings --options vg_name="$vg_name" | awk '{print $NF}' | xargs -r lvremove -f >/dev/null 2>&1 || true
    # Remove the VG itself
    vgremove -f "$vg_name" >/dev/null 2>&1 || true
done

# Step 4: Stop any active RAID arrays.
echo "Stopping any active RAID arrays..."
for md_device in $(cat /proc/mdstat | grep "md" | awk '{print "/dev/"$1}'); do
    if [ -b "$md_device" ]; then
        echo "  - Stopping RAID array: $md_device"
        mdadm --stop --force "$md_device" >/dev/null 2>&1 || true
    fi
done

# Step 5: Aggressively wipe metadata from devices.
echo "Aggressively wiping metadata from all target devices..."
for device in "${ALL_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        echo "  - Processing device: $device"
        # mdadm --zero-superblock --force >/dev/null 2>&1 || true # Temporarily removed to avoid conflicts
        wipefs --all --force --backup "$device" >/dev/null 2>&1 || true
        sgdisk --zap-all "$device" >/dev/null 2>&1 || true
    fi
done

# Step 6: Final low-level wipe to guarantee a clean slate
echo "Performing a low-level wipe of device beginnings and ends..."
for device in "${ALL_DEVICES[@]}"; do
    if [ -b "$device" ]; then
        echo "  - Wiping device: $device"
        dd if=/dev/zero of="$device" bs=1M count=100 >/dev/null 2>&1 || true
        # Also wipe the end of the disk to clear any backup GPT headers
        end_sector=$(blockdev --getsz "$device")
        dd if=/dev/zero of="$device" bs=512 seek=$((end_sector-2048)) count=2048 >/dev/null 2>&1 || true
    fi
done

# Step 7: Refresh device-mapper and partition tables.
echo "Refreshing LVM cache and device-mapper entries..."
dmsetup remove_all --force >/dev/null 2>&1 || true
partprobe >/dev/null 2>&1 || true
# Re-scan for LVM devices after cleanup, not to run commands based on them
vgscan --cache --ignorelockingfailure >/dev/null 2>&1 || true


echo "Cleanup finished. Disks should be ready for your nas-config script."

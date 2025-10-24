#!/bin/bash

# Function to check if a device is root
is_root_device() {
    local device=$1
    mount | grep -q "^$device on / "
    return $?
}

# Function to identify SSD
is_ssd() {
    local device=$1
    if [ -n "$(cat /sys/block/${device#/dev/}/queue/rotational 2>/dev/null)" ]; then
        [ "$(cat /sys/block/${device#/dev/}/queue/rotational)" -eq 0 ]
        return $?
    fi
    return 1
}

# Function to monitor RAID build progress
monitor_raid_progress() {
    local md_device=$1
    while true; do
        if [ -f "/proc/mdstat" ]; then
            local progress=$(cat /proc/mdstat | grep -A 1 "$md_device" | grep -oP '\[=*>*\]\s+\K[0-9.]+(?=%)' || echo "100.0")
            echo -ne "RAID build progress: $progress%\r"
            if [ "${progress%.*}" -eq 100 ]; then
                echo -e "\nRAID build complete"
                break
            fi
        fi
        sleep 1
    done
}

echo "Starting warehouse storage reconfiguration..."

# Get all block devices
devices=($(lsblk -d -n -o NAME | grep -E '^sd[a-z]$'))
spinning_disks=()
ssd_cache=""

# Categorize devices
for dev in "${devices[@]}"; do
    device="/dev/$dev"
    
    # Skip root device
    if is_root_device "$device"; then
        continue
    fi
    
    # Identify SSD for cache
    if is_ssd "$device" && [ -z "$ssd_cache" ]; then
        ssd_cache=$device
        echo "Found SSD for cache: $ssd_cache"
    else
        spinning_disks+=($device)
    fi
done

# Verify we have enough disks
if [ ${#spinning_disks[@]} -lt 4 ]; then
    echo "Error: Not enough spinning disks found. Need at least 4."
    exit 1
fi

if [ -z "$ssd_cache" ]; then
    echo "Error: No SSD found for cache."
    exit 1
fi

echo "Clearing existing warehouse configuration..."

# Remove from fstab if exists
sed -i '/\/srv\/warehouse/d' /etc/fstab

# Unmount if mounted
umount -f /srv/warehouse 2>/dev/null

# Remove existing LVM configuration
lvchange -an /dev/warehouse_vg/warehouse_lv 2>/dev/null
lvremove -f warehouse_vg 2>/dev/null
vgremove -f warehouse_vg 2>/dev/null

# Stop all MD arrays
mdadm --stop --scan 2>/dev/null
mdadm --zero-superblock --force "${spinning_disks[@]}" "$ssd_cache" 2>/dev/null

echo "Creating new RAID 5 array..."

# Create RAID 5 array with force
echo y | mdadm --create --run /dev/md0 --level=5 --raid-devices=${#spinning_disks[@]} --force "${spinning_disks[@]}"

echo "Monitoring RAID array initialization..."
monitor_raid_progress md0

echo "Creating LVM configuration..."

# Wipe and initialize physical volumes
wipefs -af "$ssd_cache"
wipefs -af /dev/md0

# Create PVs with force
pvcreate -ff -y /dev/md0
pvcreate -ff -y "$ssd_cache"

# Create volume group with force
vgcreate -ff -y warehouse_vg /dev/md0

# Create logical volume
lvcreate -y -l 100%FREE -n warehouse_lv warehouse_vg

# Extend VG with SSD
vgextend -f -y warehouse_vg "$ssd_cache"

# Create cache pool with fixed sizes
lvcreate -y -L 100G -n cache_pool warehouse_vg "$ssd_cache"
lvcreate -y -L 1G -n cache_pool_meta warehouse_vg "$ssd_cache"

# Convert to cache pool and attach to main LV with force
lvconvert --yes --force --type cache-pool --poolmetadata warehouse_vg/cache_pool_meta warehouse_vg/cache_pool
lvconvert --yes --force --type cache --cachepool warehouse_vg/cache_pool warehouse_vg/warehouse_lv

echo "Creating filesystem..."
# Create XFS filesystem with force and progress indication
mkfs.xfs -f /dev/warehouse_vg/warehouse_lv 2>&1 | while IFS= read -r line; do
    echo "Filesystem creation: $line"
done

# Create mount point
mkdir -p /srv/warehouse

# Add to fstab and reload systemd
echo "/dev/warehouse_vg/warehouse_lv /srv/warehouse xfs defaults 0 0" >> /etc/fstab
systemctl daemon-reload

 Mount the filesystem
mount /srv/warehouse

echo "Warehouse configuration complete!"
echo "Storage is mounted at /srv/warehouse"

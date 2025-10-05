
#!/bin/bash

# Redirect stout and stderr to mcclouthos.log and still output to console
exec > >(tee -i mcclouthos.log)
exec 2>&1


check_background() {
    check_rhel
    detect_rhel
    check_root
    check_release
    check_dnf
}

check_dnf() {
    if [[ -f /var/lib/dnf/lock ]] || ps -e | grep -w -E 'dnf|yum' >/dev/null; then
        echo "ERROR! DNF is blocked."
        echo -ne "If not running remove /var/lib/dnf/lock or kill the running process.\n"
        exit 0
    fi
}

check_release() {
    if [[ ! -e /etc/redhat-release ]]; then
        echo -ne "ERROR! This script must be run on RedHat-based Linux!\n"
        exit 0
    fi
}

check_rhel() {
    if ! ps aux | grep "[a]naconda" > /dev/null; then
        echo "This script must be run from a RHEL Linux ISO environment."
        exit 1
    fi
}

check_root() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! This script must be run under the 'root' user!\n"
        exit 0
    fi
}

clear() {
  printf "\033[H\033[J" #clear
}

detect_rhel() {

    distro_id=$(grep '^ID=' "/etc/os-release" 2>/dev/null | cut -d'=' -f2 | tr -d '"')

}

disk_create_filesystems () {
    if [[ "${DISK}" =~ "nvme" ]]; then
        partition1=${DISK}p1
        partition2=${DISK}p2
        partition3=${DISK}p3
    else
        partition1=${DISK}1
        partition2=${DISK}2
        partition3=${DISK}3
    fi
    
    mkfs.ext4 -L BOOT "${partition1}"
    mkfs.fat -F32 -n "EFIBOOT" "${partition2}"
    
    if [[ "${FS}" == "xfs" ]]; then 
        mkfs.xfs -f -L ROOT "${partition3}"
        mount -t xfs "${partition3}" /mnt
    elif [[ "${FS}" == "ext4" ]]; then
        mkfs.ext4 "${partition3}"
        mount -t ext4 "${partition3}" /mnt
    fi
    
    BOOT_UUID=$(blkid -s UUID -o value "${partition1}")
    EFI_UUID=$(blkid -s UUID -o value "${partition2}")
    
    sync
    if ! mountpoint -q /mnt; then
        echo "ERROR! Failed to mount ${partition3} to /mnt after multiple attempts."
        exit 1
    fi
    
    mkdir -p /mnt/boot
    mount -U "${BOOT_UUID}" /mnt/boot/
    mkdir -p /mnt/boot/efi
    mount -U "${EFI_UUID}" /mnt/boot/efi
    
    if ! grep -qs '/mnt' /proc/mounts; then
        echo "Drive is not mounted, cannot continue"
        echo "Rebooting in 3 Seconds ..." && sleep 1
        echo "Rebooting in 2 Seconds ..." && sleep 1
        echo "Rebooting in 1 Second ..." && sleep 1
        reboot now
    fi
}

disk_format () {
    umount -A --recursive /mnt # make sure everything is unmounted before we start
    # disk prep
    sgdisk -Z "${DISK}" # zap all on disk
    sgdisk -a 2048 -o "${DISK}" # new gpt disk 2048 alignment
    
    # create partitions
    sgdisk -n 1::+1G --typecode=1:8300 --change-name=1:'BOOT' "${DISK}" # partition 1 (BIOS Boot Partition)
    sgdisk -n 2::+1G --typecode=2:ef00 --change-name=2:'EFIBOOT' "${DISK}" # partition 2 (UEFI Boot Partition)
    sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' "${DISK}" # partition 3 (Root), default start, remaining
    if [[ ! -d "/sys/firmware/efi" ]]; then # Checking for bios system
        sgdisk -A 1:set:2 "${DISK}"
    fi
    partprobe "${DISK}" # reread partition table to ensure it is correct
}

disk_fs () {
    echo -ne "
    Please Select your file system for both boot and root
    "
    options=("xfs" "ext4" "exit")
    select_option "${options[@]}"

    case $? in
    0) export FS=xfs;;
    1) export FS=ext4;;
    2) exit ;;
    *) echo "Wrong option please select again"; filesystem;;
    esac
}

disk_installbootloader() {
    efibootmgr -v | grep Boot
    
    echo ""
    read -p "Give all entries to remove, or enter stop to continue: " input
    
    if [[ "$input" == "stop" ]]; then
      echo ""
    else
     for bootnum in $input; do
          if [[ "$bootnum" =~ ^[0-9]+$ ]]; then
              echo "Removing entry $bootnum..."
              efibootmgr -B -b "$bootnum"
          else
              echo "Invalid entry: '$bootnum'"
          fi
      done
    fi
    
    #if [[ -d "/sys/firmware/efi" ]]; then
        grub2-install \
          --target=x86_64-efi \
          --efi-directory=/mnt/boot/efi \
          --bootloader-id=McClouthOS \
          --boot-directory=/mnt/boot \
          --recheck \
          --force
    #else
    #    grub2-install --boot-directory=/mnt/boot "${DISK}"
    #fi
}

disk_installon() {
    # Detect EFI and install base system
    mkdir -p /mnt/etc/dnf/vars
    echo "$VERSION" > "/mnt/etc/dnf/vars/releasever"
    echo "x86_64" > "/mnt/etc/dnf/vars/basearch"
    echo "production" > "/mnt/etc/dnf/vars/rltype"
    cp /etc/os-release /mnt/etc
    #if [[ ! -d "/sys/firmware/efi" ]]; then
        dnfstrap /mnt @core @"Development Tools" kernel linux-firmware grub2 efibootmgr grub2-efi-x64 grub2-efi-x64-modules nano --assumeyes
    #else
    #    dnfstrap /mnt @core @"Development Tools" kernel linux-firmware grub2 --assumeyes
    #fi
    
    # Import official GPG key (optional, for repo trust)
    find /etc/pki/rpm-gpg/ -type f -name 'RPM-GPG-KEY-*' -exec install -Dm644 {} /mnt{} \;
    find /mnt/etc/pki/rpm-gpg/ -type f -name 'RPM-GPG-KEY-*' -exec rpm --root /mnt --import {} \;
    
    
    # Copy repo configurations
    #cp /tmp/alma-repos.d/*.repo /mnt/etc/yum.repos.d/
    #sed -i 's/^enabled=1/enabled=0/' /mnt/etc/yum.repos.d/alma.repo
    
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "
      Generated /etc/fstab:
    "
    cat /mnt/etc/fstab
}

disk_part () {
    echo -ne "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formatting your disk there is no way to get data back
    *****BACKUP YOUR DATA BEFORE CONTINUING*****
    ***I AM NOT RESPONSIBLE FOR ANY DATA LOSS***
------------------------------------------------------------------------

"

    PS3='
    Select the disk to install on: '
    options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

    select_option "${options[@]}"
    disk=${options[$?]%|*}

    echo -e "\n${disk%|*} selected \n"
        export DISK=${disk%|*}

    disk_type
}

disk_type () {
    echo -ne "
Is this an SSD? yes/no:
"
    options=("Yes" "No")
    select_option "${options[@]}"

    case $? in
        0)
            export MOUNT_OPTIONS="noatime,commit=120"
            ;;
        1)
            export MOUNT_OPTIONS="noatime,commit=120"
            ;;
        *)
            echo "Wrong option. Try again"
            disk_type
            ;;
    esac
}

keymap () {
    echo -ne "
Please select keyboard layout from this list
"
    # These are default key maps commonly supported on Alma Linux
    options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

    select_option "${options[@]}"
    keymap=${options[$?]}

    echo -ne "Your keyboard layout: ${keymap} \n"
    export KEYMAP=$keymap

    # Apply the selected keymap using localectl
    localectl set-keymap "$keymap"
}

logo() {
# This will be shown on every set as user is progressing
echo -ne "
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝
Powered by RHEL
"
}

select_option() {
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local last_selected=-1

    while true; do
        # Move cursor up to the start of the menu
        if [ $last_selected -ne -1 ]; then
            echo -ne "\033[${num_options}A"
        fi

        if [ $last_selected -eq -1 ]; then
            echo "Please select an option using the arrow keys and Enter:"
        fi
        for i in "${!options[@]}"; do
            if [ "$i" -eq $selected ]; then
                echo "> ${options[$i]}"
            else
                echo "  ${options[$i]}"
            fi
        done

        last_selected=$selected

        # Read user input
        read -rsn1 key
        case $key in
            $'\x1b') # ESC sequence
                read -rsn2 -t 0.1 key
                case $key in
                    '[A') # Up arrow
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        ;;
                    '[B') # Down arrow
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
                            selected=0
                        fi
                        ;;
                esac
                ;;
            '') # Enter key
                break
                ;;
        esac
    done

    return $selected
}

setup_installer_environment() {

    dnf --releasever=10 update -y
    dnf --releasever=10 clean all
    dnf --releasever=10 makecache
    dnf --releasever=10 -y rpm
    dnf --releasever=10 -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm --nogpgcheck
    dnf --releasever=10 install -y grub2 grub2-tools grub2-efi-x64 grub2-efi-x64-modules kbd systemd-resolved
    dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
    setfont ter-118b
    
    systemctl enable systemd-resolved
    systemctl start systemd-resolved
    #ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    cp /etc/resolv.conf /mnt/etc/resolv.conf

    if [ ! -d "/mnt" ]; then
        mkdir /mnt
    fi
}

setup_installer_environment2() {
    #sed -i '/^\[repl\]/,/^\[/{s/^enabled=.*/enabled=1/}' /tmp/rhel.repos.d/epel.repo
    #sed -i '/^\[crb\]/,/^\[/{s/^enabled=.*/enabled=1/}' /tmp/rhel.repos.d/epel.repo
    
    dnf ----releasever=10 install -y gdisk
    wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/dnfstrap.sh
      chmod +x dnfstrap.sh
      mv dnfstrap.sh /usr/bin/dnfstrap
    wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/common
      mv common /usr/bin/dnfcommon
    wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/rhel-chroot.sh
      chmod +x rhel-chroot.sh
      mv rhel-chroot.sh /usr/bin/rhel-chroot
    wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/genfstab.sh
      chmod +x genfstab.sh
      mv genfstab.sh /usr/bin/genfstab
    wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/fstab-helpers
      mv fstab-helpers /usr/bin/fstab-helpers
}

setup_mirrors() {
   echo "Setting up mirrors for optimal download"
    is=$(curl -4 -s ifconfig.io/country_code)
    timedatectl set-ntp true

    mkdir -p /etc/yum.repos.d
    
    #Check if we have registered system
    if ! subscription-manager status 2>/dev/null | grep -q "Overall Status: Registered"; then
      read -p "CDN Username: " RHEL_USER
      read -s -p "CDN Password: " RHEL_PASS
      echo
    
      echo "📡 Registring with Red Hat..."
      output=$(subscription-manager register --username="$RHEL_USER" --password="$RHEL_PASS" 2>&1) && rc=$? || rc=$?
      echo "$output"
    
      if [[ $rc -ne 0 ]]; then
        echo "❌ Registration failed."
        exit $rc
      fi
    
      unset RHEL_USER
      unset RHEL_PASS
    fi
    
    subscription-manager refresh
    
    subscription-manager repos --enable="rhel-$RHEL_VERSION-for-x86_64-baseos-rpms"
}

system_choice() {
  #ask user whether to install a server or a workstation
  echo -ne "
Please select which system you want to install from this list
"
    # These are default key maps commonly supported on Alma Linux
    options=(server workstation)

    select_option "${options[@]}"
    system_choice=${options[$?]}

    echo -ne "Your system of choice: ${system_choice} \n"

    #./mcclouth-setup
    export SYSTEM_OF_CHOICE=$system_choice
}

system_timezone () {
    # Attempt to detect timezone using external service
    time_zone="$(curl --fail -s https://ipapi.co/timezone)"
    echo -ne "
System detected your timezone to be '$time_zone' \n"
    echo -ne "Is this correct?
    "
    options=("Yes" "No")
    select_option "${options[@]}"

    case $? in
        0)
            echo "${time_zone} set as timezone"
            export TIMEZONE=$time_zone
            timedatectl set-timezone "$time_zone"
            ;;
        1)
            echo "Please enter your desired timezone e.g. Europe/Brussels :"
            read -r new_timezone
            echo "${new_timezone} set as timezone"
            export TIMEZONE=$new_timezone
            timedatectl set-timezone "$new_timezone"
            ;;
        *)
            echo "Wrong option. Try again"
            timezone
            ;;
    esac
}

# @description Gather username and password to be used for installation.
userinfo () {
    # Loop through user input until the user gives a valid username
    while true
    do
            read -r -p "Please enter username: " username
            if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
            then
                    break
            fi
            echo "Incorrect username."
    done
    export USERNAME=$username

    while true
    do
        read -rs -p "Please enter password: " PASSWORD1
        echo -ne "\n"
        read -rs -p "Please re-enter password: " PASSWORD2
        echo -ne "\n"
        if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
            break
        else
            echo -ne "ERROR! Passwords do not match. \n"
        fi
    done
    export PASSWORD=$PASSWORD1

     # Loop through user input until the user gives a valid hostname, but allow the user to force save
    while true
    do
            read -r -p "Please name your machine: " name_of_machine
            # hostname regex (!!couldn't find spec for computer name!!)
            if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]
            then
                    break
            fi
            # if validation fails allow the user to force saving of the hostname
            read -r -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
            if [[ "${force,,}" = "y" ]]
            then
                    break
            fi
    done
    export NAME_OF_MACHINE=$name_of_machine
}

# main
clear
logo
echo -ne "
--------------------------------------------------------------------------------------------
                    Automated McClouth OS Base Installer
--------------------------------------------------------------------------------------------

"

check_background

clear
logo
echo -ne "
-------------------------------------------------------------------------------------------
                      Please select presetup settings for your system
-------------------------------------------------------------------------------------------

"
userinfo

clear
logo
disk_part

clear
logo
disk_fs

clear
logo
system_timezone

clear
logo
system_keymap

clear
logo
system_choice

clear
logo
echo -ne "
-------------------------------------------------------------------------------------------
                      Setting up install environment
-------------------------------------------------------------------------------------------

"
setup_mirrors
setup_installer_environment

clear
logo
echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
setup_installer_environment2

clear
logo
echo -ne "
-------------------------------------------------------------------------
                    Formatting Disk
-------------------------------------------------------------------------
"
disk_format

clear
logo
echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
disk_create_filesystems

clear
logo
echo -ne "
-------------------------------------------------------------------------
                    RHEL Install on Main Drive
-------------------------------------------------------------------------
"

disk_installon

clear
logo
echo -ne "
-------------------------------------------------------------------------
                    GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------
"
disk_installbootloader

clear
logo
echo -ne "
-------------------------------------------------------------------------
                    Checking for low memory systems <8G
-------------------------------------------------------------------------
"

TOTAL_MEM=$(awk '/MemTotal/ { print $2 }' /proc/meminfo) # in KiB

if [[ $TOTAL_MEM -lt 8000000 ]]; then
    echo "Low memory detected: enabling zram swap"

    # Load zram module
    modprobe zram

    # Configure zram0 with 2G compressed swap
    echo lz4 > /sys/block/zram0/comp_algorithm
    echo $((2 * 1024 * 1024 * 1024)) > /sys/block/zram0/disksize

    # Format and enable swap
    mkswap /dev/zram0
    swapon /dev/zram0

    # Persist zram swap in target system
    mkdir -p /mnt/etc/systemd/zram-generator.conf.d
    cat > /mnt/etc/systemd/zram-generator.conf.d/00-zram.conf <<EOF
[zram0]
zram-size = 2048MiB
compression-algorithm = lz4
EOF

    echo "ZRAM swap configured and will persist after install"
fi

gpu_type=$(lspci | grep -E "VGA|3D|Display")

rhel-chroot /mnt /bin/bash -c "KEYMAP='${KEYMAP}' /bin/bash" <<EOF

echo -ne "
-------------------------------------------------------------------------
                    Network Setup
-------------------------------------------------------------------------
"
echo 'nameserver 1.1.1.1' > /etc/resolv.conf
dnf install -y NetworkManager --nogpgcheck
systemctl enable NetworkManager
systemctl start NetworkManager
echo -ne "
-------------------------------------------------------------------------
                    Setting up repos for optimal download
-------------------------------------------------------------------------
"
dnf install -y curl git wget chrony
dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/t/terminus-fonts-console-4.48-1.el8.noarch.rpm --nogpgcheck
dnf install -y rsync grub2
wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/dnfstrap.sh
  chmod +x dnfstrap.sh
  mv dnfstrap.sh /usr/bin/dnfstrap
wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/common
  mv common /usr/bin/dnfcommon
wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/rhel-chroot.sh
  chmod +x rhel-chroot.sh
  mv rhel-chroot.sh /usr/bin/rhel-chroot
wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/genfstab.sh
  chmod +x genfstab.sh
  mv genfstab.sh /usr/bin/genfstab
wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/rhel-install-scripts/fstab-helpers
  mv fstab-helpers /usr/bin/fstab-helpers
wget https://raw.githubusercontent.com/BRDB82/McClouthOS/main/Rocky/mcclouth-setup.sh
  chmod +x mcclouth-setup.sh
  mv mcclouth-setup.sh /usr/bin/mcclouth-setup
dnf install -y git ntp
cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak

nc=$(grep -c ^"cpu cores" /proc/cpuinfo)
echo -ne "
-------------------------------------------------------------------------
                    You have " $nc" cores. And
            changing the makeflags for " $nc" cores. Aswell as
                changing the compression settings.
-------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -gt 8000000 ]]; then
sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi
echo -ne "
-------------------------------------------------------------------------
                    Setup Language to US and set locale
-------------------------------------------------------------------------
"
locale -a | grep -q en_US.UTF-8 || localedef -i en_US -f UTF-8 en_US.UTF-8
timedatectl --no-ask-password set-timezone "${TIMEZONE}"
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# Set keymap
localectl --no-ask-password set-keymap "${KEYMAP}"
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
echo "Keymap set to: ${KEYMAP}"

# Add sudo no-password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# Optimize DNF behavior
echo "max_parallel_downloads=5" >> /etc/dnf/dnf.conf
echo "color=always" >> /etc/dnf/dnf.conf

# Refresh metadata
dnf makecache

echo -ne "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------
"

# Determine processor type and install microcode
if grep -q "GenuineIntel" /proc/cpuinfo; then
    echo "Installing Intel microcode"
    dnf install -y microcode_ctl
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    echo "Installing AMD microcode"
    dnf install -y linux-firmware
else
    echo "Unable to determine CPU vendor. Skipping microcode installation."
fi

echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"

# Graphics Drivers find and install
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo "Installing NVIDIA drivers via dnf module"
    dnf clean all
    dnf module install -y nvidia-driver:latest-dkms
    dnf install -y nvidia-gds cuda
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Installing AMD drivers (bundled in linux-firmware)"
    dnf install -y linux-firmware mesa-dri-drivers mesa-vulkan-drivers
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller|Intel Corporation UHD"; then
    echo "Installing Intel drivers"
    dnf config-manager --add-repo https://repositories.intel.com/graphics/rhel/8.6/flex/intel-graphics.repo
    dnf clean all
    dnf makecache
    dnf install -y intel-opencl intel-media intel-mediasdk libvpl2 level-zero intel-level-zero-gpu \
                   mesa-dri-drivers mesa-vulkan-drivers mesa-vdpau-drivers libva libva-utils
else
    echo "Unknown GPU type. Skipping graphics driver installation."
fi

echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
getent group libvirt >/dev/null || groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash "$USERNAME"
echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "$USERNAME password set"
echo "$NAME_OF_MACHINE" > /etc/hostname
hostnamectl set-hostname "$NAME_OF_MACHINE"

echo -ne "
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝

--------------------------------------------------------------------------------------------
                Automated McClouth OS Base Installer (powered by Rocky)
--------------------------------------------------------------------------------------------

Final Setup and Configurations
GRUB EFI Bootloader Install & Check
"
#if [[ -d "/sys/firmware/efi" ]]; then
    grub2-install --efi-directory=/boot "${DISK}"
#fi

echo -ne "
-------------------------------------------------------------------------
               Creating Grub Boot Menu
-------------------------------------------------------------------------
"

# Add splash screen
sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& splash /' /etc/default/grub

echo -e "Updating grub..."
grub2-mkconfig -o /boot/grub2/grub.cfg
echo -e "All set!"

echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
chronyd -q
systemctl enable chronyd.service
echo "  Chrony (NTP) enabled"
systemctl disable network.service 2>/dev/null || true
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"

echo -ne "
-------------------------------------------------------------------------
                    Install $SYSTEM_OF_CHOICE
-------------------------------------------------------------------------
"
#mcclouth-setup "$SYSTEM_OF_CHOICE"

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
# Remove no password sudo rights
visudo -c >/dev/null && sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# &/' /etc/sudoers
visudo -c >/dev/null && sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# &/' /etc/sudoers
# Add sudo rights
visudo -c >/dev/null && sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
visudo -c >/dev/null && sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

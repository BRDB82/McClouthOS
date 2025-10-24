#!/bin/bash
# This script sets up Samba for a NAS admin with shares DATA and BACKUP on RHEL (run as root).

# Install Samba using DNF, which is appropriate for RHEL 10+
dnf install -y samba policycoreutils-python-utils

# Create folders for shares
mkdir -p /srv/warehouse/DATA
mkdir -p /srv/warehouse/BACKUP

# Create the local-only admin user if not already present
if ! id "smb001mi" &>/dev/null; then
    useradd -M -s /sbin/nologin smb001mi
fi

# Prompt for the Samba password for the nas admin user
echo "Enter password for Samba user smb001mi:"
read -s SMBPASS1
echo "Retype password:"
read -s SMBPASS2

if [[ "$SMBPASS1" != "$SMBPASS2" ]]; then
    echo "Passwords do not match. Exiting."
    exit 1
fi

# Set the Samba password for smb001mi
(echo "$SMBPASS1"; echo "$SMBPASS1") | smbpasswd -a -s smb001mi

# Set permissions for the share directories
chown -R smb001mi:smb001mi /srv/warehouse/DATA
chmod -R 770 /srv/warehouse/DATA

chown -R smb001mi:smb001mi /srv/warehouse/BACKUP
chmod -R 770 /srv/warehouse/BACKUP

# Backup current smb.conf
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Overwrite smb.conf with a minimal configuration: removes homes, printers, print$ and leaves only necessary [global] and shares.
cat <<EOT > /etc/samba/smb.conf
[global]
    workgroup = WORKGROUP
    security = user
    map to guest = bad user
    server string = McClouthOS FS

[DATA]
    path = /srv/warehouse/DATA
    browseable = yes
    writable = yes
    valid users = smb001mi
    force user = smb001mi
    force group = smb001mi
    create mask = 0770
    directory mask = 0770

[BACKUP]
    path = /srv/warehouse/BACKUP
    browseable = yes
    writable = yes
    valid users = smb001mi
    force user = smb001mi
    force group = smb001mi
    create mask = 0770
    directory mask = 0770

EOT

# Enable and start the Samba service
systemctl enable --now smb

firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --reload

semanage fcontext -a -t samba_share_t "/srv/warehouse(/.*)?"
restorecon -R -v /srv/warehouse
setsebool -P samba_export_all_rw on

systemctl restart smb.service
semanage fcontext -a -t samba_share_t "/srv/warehouse/DATA(/.*)?"echo "Samba is configured! Shares DATA and BACKUP are available for smb001mi on Windows, Linux, and MacOS."

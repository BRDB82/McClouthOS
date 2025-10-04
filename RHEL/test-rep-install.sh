 #!/bin/bash
 VERSION=$(curl -s https://developers.redhat.com/products/rhel/download | \
            grep -oE 'Red Hat Enterprise Linux [0-9]+\.[0-9]+' | \
            grep -oE '[0-9]+\.[0-9]+' | \
            sort -V | tail -1 | sed 's:/$::')
  
[ -d /etc/yum.repos.d ] || mkdir /etc/yum.repos.d
[ -d /tmp/rhel.repos.d ] || mkdir /tmp/rhel.repos.d

while true; do
	read -p "Red Hat account: " RHELuser
	read -s -p "Red Hat password: " RHELpasswd
	echo

	output=$(subscription-manager register --username="$RHELuser" --password="$RHELpasswd")
	echo "$output"

    if echo "$output" | grep -q "Invalid username or password. To create a login"; then
        echo "Please try again."
        unset RHELuser
        unset RHELpasswd
        sleep 2
    else
        unset RHELuser
        unset RHELpasswd
        break
    fi
done

ENTITLEMENT_CERT=$(find /etc/pki/entitlement -type f -name "*.pem" ! -name "*-key.pem" | head -n 1)
ENTITLEMENT_KEY=$(find /etc/pki/entitlement -type f -name "*-key.pem" | head -n 1)
CONSUMER_CERT=$(find /etc/pki/consumer -type f -name "*cert.pem" | head -n 1)
CONSUMER_KEY=$(find /etc/pki/consumer -type f -name "*key.pem" | head -n 1)

if [ ! -f /tmp/rhel.repos.d/BaseOS.repo ]; then
	{
	echo "[rhel-baseos]"
	echo "name=Red Hat Enterprise Linux $VERSION - BaseOS"
	echo "baseurl=https://cdn.redhat.com/content/dist/rhel/$VERSION/x86_64/BaseOS/production/os/"
	echo "enabled=1"
	echo "gpgcheck=0"
	echo "sslverify=1"
	echo "sslclientcert=$ENTITLEMENT_CERT"
	echo "sslclientkey=$ENTITLEMENT_KEY"
	} > /tmp/rhel.repos.d/BaseOS.repo
fi

echo "releasever=$VERSION" >> /etc/dnf/dnf.conf
echo "$VERSION" > /etc/dnf/vars/releasever
echo "x86_64" > /etc/dnf/vars/basearch
echo "production" > /etc/dnf/vars/rltype

rm -f /etc/yum.repos.d/*.repo

for f in /tmp/rhel.repos.d/*.repo; do
	ln -s "$f" /etc/yum.repos.d/$(basename "$f")
done


#subscription-manager attach --auto
sleep 5
dnf --setopt=reposdir=/tmp/rhel.repos.d update -y
dnf --setopt=reposdir=/tmp/rhel.repos.d clean all
dnf --setopt=reposdir=/tmp/rhel.repos.d makecache
dnf --setopt=reposdir=/tmp/rhel.repos.d install -y rpm

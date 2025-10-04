 #!/bin/bash
exec > >(tee -i repo-test.log)
exec 2>&1

if [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/RHEL/test-rep-install.sh" -o "test-rep-install.sh.new" || {
		echo "update failed"
	    rm "test-rep-install.sh.new"
	    exit 1
	}
	chmod +x "test-rep-install.sh.new"
	mv -f "test-rep-install.sh.new" "test-rep-install.sh"
	exit 0
fi
 
echo "=== RHEL Registration and Repo Setup Script ==="

# Get latest RHEL version from Red Hat's CDN or developer site
echo "Detecting latest RHEL version..."
RHEL_VERSION=$(curl -s https://cdn.redhat.com/content/dist/rhel/server/ | grep -oE 'href="[0-9]+\.[0-9]+/' | grep -oE '[0-9]+\.[0-9]+' | sort -V | tail -1)
if [[ -z "$RHEL_VERSION" ]]; then
    RHEL_VERSION=$(curl -s https://developers.redhat.com/products/rhel/download | grep -oE 'Red Hat Enterprise Linux [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | sort -V | tail -1)
fi
if [[ -z "$RHEL_VERSION" ]]; then
    echo "Could not detect RHEL version automatically."
    exit 1
fi
echo "Detected RHEL version: $RHEL_VERSION"

# Ensure repo directories exist
mkdir -p /etc/yum.repos.d
mkdir -p /tmp/rhel.repos.d

# Check if system is already registered BEFORE prompting for credentials
if subscription-manager status 2>/dev/null | grep -q "Overall Status: Registered"; then
    REGISTERED=1
elif [ -f /etc/pki/consumer/cert.pem ]; then
    REGISTERED=1
else
    REGISTERED=0
fi

if [[ $REGISTERED -eq 0 ]]; then
    # Prompt for Red Hat credentials and register
    while true; do
        read -p "Red Hat account (username): " RHEL_USER
        read -s -p "Red Hat password: " RHEL_PASS
        echo
        if [[ -z "$RHEL_USER" || -z "$RHEL_PASS" ]]; then
            echo "Username and password required."
            continue
        fi
        echo "Registering system with Red Hat..."
        output=$(subscription-manager register --username="$RHEL_USER" --password="$RHEL_PASS" 2>&1) && rc=$? || rc=$?
        echo "$output"
        if [[ $rc -eq 0 ]]; then
            echo "Registration successful."
            break
        elif echo "$output" | grep -qi "This system is already registered"; then
            echo "System is already registered (according to subscription-manager)."
            break
        elif echo "$output" | grep -qi "Invalid username or password"; then
            echo "Invalid credentials, please try again."
        else
            echo "Registration failed, please check your account or network."
        fi
    done
    unset RHEL_USER
    unset RHEL_PASS
fi

# No attach step for RHEL 10.0, skip it

# Get entitlement certs for repo SSL
ENT_CERT=$(find /etc/pki/entitlement -type f -name "*.pem" ! -name "*-key.pem" | head -n 1)
ENT_KEY=$(find /etc/pki/entitlement -type f -name "*-key.pem" | head -n 1)

if [[ ! -f "$ENT_CERT" || ! -f "$ENT_KEY" ]]; then
    echo "Entitlement certificates not found. Registration may have failed."
    exit 2
fi

# Use Red Hat's GPG key, not a self-signed one
GPG_KEY_PATH="/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
if [[ ! -f "$GPG_KEY_PATH" ]]; then
    echo "Downloading Red Hat GPG key..."
    curl -o "$GPG_KEY_PATH" https://www.redhat.com/security/data/fd431d51.txt
fi

# --- SSL FIX FOR CURL ERROR 60 ---
# Update CA trust and import Red Hat's CA if needed
echo "Updating CA trust and importing Red Hat CA if needed..."
# Remove force-enable, just use extract (force-enable is not a valid option)
update-ca-trust extract || true

# Download Red Hat's CA certificate and add to system trust if not present
# Extract Red Hat CDN certificate chain and trust it
RH_CA_PATH="/etc/pki/ca-trust/source/anchors/redhat-cdn.pem"
if ! grep -q "Red Hat" "$RH_CA_PATH" 2>/dev/null; then
    echo "Extracting Red Hat CDN certificate chain..."
    echo -n | openssl s_client -showcerts -connect cdn.redhat.com:443 \
      | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/ { print }' \
      > "$RH_CA_PATH"
    update-ca-trust extract
fi

# Also ensure ca-certificates package is installed and up to date
dnf install -y ca-certificates || yum install -y ca-certificates

# Create BaseOS repo file with correct SSL and GPG settings
cat > /tmp/rhel.repos.d/BaseOS.repo <<EOF
[rhel-baseos]
name=Red Hat Enterprise Linux $RHEL_VERSION - BaseOS
baseurl=https://cdn.redhat.com/content/dist/rhel/$RHEL_VERSION/x86_64/baseos/os/
enabled=1
gpgcheck=1
gpgkey=file://$GPG_KEY_PATH
sslverify=1
sslclientcert=$ENT_CERT
sslclientkey=$ENT_KEY
EOF

# Set DNF variables for releasever and basearch
echo "$RHEL_VERSION" > /etc/dnf/vars/releasever
echo "x86_64" > /etc/dnf/vars/basearch
echo "production" > /etc/dnf/vars/rltype

# Remove any existing repo files and link new ones
rm -f /etc/yum.repos.d/*.repo
for f in /tmp/rhel.repos.d/*.repo; do
    ln -sf "$f" /etc/yum.repos.d/$(basename "$f")
done

# Clean and update DNF
echo "Cleaning and updating DNF cache..."
dnf --setopt=reposdir=/tmp/rhel.repos.d clean all
dnf --setopt=reposdir=/tmp/rhel.repos.d makecache
dnf --setopt=reposdir=/tmp/rhel.repos.d install -y ca-certificates || true
dnf --setopt=reposdir=/tmp/rhel.repos.d install -y rpm

echo "=== RHEL registration and repo setup complete. You can now install packages. ==="
#update1833

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

subscription-manager repos --enable=rhel-10-for-x86_64-baseos-rpms

echo "=== Verifiëren van toegang tot Red Hat CDN met entitlement-certificaten ==="
ENT_CERT=$(find /etc/pki/entitlement -type f -name "*.pem" ! -name "*-key.pem" | head -n 1)
ENT_KEY=$(find /etc/pki/entitlement -type f -name "*-key.pem" | head -n 1)

if [[ ! -f "$ENT_CERT" || ! -f "$ENT_KEY" ]]; then
    echo "❌ Entitlement-certificaten niet gevonden. Systeem is mogelijk niet correct geregistreerd."
    exit 2
fi

CDN_URL="https://cdn.redhat.com/content/dist/rhel/$RHEL_VERSION/x86_64/baseos/os/"
curl -s -o /dev/null --cert "$ENT_CERT" --key "$ENT_KEY" --head "$CDN_URL"
CURL_RC=$?

if [[ $CURL_RC -eq 0 ]]; then
    echo "✅ CDN-verbinding succesvol: toegang tot BaseOS bevestigd."
elif [[ $CURL_RC -eq 60 ]]; then
    echo "❌ SSL-fout: certificaat niet vertrouwd. Controleer CA-trust en entitlement-certificaten."
    exit 60
elif [[ $CURL_RC -eq 22 ]]; then
    echo "❌ HTTP-fout: CDN weigert toegang (403 of 404). Controleer of je subscription toegang geeft tot RHEL $RHEL_VERSION BaseOS."
    exit 22
else
    echo "❌ Onbekende fout bij CDN-connectie (curl exit code $CURL_RC)."
    exit $CURL_RC
fi


# Set DNF variables for releasever and basearch
echo "$RHEL_VERSION" > /etc/dnf/vars/releasever
echo "x86_64" > /etc/dnf/vars/basearch
echo "production" > /etc/dnf/vars/rltype

# Clean and update DNF
echo "Cleaning and updating DNF cache..."
dnf clean all
dnf makecache
dnf install -y ca-certificates || true
dnf install -y rpm

echo "=== RHEL registration and repo setup complete. You can now install packages. ==="
#update1852-008

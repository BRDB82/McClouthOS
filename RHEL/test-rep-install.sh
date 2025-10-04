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
RHEL_VERSION=$(curl -s https://developers.redhat.com/products/rhel/download \
| grep -oE 'Red Hat Enterprise Linux [0-9]+' \
| grep -oE '[0-9]+' \
| sort -n | uniq | tail -1)
if [[ -z "$RHEL_VERSION" ]]; then
    echo "Could not detect RHEL version automatically."
    exit 1
fi
echo "Detected RHEL version: $RHEL_VERSION"

# Ensure repo directories exist
mkdir -p /etc/yum.repos.d

if [[ -z "$RHEL_VERSION" ]]; then
  echo "❌ Kon RHEL versie niet detecteren."
  exit 1
fi

echo "✅ Gedetecteerde RHEL versie: $RHEL_VERSION"

ENT_CERT=$(find /etc/pki/entitlement -type f -name "*.pem" ! -name "*-key.pem" | head -n 1)
ENT_KEY=$(find /etc/pki/entitlement -type f -name "*-key.pem" | head -n 1)

curl --cacert /etc/pki/tls/certs/ca-bundle.crt \
     --cert "$ENT_CERT" \
     --key "$ENT_KEY" \
     https://cdn.redhat.com/content/dist/rhel/10/x86_64/baseos/os/Packages/

# Check of systeem al geregistreerd is
if subscription-manager status 2>/dev/null | grep -q "Overall Status: Registered"; then
  echo "✅ Systeem is al geregistreerd."
else
  echo "🔐 Voer Red Hat accountgegevens in om te registreren..."
  read -p "Gebruikersnaam: " RHEL_USER
  read -s -p "Wachtwoord: " RHEL_PASS
  echo

  echo "📡 Registreren bij Red Hat..."
  output=$(subscription-manager register --username="$RHEL_USER" --password="$RHEL_PASS" 2>&1) && rc=$? || rc=$?
  echo "$output"

  if [[ $rc -ne 0 ]]; then
    echo "❌ Registratie mislukt. Controleer je account of netwerk."
    exit $rc
  fi

  echo "✅ Registratie geslaagd."
  unset RHEL_USER
  unset RHEL_PASS
fi

echo "📦 Repo activeren: rhel-$RHEL_VERSION-for-x86_64-baseos-rpms"
subscription-manager repos --enable="rhel-$RHEL_VERSION-for-x86_64-baseos-rpms"

# Entitlement-certificaten ophalen
ENT_CERT=$(find /etc/pki/entitlement -type f -name "*.pem" ! -name "*-key.pem" | head -n 1)
ENT_KEY=$(find /etc/pki/entitlement -type f -name "*-key.pem" | head -n 1)

if [[ ! -f "$ENT_CERT" || ! -f "$ENT_KEY" ]]; then
  echo "❌ Entitlement-certificaten niet gevonden. Registratie is mogelijk mislukt."
  exit 2
fi

# CDN-connectie testen
echo "🌐 Test toegang tot Red Hat CDN voor BaseOS..."
CDN_URL="https://cdn.redhat.com/content/dist/rhel/$RHEL_VERSION/x86_64/baseos/os/"
curl -s -o /dev/null --cert "$ENT_CERT" --key "$ENT_KEY" --head "$CDN_URL"
CURL_RC=$?

if [[ $CURL_RC -eq 0 ]]; then
  echo "✅ CDN-verbinding succesvol: toegang tot BaseOS bevestigd."
elif [[ $CURL_RC -eq 60 ]]; then
  echo "❌ SSL-fout: certificaat niet vertrouwd. Controleer CA-trust en entitlement-certificaten."
  exit 60
elif [[ $CURL_RC -eq 22 ]]; then
  echo "❌ HTTP-fout: CDN weigert toegang (403 of 404). Subscription biedt mogelijk geen toegang tot RHEL $RHEL_VERSION BaseOS."
  exit 22
else
  echo "❌ Onbekende fout bij CDN-connectie (curl exit code $CURL_RC)."
  exit $CURL_RC
fi

echo "🎯 RHEL registratie en repo-activatie voltooid. Je systeem is klaar voor installatie."

# Clean and update DNF
echo "Cleaning and updating DNF cache..."
dnf clean all
dnf makecache
dnf install -y ca-certificates || true
dnf install -y rpm

echo "=== RHEL registration and repo setup complete. You can now install packages. ==="
#update1852-012

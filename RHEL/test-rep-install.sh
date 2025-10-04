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
 
# Get latest RHEL version from Red Hat's CDN or developer site (for later version)

# Ensure repo directories exist
mkdir -p /etc/yum.repos.d

# Check if we have registered system
if ! subscription-manager status 2>/dev/null | grep -q "Overall Status: Registered"; then
  read -p "CDN Username: " RHEL_USER
  read -s -p "CDN Password: " RHEL_PASS
  echo

  echo "📡 Registreren bij Red Hat..."
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

# Clean and update DNF
echo "Cleaning and updating DNF cache..."
dnf --releasever=10 clean all
dnf -releasever=10 makecache
dnf -releasever=10 install -y ca-certificates || true
dnf -releasever=10 install -y rpm

echo "=== RHEL registration and repo setup complete. You can now install packages. ==="
#update1852-013

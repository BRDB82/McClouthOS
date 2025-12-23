#!/bin/bash
shopt -s extglob
source "/usr/bin/dnfcommon"

hostcache=0
copyrepolist=1
dnf_args=()
dnf_group_args=()
setopt_arg=()
dnfmode="install"
copyconf=0
dnf_config="/etc/dnf/dnf.conf"

usage() {
  cat <<EOF
usage: ${0##*/} [options] root [packages...]

  Options:
    -C <config>    Use an alternate config file for dnf
    -c             Use the package cache on the host, rather than the target
    -D             Skip dnf dependency checks
    -i             Prompt for package confirmation when needed (run interactively)
    -M             Avoid copying the host's repolist to the target
    -P             Copy the host's dnf config to the target

    -h             Print this help message

pacstrap installs packages to the specified new root directory. If no packages
are given, pacstrap defaults to the "base" group.

EOF
}

dnfstrap() {
  (( EUID == 0 )) || die 'This script must be run with root privileges'

  # create obligatory directories
  msg 'Creating install root at %s' "$newroot"
  # shellcheck disable=SC2174 # permissions are perfectly fine here
  mkdir -m 0755 -p "$newroot"/var/{cache/dnf,lib/rpm,log} "$newroot"/{dev,run,etc/yum.repos.d}
  # shellcheck disable=SC2174 # permissions are perfectly fine here
  mkdir -m 1777 -p "$newroot"/tmp
  # shellcheck disable=SC2174 # permissions are perfectly fine here
  mkdir -m 0555 -p "$newroot"/{sys,proc}

  # mount API filesystems
  $setup "$newroot" || die "failed to setup chroot %s" "$newroot"

  # If no arguments are passed after root, default to @core
  (( $# == 0 )) && set -- @core

  # Filter group targets and regular packages
  for arg in "$@"; do
    if [[ "$arg" == --* || "$arg" == -* ]]; then
      continue
    elif [[ "$arg" == @* ]]; then
      dnf_group_args+=("${arg#@}")
    else
      dnf_args+=("$arg")
    fi
  done

  printf 'dnf_group_args: [%s]\n' "${dnf_group_args[@]}"
  printf 'dnf_args: [%s]\n' "${dnf_args[@]}"
  
  if (( copyrepolist )); then
    # if we are on RHEL (true-RHEL) this can never work, so it that case we should make sure that we 
    # have subscription-manager installed at least.
    #if [ -f /etc/redhat-release ] && grep -q '^Red Hat Enterprise Linux' /etc/redhat-release && [ -d /etc/pki/entitlement ]; then
    #  echo ""
    #else
    #  # install the host's repo definitions onto the new root
    # Set up necessary directories in the target root
    mkdir -p "$newroot/etc/pki/consumer"
    mkdir -p "$newroot/etc/yum.repos.d"
    
    # Create symlinks from the target root to the host's authenticated files
    ln -s /etc/pki/consumer/ca.pem "$newroot/etc/pki/consumer/ca.pem"
    ln -s /etc/pki/consumer/cert.pem "$newroot/etc/pki/consumer/cert.pem"
    ln -s /etc/pki/consumer/key.pem "$newroot/etc/pki/consumer/key.pem"
    ln -s /etc/yum.repos.d/redhat.repo "$newroot/etc/yum.repos.d/redhat.repo"
    mkdir -p /mnt/etc/dnf/vars
    echo "10" > /mnt/etc/dnf/vars/releasever
    echo "production" > /mnt/etc/dnf/vars/rltype
    echo "x86_64" > /mnt/etc/dnf/vars/basearch
    #fi
  fi

  if (( copyconf )); then
    cp -a "$dnf_config" "$newroot/etc/dnf/dnf.conf"
  fi

  dnf --installroot="$newroot" --setopt=reposdir=/etc/yum.repos.d clean all
  dnf --installroot="$newroot" --setopt=reposdir=/etc/yum.repos.d makecache

  # First install groups inside chroot
  for group in "${dnf_group_args[@]}"; do
    msg 'Installing group "%s" inside installroot' "$group"
    if ! dnf --installroot="$newroot" \
      -c /etc/dnf/dnf.conf \
      --disableplugin=subscription-manager \
      --setopt=reposdir=/etc/yum.repos.d \
      --setopt=persistdir=/var/cache/dnf \
      --setopt=install_weak_deps=False \
      --setopt=group_package_types=mandatory \
      --setopt=timeout=300 \
      --setopt=max_parallel_downloads=1 \
      --setopt=retries=10 \
      group install "$group" -y; then
      die 'Failed to install group "%s"' "$group"
    fi
  done

  # Then install regular packages into installroot
  if (( ${#dnf_args[@]} )); then
    msg 'Installing "%s" inside installroot' "${dnf_args[@]}"
    if ! dnf --installroot="$newroot" \
      -c /etc/dnf/dnf.conf \
      --disableplugin=subscription-manager \
      --setopt=reposdir=/etc/yum.repos.d \
      --setopt=persistdir=/var/cache/dnf \
      --setopt=timeout=300 \
      --setopt=max_parallel_downloads=1 \
      --setopt=retries=10 \
      install -y "${dnf_args[@]}"; then
      die 'Failed to install packages to new root'
    fi
  fi
}

if [[ -z $1 || $1 = @(-h|--help) ]]; then
  usage
  exit $(( $# ? 0 : 1 ))
fi

OPTIND=1
while getopts ':C:cDiMPh' flag; do
  case $flag in
    C)
      dnf_config=$OPTARG
      ;;
    D)
      dnf_args+=(--setopt=skip_if_unavailable=True)
      ;;
    c)
      hostcache=1
      ;;
    i)
      dnf_args+=("--assumeyes")
      ;;
    M)
      copyrepolist=0
      ;;
    P)
      copyconf=1
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      die '%s: option requires an argument -- '\''%s'\''' "${0##*/}" "$OPTARG"
      ;;
    ?)
      die "%s: invalid option -- '\''%s'\'" "${0##*/}" "$OPTARG"
      ;;
  esac
done

shift $(( OPTIND - 1 ))

(( $# )) || die "No root directory specified"
newroot=$1
shift

[[ -d $newroot ]] || die "%s is not a directory" "$newroot"

# The following dnf_args is only for passing options, not for packages/groups
dnf_args+=(--config="$dnf_config" --installroot="$newroot")

if (( ! hostcache )); then
  dnf_args+=(--setopt=keepcache=False)
fi

if (( ! interactive )); then
  dnf_args+=(--assumeyes)
fi

setup=chroot_setup
dnfstrap "$@"
rm "$newroot/etc/pki/consumer/ca.pem" "$newroot/etc/pki/consumer/cert.pem" "$newroot/etc/pki/consumer/key.pem"
rm "$newroot/etc/yum.repos.d/redhat.repo"

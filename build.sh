#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Set install locations
mkdir -p /var/gnu
ln -s /var/gnu /gnu

# Set guix version
GUIX_VERSION=1.4.0
ARCH=$(uname -m)
GUIX_INST=guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz
GUIX_URL=https://ftpmirror.gnu.org/gnu/guix/${GUIX_INST}

export GNUPGHOME=/var/roothome/.gnupg
mkdir -p $GNUPGHOME

# Import GNU public key
wget 'https://sv.gnu.org/people/viewgpg.php?user_id=15145' \
      -qO - | gpg --import -

# Download installer and verify
cd /tmp
wget ${GUIX_URL}
wget ${GUIX_URL}.sig
gpg --verify ${GUIX_INST}.sig


# Extract and move guix store
tar --warning=no-timestamp -xf ${GUIX_INST}
mv var/guix /var/ && mv gnu /


# Make root guix config
mkdir -p ~root/.config/guix
ln -sf /var/guix/profiles/per-user/root/current-guix \
         ~root/.config/guix/current


# Set relevant env vars
GUIX_PROFILE="$(echo ~root)/.config/guix/current" ; \
  source $GUIX_PROFILE/etc/profile


# Create the group and user accounts for build users
groupadd --system guixbuild
for i in $(seq -w 1 10);
  do
    useradd -g guixbuild -G guixbuild           \
            -d /var/empty -s $(which nologin)   \
            -c "Guix build user $i" --system    \
            guixbuilder$i;
  done


# Run the daemon, and set it to automatically start on boot.
cp ~root/.config/guix/current/lib/systemd/system/gnu-store.mount \
     ~root/.config/guix/current/lib/systemd/system/guix-daemon.service \
     /etc/systemd/system/
systemctl enable gnu-store.mount guix-daemon


# # Arrange for guix gc to run periodically:
# cp ~root/.config/guix/current/lib/systemd/system/guix-gc.service \
#      ~root/.config/guix/current/lib/systemd/system/guix-gc.timer \
#      /etc/systemd/system/
# systemctl enable guix-gc.timer


# Make the guix command available to other users on the machine
mkdir -p /usr/bin
cd /usr/bin
ln -s /var/guix/profiles/per-user/root/current-guix/bin/guix


# Make guix Info manual available
mkdir -p /usr/share/info
cd /usr/share/info
for i in /var/guix/profiles/per-user/root/current-guix/share/info/* ;
  do ln -s $i ; done


# Authorise substitutes from ci.guix.gnu.org, bordeaux.guix.gnu.org
guix archive --authorize < \
     ~root/.config/guix/current/share/guix/ci.guix.gnu.org.pub
guix archive --authorize < \
     ~root/.config/guix/current/share/guix/bordeaux.guix.gnu.org.pub


# this installs a package from fedora repos
# dnf5 install -y tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

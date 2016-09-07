#!/usr/bin/env sh

# Guix bootstrap script.
# Copyright © 2016 University of Warwick
# License: GNU GPL version 3 or higher. See COPYING for details.

set -x
set -e

: ${GUIX_REPO_URI:=http://git.savannah.gnu.org/r/guix.git}
: ${GUIX_MIRROR:=ftp://alpha.gnu.org/gnu/guix}
: ${GUIX_BINARY_TARBALL:=guix-binary-0.11.0.x86_64-linux.tar.xz}
: ${GUIX_SIGNATURE_KEYS:=090B11993D9AEBB5}

# VMROOT is the mounted linux system.
VMROOT=$1
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT INT TERM HUP

curl -o ${TMPDIR}/${GUIX_BINARY_TARBALL} ${GUIX_MIRROR}/${GUIX_BINARY_TARBALL}

# XXX: This may fail due to incorrect permissions on ~/.gnupg.
#gpg --keyserver pgp.mit.edu --recv-keys ${GUIX_SIGNATURE_KEYS}
#curl -o ${TMPDIR}/${GUIX_BINARY_TARBALL}.sig ${GUIX_MIRROR}/${GUIX_BINARY_TARBALL}.sig
#gpg --verify ${GUIX_BINARY_TARBALL}.sig

tar --warning=no-timestamp -xf ${TMPDIR}/${GUIX_BINARY_TARBALL} -C ${TMPDIR}
mv ${TMPDIR}/var/guix ${VMROOT}/var && mv ${TMPDIR}/gnu ${VMROOT}/

# Make the guix command discoverable for users.
ln -s /var/guix/profiles/per-user/root/guix-profile/bin/guix \
   ${VMROOT}/usr/local/bin/guix

# Authorize hydra.gnu.org to provide substitutes.
chroot ${VMROOT} /usr/local/bin/guix archive --authorize < \
       ${VMROOT}/var/guix/profiles/per-user/root/guix-profile/share/guix/hydra.gnu.org.pub

# Create guix build users.
groupadd --root ${VMROOT} --system guixbuild
for i in `seq -w 1 10`; do
    useradd -g guixbuild -G guixbuild          \
            -d /var/empty -s /usr/sbin/nologin \
            -c "Guix build user $i" --system   \
            --root ${VMROOT} guixbuilder$i;
done

# Add guix daemon service from the root profile.
ln -s /var/guix/profiles/per-user/root/guix-profile/lib/systemd/system/guix-daemon.service \
   ${VMROOT}/etc/systemd/system/

# Enable it.
ln -s /etc/systemd/system/guix-daemon.service \
   ${VMROOT}/etc/systemd/system/multi-user.target.wants/

# Set up user profile on first login.
cat >> ${VMROOT}/etc/skel/.bash_profile <<'EOF'

GUIX_PROFILE="${HOME}/.guix-profile"
CLIMB_GUIX_REPO_DIR="${HOME}/climb-guix-recipes"

# Tell Guix where to find CLIMB recipes.
export GUIX_PACKAGE_PATH="${GUIX_PACKAGE_PATH}:${CLIMB_GUIX_REPO_DIR}"

# Set up GUIX_LOCPATH so guix libc can find locales.
export GUIX_LOCPATH="${HOME}/.guix-profile/lib/local"

# $GUIX_PROFILE does not exist until the user has installed something.
if [ -d "${GUIX_PROFILE}" ]; then
    source "${GUIX_PROFILE}/etc/profile"
else
    # Set up Guix PATH variable regardless so the user does not have
    # to log out and in again after installing their first program.
    export PATH="${HOME}/.guix-profile/bin:${HOME}/.guix-profile/sbin:${PATH}"
fi

# You can safely delete everything below.
# This prepares the user account for first login.
if [ ! -e "${HOME}/.config/guix/latest" ]; then
    CLIMB_GUIX_REPO_URL="https://github.com/MRC-CLIMB/guix-climb"

    echo
    echo "Welcome to the CLIMB Guix system."
    echo "Hang on while we prepare your system for first use..."
    echo
    echo 'Invoking `guix pull`..'
    /usr/local/bin/guix pull
    echo
    echo "Downloading CLIMB packages from ${CLIMB_GUIX_REPO_URL}..."
    git clone ${CLIMB_GUIX_REPO_URL} ${CLIMB_GUIX_REPO_DIR}
    echo
    echo 'Installing locales...'
    guix package -i glibc-utf8-locales # Use 'glibc-locales' for *all* locales.
    echo
    echo 'Installation complete!'
    echo
    echo 'Use `guix package` to search and install programs.'
    echo 'Run `guix pull` to refresh available packages and'
    echo '`guix package -u` to update locally installed programs.'
    echo 'You can undo an update with `guix package --roll-back`.'
    echo 'See `guix [command] --help` for more options.'
    echo
    echo "To refresh packages specific to CLIMB, change to the"
    echo -n "${CLIMB_GUIX_REPO_DIR} "
    echo 'directory and run `git pull`.'
    echo
    echo 'This installer will exit now. Bye!'
fi
EOF

# Keep the root guix up-to-date.
cat > ${VMROOT}/etc/cron.d/guix-root-update <<EOF
#
# This job updates root's guix every week to keep the daemon updated.
# It will need to be restarted by other means, though.
#

42 4 * * 0 root /usr/local/bin/guix pull && /usr/local/bin/guix package -u guix
EOF

# Make sure SSH host keys does not end up in the final image.
rm -f ${VMROOT}/etc/ssh/ssh_host_*

# Cloud SSH keys are not picked up for custom users. Instead we replace the default.
# First delete all indented lines after "default_user"; then inject our configuration.
sed -i ${VMROOT}/etc/cloud/cloud.cfg \
    -e '/default_user:/,/^   [a-zA-Z#]/ {//!d}' \
    -e '/default_user:/ a\     name: climb\
     gecos: Default user\
     lock_passwd: True\
     groups: [adm, audio, cdrom, dialout, floppy, video, plugdev, dip]\
     sudo: ["ALL=(ALL) NOPASSWD:ALL"]\
     shell: /bin/bash'

exit 0

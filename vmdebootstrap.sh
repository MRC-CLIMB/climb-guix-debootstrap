#!/usr/bin/env sh

: ${ARCH:=amd64}
: ${DISTRIBUTION=jessie}
: ${MIRROR:=http://mirror.ox.ac.uk/debian}
: ${CUSTOMIZE_SCRIPT:=./guix-bootstrap.sh}
: ${IMAGE_NAME:=climb-guix-vm.img}
: ${IMAGE_SIZE:=2000000000} # 2GB
: ${PACKAGE_LIST:=openssh-server,sudo,cloud-init,cloud-initramfs-growroot,\
qemu-guest-agent,curl,git}

sudo vmdebootstrap --verbose --enable-dhcp --grub --sparse --arch=${ARCH} \
     --distribution=${DISTRIBUTION} --serial-console --configure-apt \
     --mirror=${MIRROR} --customize=${CUSTOMIZE_SCRIPT} --image=${IMAGE_NAME} \
     --package=${PACKAGE_LIST} --size=${IMAGE_SIZE} --log=stderr

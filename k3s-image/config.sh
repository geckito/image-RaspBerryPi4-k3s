#!/bin/bash
# vim: sw=4 et
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : operating systems
#               :
#               :
# STATUS        : BETA
#----------------
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

set -e

echo "Download and execute k3s installation script"
echo "WARNING: This requires an unsecured KVM, run pbuild using    --vm-network    switch!"
bash /root/k3s.sh || exit 1

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Activate services
#--------------------------------------
#suseInsertService sshd
suseInsertService boot.device-mapper
suseInsertService chronyd
suseRemoveService avahi-dnsconfd
suseRemoveService avahi-daemon
suseInsertService geckito-setup

if [ -x /usr/bin/cloud-init ]; then
    # Found cloud-init (probably for dracut firstboot), enable it
    suseInsertService cloud-init-local
    suseInsertService cloud-init
    suseInsertService cloud-config
    suseInsertService cloud-final
fi

#======================================
# Add missing gpg keys to rpm
#--------------------------------------
suseImportBuildKey

#======================================
# Set sensible defaults
#--------------------------------------

baseUpdateSysConfig /etc/sysconfig/clock HWCLOCK "-u"
baseUpdateSysConfig /etc/sysconfig/clock TIMEZONE UTC
echo 'DEFAULT_TIMEZONE="UTC"' >> /etc/sysconfig/clock
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_SET_HOSTNAME no
baseUpdateSysConfig /etc/sysconfig/network/dhcp WRITE_HOSTNAME_TO_HOSTS no

#==========================================
# remove unneeded kernel files
#------------------------------------------
# Stripkernel renames the image which breaks
# 2nd boot
# suseStripKernel

#==========================================
# dirs needed by kiwi for subvolumes
#------------------------------------------
mkdir -p /var/lib/mailman /var/lib/mariadb /var/lib/mysql /var/lib/named /var/lib/pgsql /var/lib/libvirt/images

#==========================================
# remove package docs
#------------------------------------------
rm -rf /usr/share/doc/packages/*
rm -rf /usr/share/doc/manual/*
rm -rf /opt/kde*

if test -e /etc/vimrc && ! rpmqpack | grep -q vim-enhanced; then
    #======================================
    # only basic version of vim is
    # installed; no syntax highlighting
    #--------------------------------------
    sed -i -e's/^syntax on/" syntax on/' /etc/vimrc
fi

#======================================
# Import GPG Key
#
t=$(mktemp)
cat - <<EOF > $t
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2.0.15 (GNU/Linux)

mQENBEkUTD8BCADWLy5d5IpJedHQQSXkC1VK/oAZlJEeBVpSZjMCn8LiHaI9Wq3G
3Vp6wvsP1b3kssJGzVFNctdXt5tjvOLxvrEfRJuGfqHTKILByqLzkeyWawbFNfSQ
93/8OunfSTXC1Sx3hgsNXQuOrNVKrDAQUqT620/jj94xNIg09bLSxsjN6EeTvyiO
mtE9H1J03o9tY6meNL/gcQhxBvwuo205np0JojYBP0pOfN8l9hnIOLkA0yu4ZXig
oKOVmf4iTjX4NImIWldT+UaWTO18NWcCrujtgHueytwYLBNV5N0oJIP2VYuLZfSD
VYuPllv7c6O2UEOXJsdbQaVuzU1HLocDyipnABEBAAG0NG9wZW5TVVNFIFByb2pl
Y3QgU2lnbmluZyBLZXkgPG9wZW5zdXNlQG9wZW5zdXNlLm9yZz6JATwEEwECACYC
GwMGCwkIBwMCBBUCCAMEFgIDAQIeAQIXgAUCU2dN1AUJHR8ElQAKCRC4iy/UPb3C
hGQrB/9teCZ3Nt8vHE0SC5NmYMAE1Spcjkzx6M4r4C70AVTMEQh/8BvgmwkKP/qI
CWo2vC1hMXRgLg/TnTtFDq7kW+mHsCXmf5OLh2qOWCKi55Vitlf6bmH7n+h34Sha
Ei8gAObSpZSF8BzPGl6v0QmEaGKM3O1oUbbB3Z8i6w21CTg7dbU5vGR8Yhi9rNtr
hqrPS+q2yftjNbsODagaOUb85ESfQGx/LqoMePD+7MqGpAXjKMZqsEDP0TbxTwSk
4UKnF4zFCYHPLK3y/hSH5SEJwwPY11l6JGdC1Ue8Zzaj7f//axUs/hTC0UZaEE+a
5v4gbqOcigKaFs9Lc3Bj8b/lE10Y
=i2TA
-----END PGP PUBLIC KEY BLOCK-----
EOF
rpm --import $t
rm -f $t

#======================================
# prepare for setting root pw, timezone
#--------------------------------------
echo ** "reset machine settings"
rm /etc/machine-id
rm /etc/localtime
rm /var/lib/zypp/AnonymousUniqueId
rm /var/lib/systemd/random-seed


#======================================
# Bring up eth device automatically
#--------------------------------------
cat > /etc/sysconfig/network/ifcfg-eth0 <<-EOF
BOOTPROTO='dhcp'
MTU=''
REMOTE_IPADDR=''
STARTMODE='onboot'
EOF

#======================================
# Configure chronyd
#--------------------------------------

# tell e2fsck to ignore the time differences
cat > /etc/e2fsck.conf <<EOF
[options]
broken_system_clock=true
EOF

# /etc/chronyd.conf has already one openSUSE ntp pool
# for i in 0 1 2 3; do
#     echo "server $i.opensuse.pool.ntp.org iburst" >> /etc/chronyd.conf
# done

#======================================
# Trigger {jeos,yast2}-firstboot on first boot
# XXX It breaks more than it helps for now, just disable it
#--------------------------------------
# if [ -e /usr/lib/systemd/system/jeos-firstboot.service ]; then
#     touch /var/lib/YaST2/reconfig_system
#     suseInsertService jeos-firstboot
# fi

#======================================
# Disable systemd-firstboot
#--------------------------------------
# While it's a good idea to adapt the image according to user's preferences,
# people seem to want to run headless systems, so stalling the boot is a
# really bad idea. Disable firstboot for now ... (boo#1020019)
# rm -f /usr/lib/systemd/system/systemd-firstboot.service
rm -f /usr/lib/systemd/system/sysinit.target.wants/systemd-firstboot.service


#======================================
# Latest openssh disables root login by default
# Re-enable it as we do not use 1st boot for now,
# so root is the only account by default
#--------------------------------------

echo -e "\n# Allow root login on ssh\nPermitRootLogin yes" >> /etc/ssh/sshd_config

#======================================
# Load panel-tfp410 before omapdrm
#---
if [[ "$kiwi_iname" == *"-beagle" || "$kiwi_iname" == *"-panda" ]]; then
    cat > /etc/modprobe.d/50-omapdrm.conf <<EOF
# Ensure that panel-tfp410 is loaded before omapdrm
softdep omapdrm pre: panel-tfp410
EOF
fi

#======================================
# Load cros-ec-keyb (on board keyboard), tune touchpad 
# and map function keys for chromebook (snow)
#---
if [[ "$kiwi_iname" == *"-chromebook" ]]; then
    cat > /etc/modules-load.d/cros-ec-keyb.conf <<EOF
# Load cros-ec-keyb (on board keyboard)
cros-ec-keyb
EOF

    cat > /etc/X11/xorg.conf.d/50-touchpad.conf << EOF
Section "InputClass"
	Identifier "touchpad"
	MatchIsTouchpad "on"
	Option "FingerHigh" "5"
	Option "FingerLow" "5"
EndSection
EOF

# FIXME: This config will be lost once Xmodmap package will be updated
    cat > /etc/X11/Xmodmap << EOF
! Map the Chrombook function keys
keycode 67 = XF86Back F1 F1 F1 F1 XF86Switch_VT_1
keycode 68 = XF86Forward F2 F2 F2 F2 XF86Switch_VT_2
keycode 69 = XF86Refresh F3 F3 F3 F3 XF86Switch_VT_3
!keycode 70 =  F4 F4 XF86Switch_VT_4
keycode 71 = XF86Display F5 F5 F5 F5 XF86Switch_VT_5
keycode 72 = XF86MonBrightnessDown F6 F6 F6 F6 XF86Switch_VT_6
keycode 73 = XF86MonBrightnessUp F7 F7 F7 F7 XF86Switch_VT_7
keycode 74 = XF86AudioMute F8 F8 F8 F8 XF86Switch_VT_8
keycode 75 = XF86AudioLowerVolume F9 F9 F9 F9 XF86Switch_VT_9
keycode 76 = XF86AudioRaiseVolume F10 F10 F10 F10 XF86Switch_VT_10
EOF

fi

#======================================
# Import trusted keys
#--------------------------------------
for i in /usr/lib/rpm/gnupg/keys/gpg-pubkey*asc; do
    # importing can fail if it already exists
    rpm --import $i || true
done


#======================================
# Initrd fixes (for 2nd boot only. 1st boot modules are handled by *.kiwi files)
#======================================

echo 'add_drivers+=" sdhci-iproc bcm2835-sdhost bcm2835_dma mmc_block dwc2 drm vc4"' > /etc/dracut.conf.d/raspberrypi_modules.conf
echo 'add_drivers+=" gpio-regulator virtio_gpu scsi_mod "' > /etc/dracut.conf.d/efi_modules.conf

#======================================
# Umount kernel filesystems
#--------------------------------------
#baseCleanMount

exit 0

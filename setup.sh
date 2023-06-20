#!/bin/sh

# Usage: setup.sh /dev/disk /dev/espdisk /dev/rootdisk hostname username

curl -s https://raw.githubusercontent.com/eoli3n/archiso-zfs/master/init | bash -s -- -v

parted --script $1 -- mklabel gpt mkpart ESP fat32 0% 2GiB mkpart Zeebs 2GiB 100% set 1 esp on

modprobe zfs

zpool create -f -o ashift=12	\
	-O acltype=posixacl	\
	-O relatime=on		\
	-O xattr=sa		\
	-O dnodesize=auto	\
	-O normalization=formD	\
	-O mountpoint=none	\
	-O canmount=off		\
	-O devices=off		\
	-O compression=lz4	\
	-R /mnt			\
	zroot $3

zfs create -o mountpoint=none zroot/data
zfs create -o mountpoint=none zroot/ROOT

zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/default
zfs create -o mountpoint=/home zroot/data/home

zfs create -o mountpoint=/var -o canmount=off		zroot/var
zfs create						zroot/var/log
zfs create -o mountpoint=/var/lib -o canmount=off	zroot/var/lib
zfs create						zroot/var/lib/libvirt

zpool export zroot
zpool import -d /dev/disk/by-id -R /mnt zroot -N

zfs mount zroot/ROOT/default
zfs mount -a

zpool set bootfs=zroot/ROOT/default zroot
zpool set cachefile=/etc/zfs/zpool.cache zroot

mkfs.fat $2
mount --mkdir $2 /mnt/boot/efi
mkdir /mnt/boot/efi/EFI

echo "Server = https://mirror.fcix.net/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
pacman -Sy

pacstrap -K /mnt base base-devel kmod linux linux-headers git dtc linux-firmware amd-ucode man-db man-pages texinfo dhcpcd neovim nano curl efibootmgr sudo zfs-utils

genfstab -U -p /mnt > /mnt/etc/fstab
nano /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
arch-chroot /mnt hwclock --systohc

nano /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo $4 > /mnt/etc/hostname


arch-chroot /mnt useradd -m -G wheel,adm,games,log,rfkill,ftp,systemd-journal,uucp,http,sys $5
arch-chroot /mnt passwd $5

cp /mnt/etc/sudoers /tmp
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /mnt/etc/sudoers

arch-chroot /mnt pacman -Syu
arch-chroot /mnt su $5 -c "bash -c \"curl 'https://aur.archlinux.org/cgit/aur.git/snapshot/zfs-linux.tar.gz' -o /home/aled/zfs-linux.tar.gz\""
arch-chroot /mnt su $5 -c "bash -c \"cd /home/aled/ && tar zxf zfs-linux.tar.gz && cd zfs-linux && makepkg -si\""

nano /mnt/etc/mkinitcpio.conf

arch-chroot /mnt su $5 -c "bash -c \"curl 'https://aur.archlinux.org/cgit/aur.git/snapshot/perl-boolean.tar.gz' -o /home/aled/perl-boolean.tar.gz\""
arch-chroot /mnt su $5 -c "bash -c \"cd /home/aled && tar zxf perl-boolean.tar.gz && cd perl-boolean && makepkg -si\""

arch-chroot /mnt su $5 -c "bash -c \"curl 'https://aur.archlinux.org/cgit/aur.git/snapshot/zfsbootmenu.tar.gz' -o /home/aled/zfsbootmenu.tar.gz\""
arch-chroot /mnt su $5 -c "bash -c \"cd /home/aled && tar zxf zfsbootmenu.tar.gz && cd zfsbootmenu && makepkg -si\""

nano /mnt/etc/zfsbootmenu/config.yaml

cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache

arch-chroot /mnt generate-zbm
arch-chroot /mnt zfs set org.zfsbootmenu:commandline="rw" zroot/ROOT/default
arch-chroot /mnt efibootmgr -c -d $1 -p 1 -L ZFBootMenu -l '\EFI\zbm\vmlinux-linux.EFI'


arch-chroot /mnt zpool set cachefile=/etc/zfs/zpool.cache zroot
arch-chroot /mnt systemctl enable zfs.target
arch-chroot /mnt systemctl enable zfs-import-cache.service zfs-mount.service zfs-import.target

arch-chroot /mnt zgenhostid $(hostid)
arch-chroot /mnt mkinitcpio -P

cp /tmp/sudoers /mnt/etc/sudoers
chmod 600 /mnt/etc/sudoers
arch-chroot /mnt passwd
arch-chroot /mnt

umount /mnt/boot/efi
zfs umount -a

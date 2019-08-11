#!/bin/bash -ex

_() {
	set -xeuo pipefail
	loadkeys fr

	SWAP="6GiB"
	if [ -d /sys/firmware/efi ]; then
		parted -s /dev/sda mklabel gpt
		parted -s -a optimal /dev/sda mkpart primary fat32 1MiB 550MiB
		parted -s -a optimal /dev/sda set 1 esp on
		parted -s -a optimal /dev/sda mkpart primary linux-swap 550MiB "$SWAP"
		parted -s -a optimal /dev/sda mkpart primary ext4 "$SWAP" 100%
	else
		parted -s /dev/sda mklabel msdos
		parted -s -a optimal /dev/sda mkpart primary ext3 1MiB 550MiB
		parted -s -a optimal /dev/sda set 1 boot on
		parted -s -a optimal /dev/sda mkpart primary linux-swap 550MiB "$SWAP"
		parted -s -a optimal /dev/sda mkpart primary ext4 "$SWAP" 100%
	fi

	mkfs.ext4 -F /dev/sda3
	mkfs.fat -F32 /dev/sda1

	mkswap /dev/sda2
	swapon /dev/sda2

	mount /dev/sda3 /mnt
	mkdir /mnt/{boot,home}

	if [ -d /sys/firmware/efi ]; then
		mkdir /mnt/boot/efi
		mount /dev/sda1 /mnt/boot/efi
	else
		mount /dev/sda1 /mnt/boot
	fi

	echo 'Server = http://archlinux.mirrors.ovh.net/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

	pacstrap /mnt base base-devel pacman-contrib
	pacstrap /mnt git zip unzip p7zip vim mc alsa-utils syslog-ng mtools dosfstools lsb-release ntfs-3g exfat-utils bash-completion zsh sudo tmux htop iftop nmap curl wget autossh

	genfstab -U -p /mnt >> /mnt/etc/fstab

	pacstrap /mnt grub os-prober
	if [ -d /sys/firmware/efi ]; then
		pacstrap /mnt efibootmgr
	fi

	cat <<EOF >/mnt/etc/vconsole.conf
KEYMAP=fr-latin9
FONT=eurlatgr
EOF

	cat <<EOF >/mnt/etc/locale.conf
LANG=en_US.UTF-8
LC_COLLATE=C
EOF

	echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen

	arch-chroot /mnt locale-gen

	arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

	arch-chroot /mnt hwclock --systohc --utc

	arch-chroot /mnt mkinitcpio -p linux

	if [ -d /sys/firmware/efi ]; then
		arch-chroot /mnt sh -c 'mount | grep efivars &> /dev/null || mount -t efivarfs efivarfs /sys/firmware/efi/efivars'
		arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck

		arch-chroot /mnt mkdir /boot/efi/EFI/boot
		arch-chroot /mnt cp /boot/efi/EFI/arch_grub/grubx64.efi /boot/efi/EFI/boot/bootx64.efi
	else
		arch-chroot /mnt grub-install --no-floppy --recheck /dev/sda
	fi


	arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

	arch-chroot /mnt passwd -d root

	arch-chroot /mnt pacman --noconfirm -Syy networkmanager
	arch-chroot /mnt systemctl enable NetworkManager

	arch-chroot /mnt pacman --noconfirm -Syy ntp cronie

	arch-chroot /mnt pacman --noconfirm -Syy gst-plugins-{base,good,bad,ugly} gst-libav

	arch-chroot /mnt pacman --noconfirm -Syy xorg-{server,xinit,apps} xf86-input-{mouse,keyboard} xdg-user-dirs

	arch-chroot /mnt pacman --noconfirm -Syy xorg-{server,xinit,apps} xf86-input-{mouse,keyboard} xdg-user-dirs

	#touchpad
	arch-chroot /mnt pacman --noconfirm -Syy xf86-input-libinput

	arch-chroot /mnt pacman --noconfirm -Syy xf86-video-ati
	arch-chroot /mnt pacman --noconfirm -Syy xf86-video-intel
	arch-chroot /mnt pacman --noconfirm -Syy xf86-video-nouveau
	arch-chroot /mnt pacman --noconfirm -Syy xf86-video-vesa

	arch-chroot /mnt pacman --noconfirm -Syy ttf-{bitstream-vera,liberation,dejavu} freetype2

	arch-chroot /mnt pacman --noconfirm -Syy gimp gimp-help-fr python-pyqt5

	#printers
	arch-chroot /mnt pacman --noconfirm -Syy cups hplip
	arch-chroot /mnt pacman --noconfirm -Syy foomatic-{db,db-ppds,db-gutenprint-ppds,db-nonfree,db-nonfree-ppds} gutenprint

	arch-chroot /mnt pacman --noconfirm -Syy libreoffice-still hunspell hunspell-fr

	arch-chroot /mnt pacman --noconfirm -Syy firefox firefox-developer-edition chromium

	curl -k https://raw.githubusercontent.com/grml/grml-etc-core/master/etc/zsh/zshrc > /mnt/etc/skel/.zshrc

	chmod 700 /mnt/root
	cp /mnt/etc/skel/.zshrc /mnt/root/

	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /mnt/etc/sudoers

	IAM='marion'
	arch-chroot /mnt useradd -m -g wheel -c $IAM -s /bin/zsh $IAM
	arch-chroot /mnt passwd -d $IAM
	arch-chroot /mnt chmod 700 "/home/$IAM"

	#kde
	arch-chroot /mnt pacman --noconfirm -Syy plasma kde-applications digikam elisa packagekit-qt5
	#arch-chroot /mnt localectl set-x11-keymap fr
	arch-chroot /mnt systemctl enable sddm

	arch-chroot /mnt pacman --noconfirm -Syu

	cat <<EOF > /mnt/home/$IAM/yaourt.sh
cd

git clone https://aur.archlinux.org/package-query.git
cd package-query
makepkg -si --noconfirm
cd ..

git clone https://aur.archlinux.org/yaourt.git
cd yaourt
makepkg -si --noconfirm
cd ..

rm -rf package-query yaourt
EOF

	chmod 555 /mnt/home/$IAM/yaourt.sh
	arch-chroot /mnt sudo -u $IAM bash /home/$IAM/yaourt.sh

	arch-chroot /mnt sudo -u $IAM yaourt -Syua --noconfirm

	echo Install OK, You use arch btw
}

_ "$0" "$@"

archlinux-install-script
============

My custom script for unattended archlinux install.

Usage
=========

You can boot [archlinux ISO](https://www.archlinux.org/download/), and "curlbash" it :

	curl https://raw.githubusercontent.com/marionzz/archlinux-install-script/master/install.sh | bash

Features
=========

At the moment it's pretty basic, but enough for my every day use.

- Autodetects and supports both MBR and UEFI

Installed
=========

The syntax used in the script makes it easy to vim it at the last minute to remove unwanted parts

- KDE
- Firefox
- Cups (Printing)
- Nvidia/Ati/Virtualbox graphics
- Libreoffice
- Gimp

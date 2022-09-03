#!/bin/sh

# ##### UIFI,ENCRYPTED INSTALLATION OF ARCH LINUX ##### #

#### a) Install system apps 

	pacman --noconfirm --needed -Syyy
	pacman --noconfirm --needed -S xorg-server xorg-apps xorg-xinit xf86-input-libinput libinput xf86-input-evdev xf86-input-wacom
	sudo pacman --noconfirm --needed -S spectrwm xdo bash-completion git wget zip gzip unzip
	sudo pacman --noconfirm --needed -S bspwm sxhkd xdo libnotify dunst flameshot udevil thunar sxiv libreoffice

		# sound
	sudo pacman --noconfirm --needed -S pulseaudio pulseaudio-alsa pavucontrol alsa-utils alsa-plugins alsa-lib alsa-firmware pulsemixer hdmi-audio pulseaudio-equalizer pulseaudio-jack
	
		# bluetooth
	sudo pacman -S --noconfirm --needed bluez-libs 
		# printers
	sudo pacman --noconfirm --needed -S ghostscript gsfonts gutenprint gtk3-print-backends libcups hplip system-config-printer
		# fonts
	sudo pacman --noconfirm --needed -S adobe-source-sans-pro-fonts cantarell-fonts noto-fonts terminus-font ttf-bitstream-vera ttf-dejavu ttf-droid ttf-inconsolata ttf-liberation ttf-roboto ttf-ubuntu-font-family tamsyn-font

	sudo pacman -noconfirm --needed -S alacritty firefox dmenu

	sudo pacman -noconfirm --needed -S lf vifm youtube-dl kodi feh htop iio-sensor-proxy inotify-tools man-db man-pages redshift conky

    # next
    sudo pacman -noconfirm --needed -S mypaint
#### b) Install yay (AUR package manager)

	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -si

#### c)

	yay -S betterlockscreen
	systemctl enable betterlockscreen@$USER


	sudo pacman -S android-tools android-udev
	yay -S scrcpy sndcpy-bin

	sudo pacman -S sysstats

	sudo pacman -S zsh zsh-completions zsh-syntax-highlighting

	chsh -s /usr/bin/zsh

	#Settings
		#Touchscreen
		echo "MOZ_USE_XINPUT2 DEFAULT=1" | sudo tee -a /etc/security/pam_env.conf
		#Touchpad
		sudo pacman -S xf86-input-synaptics
		cp $HOME/Settings/70-synaptics.conf /etc/X11/xorg.conf.d/70-synaptics.conf
		#Polkit
		sudo pacman -S polkit lxsession 
		#Network
		sudo pacman -S network-manager-applet
		yay -S networkmanager-dmenu-git
		cp $HOME/Settings/50-org.freedesktop.NetworkManager.rules /etc/polkit-1/rules.d/50-org.freedesktop.NetworkManager.rules
		#Kodi
		sudo pacman -S kodi
		cp Settings/AppConfigs/.kodi $HOME/
		sudo cp Settings/AppConfigs/.kodi/addons/skin.estuary/xml/DialogButtonMenu.xml /usr/share/kodi/addons/skin.estuary/xml/DialogButtonMenu.xml

		#Multilib repository
		sudo cp Settings/pacman.conf /etc/pacman.conf

		#card reader
		sudo pacman -S ccid libnfc acsccid pcsclite pcsc-tools
		sudo systemctl enable pcscd
		sudo systemctl start pcscd

#### d) Restart the machine
	
	reboot

# ##### --------------------------------------------- ##### #

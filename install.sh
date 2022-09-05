function helpStart(){
echo "
#Definitions
\$wifi_name,\$disk

### Better font size
setfont ter-132n

### Wifi connection
ip a
iwctl
	station wla0 connect \$wifi_name
exit
ping archlinux.org
### Synchronize pacman pkgs
pacman -Sy
### Download git
git clone https://github.com/alphalinux10/installation.git
### Syncronize time protocol
timedatectl set-ntp true
### Partitioning
lsblk
gdisk \$disk
	n


	+300M
	ef00
	n




	w
	Y
lsblk
### Formating
mkfs.fat -F32 /dev/sda1
mkfs.btrfs /dev/sda2
### Mounting
mount /dev/sda2 /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
cd
umount /mnt
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=@ /dev/sda2 /mnt
mkdir /mnt/{boot,home}
mount -o noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=@home /dev/sda2 /mnt/home
mount /dev/sda1 /mnt/boot/
lsblk
########## install script ##########
./installation/install.sh --install
### Arch chroot
arch-chroot /mnt
########## arch-chroot script ##########
./installation/install.sh --arch-chroot
exit
umount -R /mnt
reboot

##### After restart
### Better font size
setfont ter-132n
### Change user & root passwd
passwd
passwd alpha
### Wifi connection
ip a
iwctl
	station wla0 connect \$wifi_name
exit
ping archlinux.org
########## post-install script ##########
"
}

function installSudoPacman(){
	for n in $(seq 1 $#); do
		sudo pacman --noconfirm --needed -S ${!n}
		if [[ "$?" == "1" ]];then echo "${!n}" >> install-error.tmp; fi
	done
}

function installPacman(){
	for n in $(seq 1 $#); do
		pacman --noconfirm --needed -S ${!n}
		if [[ "$?" == "1" ]];then echo "${!n}" >> install-error.tmp; fi
	done
}

function installParu(){
	for n in $(seq 1 $#); do
		paru --noconfirm --needed -S ${!n}
		if [[ "$?" == "1" ]];then echo "${!n}" >> installParu-error.tmp; fi
	done
}

function install() {
	# mirrorlist
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
        reflector -c Slovakia -c Czechia -a 6 --sort rate --save /etc/pacman.d/mirrorlist
	# pactrap
	if [[ $(lscpu | awk '/Model name:/ {print $3}') == "AMD" ]]; then
		pacstrap /mnt base linux linux-headers linux-lts linux-lts-headers linux-firmware vim git intel-ucode man-db man-pages texinfo
	else
		pacstrap /mnt base linux linux-headers linux-lts linux-lts-headers linux-firmware vim git amd-ucode man-db man-pages texinfo
	fi
	# generate fstab
	genfstab -U /mnt >> /mnt/etc/fstab
}


function archChroot() {
	#### 1) Time zone
		ln -sf /usr/share/zoneinfo/Europe/Bratislava /etc/localtime
        hwclock --systohc

        #### 2) Locale
		echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
		echo 'sk_SK.UTF-8 UTF-8' >> /etc/locale.gen
		locale-gen
		echo "LANG=en_US.UTF-8" >> /etc/locale.conf

        #### 3) Hostname & network configuration
		installPacman dmidecode 
		HOSTNAME="ALPHA-$(dmidecode -s system-version|sed"s/[[:space:]]/_/g")"
        echo $HOSTNAME > /etc/hostname
        echo "127.0.0.1         localhost" > /etc/hosts
        echo "::1               localhost" >> /etc/hosts
        echo "127.0.0.1         $HOSTNAME.localdomain           $HOSTNAME" >> /etc/hosts

        #### 5) Linux core packages & drivers & another needed packages
        ### Base
		installPacman base-devel git
        ### Drivers
		if [[ $(lspci | awk '/VGA/ {print $5}') == "Advanced" ]]; then
        	# amd
        	installPacman libgl mesa xf86-video-amdgpu mesa-libgl
		elif [[ $(lspci | awk '/VGA/ {print $5}') == "Intel" ]]; then
			# intel
        	installPacman xf86-video-intel libgl mesa intel-gmmlib intel-media-driver intel-media-sdk intel-tbb mesa-libgl 
		else
			# other
        	installPacman xf86-video-intel libgl mesa intel-ucode intel-gmmlib intel-media-driver intel-media-sdk intel-tbb nvidia nvidia-lts nvidia-libgl xf86-video-amdgpu xf86-video-nouveau xf86-video-ati xf86-video-vesa virtualbox-guest-utils virtualbox-guest-modules-arch mesa-libgl
		fi
		### Network
        installPacman networkmanager network-manager-applet wireless_tools wpa_supplicant dialog os-prober mtools dosfstools iwd
        systemctl enable NetworkManager.service
        ### Bluetooth
        installPacman bluez bluez-utils 
        systemctl enable bluetooth.service
		### Sound
		installPacman alsa-utils pipewire pipewire-docs pipewire-alsa pipewire-pulse pipewire-jack wireplumber qpwgraph
        systemctl enable pipewire-pulse.service
        ### Printing
        installPacman cups xdg-utils xdg-user-dirs ghostscript gsfonts gutenprint gtk3-print-backends libcups hplip system-config-printer 
		systemctl enable cups.service
		### Scanning
		installPacman sane ipp-usb sane-airscan simple-scan
		systemctl enable ipp-usb.service
		### Virt-manager
        installPacman virt-manager qemu-desktop libvirt edk2-ovmf dnsmasq iptables-nft
		systemctl enable libvirtd.service
		### System information
		installPacman usbutils hwinfo neofetch sysstats

		### Other
		installPacman bash-completion openssh rsync reflector acpi acpi_call acpid tlp bridge-utils vde2 openbsd-netcat ipset firewalld flatpak sof-firmware nss-mdns acpid ntfs-3g terminus-font avahi gvfs gvfs-smb nfs-utils inetutils dnsutils

	#### 6) Root password
		echo root:password | chpasswd

        #### 7) Create user
		useradd -m alpha
		echo alpha:password | chpasswd
		usermod -aG libvirt alpha

        #### 8) Sudo permitions of user
        pacman  --noconfirm --needed -S sudo
		echo "alpha ALL=(ALL) ALL" >> /etc/sudoers.d/alpha

        #### 9) Initramfs
		if [[ $(lspci | awk '/VGA/ {print $5}') == "Advanced" ]]; then
                	sed -i '/^MODULES/s/.*/MODULES=(btrfs amdgpu)/i' /etc/mkinitcpio.conf
		else
			sed -i '/^MODULES/s/.*/MODULES=(btrfs)/i' /etc/mkinitcpio.conf
		fi
		mkinitcpio -P
        
	##### 10) Boot loader
        installPacman grub efibootmgr
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
		grub-mkconfig -o /boot/grub/grub.cfg

        #### 11) Journal
        ###        sed -i '/Storage=auto/s/.*/Storage=volatile;/RuntimeMaxUse=/s/.*/RuntimeMaxUse=30M' /etc/systemd/journald.conf
}

function postInstall() {
	# Update mirrorlist
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	reflector -c Slovakia -c Czechia -a 10 --sort rate --save /etc/pacman.d/mirrorlist
	### Synchronize pacman pkgs
	sudo pacman --noconfirm --needed -Syy
	### Syncronize time protocol
	sudo timedatectl set-ntp true
	sudo hwclock --systohc

	#### a) Install system apps 

	### UPDATE
	sudo pacman --noconfirm --needed -Syu

	### AUR
	mkdir BuildApps
	cd BuildApps
	git clone https://aur.archlinux.org/paru-bin
	cd paru-bin
	makepkg -si
	cd

	### TIMESHIFT
	installParu timeshift timeshift-autosnap
	timeshift

	### ZRAMD
	installParu zramd
	sudo systemctl enable --now zramd.service
	lsblk

	### SDDM
	installSudoPacman sddm
	sudo systemctl enable --now sddm.service

	##Touchscreen
	if [[ $(lsusb | grep "Touch") != '' ]]; then
		echo "MOZ_USE_XINPUT2 DEFAULT=1" | sudo tee -a /etc/security/pam_env.conf
	fi
	#Touchpad
	installSudoPacman xf86-input-synaptics
	cp $HOME/installation/conf/70-synaptics.conf /etc/X11/xorg.conf.d/70-synaptics.conf

	mkdir -p ~/Programs
	# Programs
		## XORG
		installSudoPacman xorg-server xorg-apps xorg-xinit xf86-input-libinput libinput xf86-input-evdev xf86-input-wacom
		## Web Browsers
		installSudoPacman brave-bin firefox librewolf
		## Terminals
		installSudoPacman alacritty rxvt-unicode
		installParu st
		## WM
		installSudoPacman awesome dmenu
		# Editors
		installSudoPacman code
        		### neovim
        		cd Programs
			installSudoPacman cmake unzip ninja tree-sitter curl
        		git clone https://github.com/neovim/neovim.git
        		cd neovim
        		git checkout release-0.7
        		make CMAKE_BUILD_TYPE=Release
        		sudo make install
        		#git clone https://github.com/LunarVim/nvim-basic-ide.git ~/.config/nvim
        		cd ..
			installSudoPacman xsel wl-clipboard pip npm ripgrep
        		#pip install pynvim
        		#npm i -g neovim
        		### xdg-ninja
        		git clone https://github.com/b3nj5m1n/xdg-ninja.git
        		sudo pacman -S jq glow
		# Tools
		installSudoPacman xdo bash-completion git wget dunst udevil arandr youtube-dl htop iio-sensor-proxy inotify-tools redshift conky 
		## File Managers
			# xplr
			installSudoPacman xplr imv xdotool
			# thunar
			installSudoPacman thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman meld
			# nemo
    		installSudoPacman $(sudo pacman -Ss nemo | grep "community/" | awk '{print $1}' | sed "s<community/<<g" | tr '\n' ' ')
			# other
			installSudoPacman lf clifm

		## Docs
		installSudoPacman libreoffice onlyoffice-bin
		## ImageEditors
		installSudoPacman sxiv feh gimp inkscape blender
		## Image/Video capture
		installSudoPacman flameshot scrot simplescreenrecorder obs-studio
		## Video players
		installSudoPacman vlc mpv
		## Compression
		installSudoPacman zip gzip unzip
		## Fonts
		installSudoPacman awesome-terminal-fonts adobe-source-sans-pro-fonts bdf-unifont cantarell-fonts dina-font noto-fonts terminus-font ttf-bitstream-vera ttf-dejavu ttf-droid ttf-inconsolata ttf-liberation ttf-roboto ttf-ubuntu-font-family tamsyn-font ttf-croscore gnu-free-fonts ttf-ibm-plex ttf-linux-libertine tex-gyre-fonts ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-jetbrains-mono ttf-monofur inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome 
		## Themes
		installSudoPacman arc-gtk-theme arc-icon-theme 
		## Other
		installSudoPacman archlinux-wallpaper playerctl pacman-contrib

	#installSudoPacman xorg-server xorg-apps xorg-xinit xf86-input-libinput libinput xf86-input-evdev xf86-input-wacom
	#installSudoPacman arandr simplescreenrecorder arc-gtk-theme arc-icon-theme dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome awesome-terminal-fonts archlinux-wallpaper playerctl scrot obs-studio dunst pacman-contrib
    #sudo pacman -noconfirm --needed -S mypaint

	installSudoPacman android-tools android-udev scrcpy
	installParu sndcpy-bin 
		
		#Network
		paru -S networkmanager-dmenu-git

		#card reader
		sudo pacman -S ccid libnfc acsccid pcsclite pcsc-tools
		sudo systemctl enable pcscd

	sudo firewall-cmd --add-port=1025-65535/tcp --permanent
	sudo firewall-cmd --add-port=1025-65535/udp --permanent
	sudo firewall-cmd --reload

	#sudo pacman -S --noconfirm picom nitrogen lxappearance dmenu arandr simplescreenrecorder alsa-utils pulseaudio alsa-utils pulseaudio-alsa pavucontrol arc-gtk-theme arc-icon-theme dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome awesome-terminal-fonts archlinux-wallpaper playerctl scrot obs-studio dunst pacman-contrib

		systemctl enable sshd
		systemctl enable avahi-daemon
		systemctl enable tlp
		systemctl enable reflector.timer
		systemctl enable fstrim.timer
		systemctl enable libvirtd
		systemctl enable firewalld
		systemctl enable acpid
}

case "$1" in
	-h)
		helpStart
		;;
	--help)
		helpStart
		;;
    	--install)
        	install
		;;
    	--arch-chroot)
        	archChroot
        	;;
    	--post-install)
        	postInstall
        	;;
    	*)
        	# By default print output for bar
		echo "Error: Option doesn't exist"
        	;;
esac

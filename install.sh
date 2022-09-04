function help-start(){
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
### Download git
git clone https://github.com/alphalinux10/installation.git
### Synchronize pacman pkgs
pacman -Sy
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
### Arch chroot
arch-chroot /mnt
########## arch-chroot script ##########
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


function arch--chroot() {
	#### 1) Time zone
		ln -sf /usr/share/zoneinfo/Europe/Bratislava /etc/localtime
                hwclock --systohc

        #### 2) Locale
		echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
		echo 'sk_SK.UTF-8 UTF-8' >> /etc/locale.gen
		locale-gen
		echo "LANG=en_US.UTF-8" >> /etc/locale.conf

        #### 3) Hostname & network configuration
		HOSTNAME="ALPHA - $(dmidecode -s system-version)"
                echo $HOSTNAME > /etc/hostname
                echo "127.0.0.1         localhost" > /etc/hosts
                echo "::1               localhost" >> /etc/hosts
                echo "127.0.0.1         $HOSTNAME.localdomain           $HOSTNAME" >> /etc/hosts

        #### 5) Linux core packages & drivers & another needed packages
                ### Base
		pacman --noconfirm --needed -S base-devel git
                ### Drivers
                pacman --noconfirm --needed -S xf86-video-intel libgl mesa intel-ucode intel-gmmlib intel-media-driver intel-media-sdk intel-tbb nvidia nvidia-lts nvidia-libgl xf86-video-amdgpu xf86-video-nouveau xf86-video-ati xf86-video-vesa virtualbox-guest-utils virtualbox-guest-modules-arch mesa-libgl
		### Network
                pacman --noconfirm --needed -S networkmanager network-manager-applet wireless_tools wpa_supplicant dialog os-prober mtools dosfstools
                ### Bluetooth & Printing
                pacman --noconfirm --needed -S bluez bluez-utils pulseaudio-bluetooth cups xdg-utils xdg-user-dirs acpi hplip 
		### Sound
		pacman --noconfirm --needed -S alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber 
		### Other
		pacman --noconfirm --needed -S bash-completion openssh rsync reflector acpi acpi_call tlp virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid ntfs-3g terminus-font avahi gvfs gvfs-smb nfs-utils inetutils dnsutils

        #### 8) Enable network manager & bluetooth & printing
                systemctl enable NetworkManager
                systemctl enable bluetooth
		systemctl enable cups.service

	#### 9) Root password
		echo root:password | chpasswd

        #### 9) Create user
		useradd -m alpha
		echo alpha:password | chpasswd
		usermod -aG libvirt alpha

        #### 10) Sudo permitions of user
                pacman  --noconfirm --needed -S sudo
		echo "alpha ALL=(ALL) ALL" >> /etc/sudoers.d/alpha

        #### 7) Initramfs
		if [[ $(lspci | awk '/VGA/ {print $5}') == "Advanced" ]]; then
                	sed -i '/^MODULES/s/.*/MODULES=(btrfs amdgpu)/i' /etc/mkinitcpio.conf
		else
			sed -i '/^MODULES/s/.*/MODULES=(btrfs)/i' /etc/mkinitcpio.conf
		fi
		mkinitcpio -P
        
	##### 6) Boot loader
                pacman --noconfirm --needed -S grub efibootmgr
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
		grub-mkconfig -o /boot/grub/grub.cfg

        #### 11) Journal
        ###        sed -i '/Storage=auto/s/.*/Storage=volatile;/RuntimeMaxUse=/s/.*/RuntimeMaxUse=30M' /etc/systemd/journald.conf
}
function postinstall() {
	# Update mirrorlist
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	reflector -c Slovakia -c Czechia -a 10 --sort rate --save /etc/pacman.d/mirrorlist
	### Synchronize pacman pkgs
	sudo pacman -Syy
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
	paru -S timeshift timeshift-autosnap
	timeshift

	### ZRAMD
	paru -S zramd
	sudo systemctl enable --now zramd.service
	lsblk

	### SDDM
	sudo pacman --noconfirm --needed -S sddm
	sudo systemctl enable --now sddm

	### OTHER
	sudo pacman --noconfirm --needed -S awesome awesome-terminal-fonts alacritty brave-bin firefox dmenu
	sudo pacman --noconfirm --needed -S xorg-server xorg-apps xorg-xinit xf86-input-libinput libinput xf86-input-evdev xf86-input-wacom
	sudo pacman --noconfirm --needed -S xdo bash-completion git wget zip gzip unzip
	sudo pacman --noconfirm --needed -S dunst flameshot udevil thunar sxiv libreoffice
	sudo pacman --noconfirm --needed -S arandr simplescreenrecorder arc-gtk-theme arc-icon-theme dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome awesome-terminal-fonts archlinux-wallpaper playerctl scrot obs-studio dunst pacman-contrib

		# printers
	sudo pacman --noconfirm --needed -S ghostscript gsfonts gutenprint gtk3-print-backends libcups hplip system-config-printer
		# fonts
	sudo pacman --noconfirm --needed -S adobe-source-sans-pro-fonts cantarell-fonts noto-fonts terminus-font ttf-bitstream-vera ttf-dejavu ttf-droid ttf-inconsolata ttf-liberation ttf-roboto ttf-ubuntu-font-family tamsyn-font


	sudo pacman -noconfirm --needed -S lf youtube-dl feh htop iio-sensor-proxy inotify-tools redshift conky xplr clifm thunar

    #sudo pacman -noconfirm --needed -S mypaint

#### c)

	sudo pacman -S android-tools android-udev
	paru -S scrcpy sndcpy-bin

	sudo pacman -S sysstats

		#Touchscreen
		echo "MOZ_USE_XINPUT2 DEFAULT=1" | sudo tee -a /etc/security/pam_env.conf
		
		#Touchpad
		sudo pacman -S xf86-input-synaptics
		cp $HOME/installation/conf/70-synaptics.conf /etc/X11/xorg.conf.d/70-synaptics.conf
		
		#Network
		sudo pacman -S network-manager-applet
		paru -S networkmanager-dmenu-git

		#card reader
		#sudo pacman -S ccid libnfc acsccid pcsclite pcsc-tools
		#sudo systemctl enable pcscd
		#sudo systemctl start pcscd

	sudo firewall-cmd --add-port=1025-65535/tcp --permanent
	sudo firewall-cmd --add-port=1025-65535/udp --permanent
	sudo firewall-cmd --reload

	#sudo pacman -S --noconfirm picom nitrogen lxappearance dmenu arandr simplescreenrecorder alsa-utils pulseaudio alsa-utils pulseaudio-alsa pavucontrol arc-gtk-theme arc-icon-theme dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome awesome-terminal-fonts archlinux-wallpaper playerctl scrot obs-studio dunst pacman-contrib


	sudo pacman -S --noconfirm alacritty xorg sddm firefox simplescreenrecorder obs-studio vlc mpv 

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
		help-start
	--help)
		help-start
    --install)
        install
	;;
    --arch-chroot)
        arch-chroot
        ;;
    --postinstall)
        postinstall
        ;;
    *)
        # By default print output for bar
	echo "Error: Option doesn't exist"
        ;;
esac

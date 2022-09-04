#!/bin/bash

#Definitions
wifi_name="Wifi"
disk="/dev/sda"
### Double font size
setfont -d
setfont ter-132n
### Wifi connection
ip a
iwctl station wla0 connect $wifi_name
#passphase
ping archlinux.org
### Syncronize time protocol
timedatectl set-ntp true
### Partitioning
lsblk
gdisk $disk
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
### Install
pacstrap /mnt base linux linux-headers linux-firmware vim git intel-ucode man-db man-pages texinfo linux-lts linux-lts-headers
#pacstrap /mnt base linux linux-headers linux-firmware vim git amd-ucode man-db man-pages texinfo linux-lts linux-lts-headers
genfstab -U /mnt >> /mnt/etc/fstab
### Arch chroot
arch-chroot /mnt

#pacman -S openssh
#ssh-keygen -t rsa -b 4096 -C "alpha.linux@protonmail.com"
#eval "$(ssh-agent -s)"
#ssh-add ~/.ssh/id_rsa
#cat ~/.ssh/id_rsa.pub

ln -sf /usr/share/zoneinfo/Europe/Bratislava /etc/localtime
hwclock --systohc
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
echo 'sk_SK.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=us" >> /etc/vconsole.conf
echo "ALPHA" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 ALPHA.localdomain ALPHA" >> /etc/hosts
echo root:password | chpasswd

# You can add xorg to the installation packages, I usually add it at the DE or WM install script
# You can remove the tlp package if you are installing on a desktop or vm

pacman -S grub efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils cups hplip alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack bash-completion openssh rsync reflector acpi acpi_call tlp virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid os-prober ntfs-3g terminus-font

# pacman -S --noconfirm xf86-video-amdgpu
# pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB #change the directory to /boot/efi is you mounted the EFI partition at /boot/efi

grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable tlp # You can comment this command out if you didn't install tlp, see above
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

useradd -m alpha
echo alpha:password | chpasswd
usermod -aG libvirt alpha

echo "alpha ALL=(ALL) ALL" >> /etc/sudoers.d/alpha
printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"

vim /etc/mkinitcpio.conf
	MODULES=(btrfs)
	#MODULES=(btrfs amdgpu)
mkinitcpio -p linux
exit
umount -R /mnt
reboot


### Wifi connection
ip a
iwctl station wla0 connect $wifi_name
#passphase
ping archlinux.org
sudo pacman -Syu

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo reflector -c Slovakia, Czechia -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

sudo pacman -S --noconfirm picom nitrogen lxappearance dmenu arandr simplescreenrecorder alsa-utils pulseaudio alsa-utils pulseaudio-alsa pavucontrol arc-gtk-theme arc-icon-theme dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome awesome-terminal-fonts archlinux-wallpaper playerctl scrot obs-studio dunst pacman-contrib


sudo pacman -S --noconfirm alacritty xorg sddm firefox simplescreenrecorder obs-studio vlc mpv 

sudo systemctl enable sddm

mkdir BuildApps
cd BuildApps
git clone https://aur.archlinux.org/paru-bin
cd paru-bin
makepkg -si
cd
paru -S timeshift timeshift-autosnap
timeshift

# ZRAMD
paru -S zramd
sudo systemctl enable --now zramd.service
lsblk

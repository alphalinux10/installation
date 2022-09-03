#!/bin/sh

# ##### UIFI,ENCRYPTED INSTALLATION OF ARCH LINUX ##### #


	TIMEZONE="Europe/Bratislava"
	LOCALE="en_US.UTF-8"
    	HOSTNAME="alpha"
	DRIVER=$(lspci | awk '/VGA/ {print $5}')
	
	NEXT=0; until [ $NEXT -eq 1 ]; do
		read -p "USER_NAME	:" USER_NAME	
		read -p "DISK		:" DISK

		if [ "$USER_NAME" == "" ] || [ "$DISK" == "" ]; then
			echo "You forgot to insert something, try again!"
		else
			NEXT=1
		fi
	done

	read -p "Are you sure to erase /dev/$DISK & start installation? (answer YES/NO) :" ANSWER
	if [ $ANSWER != 'YES' ]; then
		echo "Installation cancelled!"
		exit
	fi
#### a)	Connect to the Internet

    	ping -q -w1 -c1 archlinux.org &>/dev/null && CONN="CONNECTED" || (CONN="NOT_CONNECTED";)
        while [ "$CONN" != "CONNECTED" ]; do
            	echo -e "\033[0;36m'You are not connected to the internet!'\033[0;0m"
            	ip addr show
		echo "HELP: # device list # station wlan0 scan # station wlan0 get-networks # station wlan0 connect \$WIFI_NAME #(WIFI password) # exit"
            	iwctl 
            	ping -q -w1 -c1 archlinux.org &>/dev/null && CONN="CONNECTED" || CONN="NOT_CONNECTED"
        done
        echo "You are connected to the internet!"

#### b) Verify the boot mode

        if [ -d "/sys/firmware/efi/efivars" ]; then
            echo "UEFI"
            BOOT="UEFI"
        else
            echo "BIOS"
            BOOT="BIOS"
	    exit
        fi

#### c)	Update the system clock

        timedatectl set-ntp true

#### d) Partition the disks

	fdisk -l
	cat<<EOF | fdisk /dev/$DISK
		g
		n
		1

		+10M
		n
		2

		+250M
		n
		3


		t
		1
		4
		t
		2
		1
		p
		w
EOF
	lsblk

#### e) Format the partitions & Mount the file systems
		##### System encryption
	echo "HELP: #YES #(ENCRYPTION_KEY) #(ENCRYPTION_KEY) ... #(ENCRYPTION_KEY"
	cryptsetup -y -v luksFormat /dev/"$DISK"3
	cryptsetup open /dev/"$DISK"3 crypt_root
		##### Format the partitions
	mkfs.fat -F32 /dev/"$DISK"2
	mkfs.ext4 -O "^has_journal" /dev/mapper/crypt_root
		##### Mount the file systems
	mount /dev/mapper/crypt_root /mnt
	mkdir /mnt/boot
	mount /dev/"$DISK"2 /mnt/boot
	lsblk


        echo "      <><><><><><><><><><><><><><><><><><><><>      "
        echo "        <> CUSTOM ARCH LINUX INSTALLATION <>        "
        echo "      <><><><><><><><><><><><><><><><><><><><>      "
#### a) Select the mirrors and update database

	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	reflector -c Slovakia -c Czechia -a 6 --sort rate --save /etc/pacman.d/mirrorlist

        pacman --noconfirm --needed -Syy

#### c) Install the base packages

	pacstrap /mnt base linux linux-firmware vim

#### c)	Fstab

	genfstab -U /mnt >> /mnt/etc/fstab
	cat /mnt/etc/fstab

#### d) Chroot

	arch-chroot /mnt /bin/sh <<END
		
	#### 1) Swapfile 16GiB
		dd if=/dev/zero of=/swapfile bs=1M count=16384 status=progress
		chmod 600 /swapfile
		mkswap /swapfile
		swapon /swapfile
		echo "/swapfile none swap defaults 0 0" >> /etc/fstab
		cat /etc/fstab

	#### 2) Time zone
    		ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    		hwclock --systohc

    	#### 3) Locale
		sed -i  '/$LOCALE/s/^#//g' /etc/locale.gen
		locale-gen
		echo "LANG=$LOCALE" > /etc/locale.conf

    	#### 4) Hostname & network configuration
    		echo $HOSTNAME > /etc/hostname
		echo "127.0.0.1		localhost" > /etc/hosts
		echo "::1      		localhost" >> /etc/hosts
		echo "127.0.0.1		$HOSTNAME.localdomain		$HOSTNAME" >> /etc/hosts
		pacman --noconfirm --needed -S networkmanager network-manager-applet wireless_tools wpa_supplicant dialog os-prober mtools dosfstools

    	#### 5) Linux core packages & drivers & another needed packages
		pacman --noconfirm --needed -S base-devel linux-headers reflector git
		# Drivers	
		pacman --noconfirm --needed -S xf86-video-intel libgl mesa intel-ucode intel-gmmlib intel-media-driver intel-media-sdk intel-tbb nvidia nvidia-lts nvidia-libgl xf86-video-amdgpu xf86-video-nouveau xf86-video-ati xf86-video-vesa virtualbox-guest-utils virtualbox-guest-modules-arch mesa-libgl
		# Bluetooth & Printing
		pacman --noconfirm --needed -S bluez bluez-utils pulseaudio-bluetooth cups xdg-utils xdg-user-dirs acpi
				
	#### 6) Initramfs
		sed -i '/^HOOKS/s/.*/HOOKS=(base udev block encrypt filesystems keyboard fsck)/i' /etc/mkinitcpio.conf
		mkinitcpio -p linux
	
	##### 7) Boot loader
		pacman --noconfirm --needed -S grub efibootmgr
		grub-install --target=i386-pc --boot-directory=/boot /dev/$DISK
		grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot --removable --recheck
		sed -i  '/GRUB_ENABLE_CRYPTODISK=y/s/^#//g' /etc/default/grub
		sed -i '<^GRUB_CMDLINE_LINUX=<s<\"$< cryptdevice=UUID=$(blkid | grep "crypto_LUKS" | sed 's>^[^\"]*\">>;s>\".*>>g'):crypt_root root=/dev/mapper/crypt_root"<' /etc/default/grub
		grub-mkconfig -o /boot/grub/grub.cfg

	#### 8) Enable network manager & bluetooth & printing
		systemctl enable NetworkManager
		systemctl enable bluetooth 
		systemctl enable org.cups.cupsd
				
	#### 9) Create user
		useradd -mG wheel $USER_NAME

	#### 10) Sudo permitions of user
		pacman  --noconfirm --needed -S sudo vim
		sed -i 's>^# %wheel ALL=(ALL) ALL>%wheel ALL=(ALL) ALL>' /etc/sudoers

	#### 11) Journal 
		sed -i '/Storage=auto/s/.*/Storage=volatile;/RuntimeMaxUse=/s/.*/RuntimeMaxUse=30M' /etc/systemd/journald.conf
	##### Exit chroot
		exit
END

#### e) Root password & password of user

	echo "HELP: # passwd # passwd $USER_NAME # exit"
	arch-chroot /mnt

#### f) Unmount all the partitions

	umount -a

#### g) Restart the machine

	reboot

# ##### --------------------------------------------- ##### #

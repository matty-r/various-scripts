#!/bin/bash

# Arch Linux INSTALL SCRIPT
driver(){
  INSTALLSTAGE=$(cat ~/installer.cfg)
  case INSTALLSTAGE in
    "FIRST"|"")
      echo "FIRST INSTALL STAGE"
      $(firstInstallStage)
      ;;
  esac

}

firstInstallStage(){
  $(generateSettings)
  $(systemClock)
  $(partDisks)
  $(formartParts)
  $(mountParts)
  $(installBase)
  $(makeFstab)
  $(chrootTime)
}


generateSettings(){
  # REQUIRE USER MODIFICATION
  USERNAME="matt"
  HOSTNAME="arch-desktop"

  # DISKS
  BOOTPART="/dev/sda1"
  BOOTMODE="CREATE" #CREATE,FORMAT,LEAVE
  ROOTPART="/dev/sda2"
  ROOTMODE="CREATE" #CREATE,FORMAT,LEAVE

  # DO NOT EDIT THESE
  BOOTDEVICE=$(echo $BOOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  ROOTDEVICE=$(echo $ROOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
  NETINT=$(ip link | grep "BROADCAST,MULTICAST,UP,LOWER_UP" | grep -oP '(?<=: ).*(?=: )')

  echo "FIRST" >> ~/installer.cfg
}

exportSettings(){
  ## write all settings to a file on new root
  echo "exportSettings .. nothing yet"
}

###Update the system clock
systemClock(){
  timedatectl set-ntp true
}

### PARTITION DISKS
partDisks(){
if [ $BOOTMODE = "CREATE" ] && [ $ROOTMODE = "CREATE" ]; then
  if [ $BOOTDEVICE = $ROOTDEVICE ]; then
    DEVICE=$(echo $BOOTPART | sed 's/[0-9]//g')
    parted -s $DEVICE -- mklabel gpt \
          mkpart primary fat32 0% 256MiB \
          mkpart primary ext4 256MiB 100%
  fi
fi
}

### FORMAT PARTITIONS
#mkfs.ext4 /dev/sdX1
formartParts(){
  if [ $BOOTMODE = "CREATE" ] || [ $BOOTMODE = "FORMAT" ]; then
    mkfs.fat -F32 $BOOTPART
  fi

  if [ $ROOTMODE = "CREATE" ] || [ $ROOTMODE = "FORMAT" ]; then
    mkfs.ext4 $ROOTPART
  fi
}

### If you created a partition for swap, initialize it with mkswap:
#mkswap /dev/sdX2
#swapon /dev/sdX2

### Mount the file systems
mountParts(){
  mount $ROOTDEVICE /mnt
  mkdir /mnt/boot
  mount $BOOTDEVICE /mnt/boot
}

### Install the base packages
installBase(){
  pacstrap /mnt base base-devel
}

### Generate an fstab file
makeFstab(){
  genfstab -U /mnt >> /mnt/etc/fstab
}

### Change root into the new system:
chrootTime(){
  echo "SECOND" >> ~/installer.cfg
  arch-chroot /mnt
}

### Set the time zone
setTime(){
  ln -sf /usr/share/zoneinfo/Australia/Brisbane /etc/localtime
  hwclock --systohc
}

### Uncomment en_US.UTF-8 UTF-8 and other needed locales in /etc/locale.gen
genLocales(){
  sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
  sed -i "s/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/" /etc/locale.gen
  locale-gen
  echo "LANG=en_AU.UTF-8" >> /etc/locale.conf
}

### Create the hostname file:
applyHostname(){
  echo "$HOSTNAME" >> /etc/hostname
}

### ADD HOSTS ENTRIES
addHosts(){
  echo "127.0.0.1     localhost" >> /etc/hosts
  echo "::1       localhost" >> /etc/hosts
  echo "127.0.1.1     $HOSTNAME.mydomain      $HOSTNAME" >> /etc/hosts
}

### GENERATE INITRAMFS
genInit(){
  mkinitcpio -p linux
}

### ROOT PASSWORD
rootPassword(){
  passwd
}

### INSTALL BOOTLOADER AND MICROCODE
readyForBoot(){
  pacman -S refind-efi intel-ucode
  refind-install
}

### FIX REFIND CONFIG https://wiki.archlinux.org/index.php/REFInd#refind_linux.conf

enableNetworkBoot(){
  sudo systemctl enable dhcpcd@$NETINT.service
}

####### add a user add to wheel group
createUser(){
  useradd -m $USERNAME
  gpasswd -a $USERNAME wheel
####### change user password
  su - $USERNAME
  passwd
  logout
###### enable wheel group for sudoers
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
}

###################################### reboot
reboot

#### Login as new user on reboot

######################################## Install nvidia stuff
installNvidia(){
  sudo pacman -S nvidia lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader nvidia-settings
}

###################################### reboot
reboot

#### Login as new user on reboot

######################################## Install the good stuff
installDesktop(){
  sudo pacman -S plasma kcalc konsole spectacle dolphin dolphin-plugins filelight kate kwalletmanager thunderbird steam ark ffmpegthumbs gwenview gimp kdeconnect kdf kdialog kfind firefox git gnome-keyring wget
  sudo systemctl enable sddm
}

###### make yay
makeYay(){
  git clone https://aur.archlinux.org/yay.git
  cd ~/yay
  makepkg -sri
}

######################################## Install the good stuff
installGoodies(){
  yay -S gparted ntfs-3g fwupd packagekit-qt5 htop nextcloud-client adapta-kde kvantum-theme-adapta papirus-icon-theme rsync remmina freerdp-git protonmail-bridge ttf-roboto virtualbox virtualbox-guest-iso xsane ttf-roboto-mono spotify libreoffice-fresh discord filezilla atom-editor-bin
}

############ enable network manager/disable dhcpcd
readyFinalBoot(){
  sudo systemctl disable dhcpcd@interface.service
  sudo systemctl enable NetworkManager
}


###################################### reboot
reboot

#### Login as new user on reboot

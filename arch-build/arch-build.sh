#!/bin/bash

# Arch Linux INSTALL SCRIPT

generateSettings(){
  # DO NOT EDIT THESE
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}
  # create settings file
  echo "" > $SCRIPTROOT/installsettings.cfg
  # CREATE PROGRESS FILE
  echo "FIRST" > $SCRIPTROOT/installer.cfg

  ########### MODiFY THESE ONES \/\/\/\/\/\/\/\/ ##################
  $(exportSettings "USERNAME" "matt")  ## << CHANGE
  $(exportSettings "HOSTNAME" "arch-vm") ## << CHANGE
  BOOTPART="/dev/sda1"  ## << CHANGE BOOT PARTITION
  $(exportSettings "BOOTPART" $BOOTPART)
  $(exportSettings "BOOTMODE" "LEAVE") # << CREATE WILL DESTROY THE DISK, FORMAT WILL JUST FORMAT THE PARTITION, LEAVE WILL DO NOTHING
  ROOTPART="/dev/sda2"  ## << CHANGE ROOT PARTITION
  $(exportSettings "ROOTPART" $ROOTPART)
  $(exportSettings "ROOTMODE" "FORMAT") # << CREATE WILL DESTROY THE DISK, FORMAT WILL JUST FORMAT THE PARTITION, LEAVE WILL DO NOTHING
  ########### MODIFY THESE ONES ^^^^^^^^^^^^^^^^

  # DO NOT EDIT THESE
  BOOTDEVICE=$(echo $BOOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "BOOTDEVICE" $BOOTDEVICE)
  ROOTDEVICE=$(echo $ROOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "ROOTDEVICE" $ROOTDEVICE)
  $(exportSettings "SCRIPTPATH" "$SCRIPTPATH")
  $(exportSettings "SCRIPTROOT" "$SCRIPTROOT")
  $(exportSettings "NETINT" $(ip link | grep "BROADCAST,MULTICAST,UP,LOWER_UP" | grep -oP '(?<=: ).*(?=: )') )
}


driver(){
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}

  INSTALLSTAGE=$(cat $SCRIPTROOT/installer.cfg)
  case $INSTALLSTAGE in
    "FIRST"|"")
      echo "FIRST INSTALL STAGE" > /dev/stderr
      firstInstallStage
      ;;
    "SECOND")
      echo "SECOND INSTALL STAGE" > /dev/stderr
      secondInstallStage
      ;;
    "THIRD")
      echo "THIRD INSTALL STAGE" > /dev/stderr
      thirdInstallStage
      ;;
    "FOURTH")
      echo "LAST INSTALL STAGE"  > /dev/stderr
      fourthInstallStage
      ;;
    esac
}

firstInstallStage(){
  echo "1. Generate Settings" > /dev/stderr
  sleep 2
  generateSettings
  echo "2. System Clock" > /dev/stderr
  sleep 2
  systemClock
  echo "3. Partition Disks" > /dev/stderr
  sleep 2
  partDisks
  echo "4. Format Partitions" > /dev/stderr
  sleep 2
  formatParts
  echo "5. Mount partitions" > /dev/stderr
  sleep 2
  mountParts
  echo "6. Install base packages" > /dev/stderr
  sleep 2
  installBase
  echo "7. Making the FSTAB" > /dev/stderr
  sleep 2
  makeFstab
  echo "8. Setup chroot." > /dev/stderr
  sleep 2
  chrootTime

  USERNAME=$(retrieveSettings "USERNAME")
  arch-chroot /mnt ./home/$USERNAME/arch-build.sh
  reboot
}

secondInstallStage(){
  echo "10. chroot: Generate Settings" > /dev/stderr
  sleep 2
  generateSettings

  echo "11. chroot: Set Time" > /dev/stderr
  sleep 2
  setTime

  echo "12. chroot: Generate locales" > /dev/stderr
  sleep 2
  genLocales

  echo "13. chroot: Apply HostName" > /dev/stderr
  sleep 2
  applyHostname

  echo "14. chroot: Add hosts file entries" > /dev/stderr
  sleep 2
  addHosts

  echo "15. chroot: Generate mkinitcpio" > /dev/stderr
  sleep 2
  genInit

  echo "16. chroot: Set root password" > /dev/stderr
  sleep 2
  rootPassword

  echo "17. chroot: Getting ready to boot" > /dev/stderr
  sleep 2
  readyForBoot

  echo "18. chroot: Fix network on boot" > /dev/stderr
  sleep 2
  enableNetworkBoot

  echo "19. chroot: Create new user" > /dev/stderr
  sleep 2
  createUser

  echo "Rebooting. Re-run on boot. Login as new user"
  sleep 10
  exit
}

thirdInstallStage(){
  echo "20. install nvidia stuff"
  sleep 2
  installNvidia

  echo "Rebooting. Re-run on boot. Login as new user"
  sleep 10
  sudo reboot
}

fourthInstallStage(){
  echo "21. : Generate Settings" > /dev/stderr
  sleep 2
  generateSettings

  echo "22. Install KDE"
  sleep 2
  installDesktop

  echo "23. Install yay - AUR package manager"
  sleep 2
  makeYay

  echo "24. Install Goodies"
  sleep 2
  installGoodies

  echo "25. Readying final boot."
  sleep 2
  readyFinalBoot

  echo "Script done. You're good to go after reboot."
  sleep 10
  sudo reboot
}

exportSettings(){
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}

  echo "Exporting $1=$2" > /dev/stderr
  EXPORTPARAM="$1=$2"
  ## write all settings to a file on new root
  echo -e "$EXPORTPARAM" >> $SCRIPTROOT/installsettings.cfg
}

#retrieveSettings 'SETTINGNAME'
retrieveSettings(){
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}
  SETTINGSPATH=$SCRIPTROOT"/installsettings.cfg"

  SETTINGNAME=$1
  SETTING=$(cat $SETTINGSPATH | grep $1 | cut -f2,2 -d'=')
  echo $SETTING
}

###Update the system clock
systemClock(){
  timedatectl set-ntp true
}

### PARTITION DISKS
partDisks(){
  BOOTMODE=$(retrieveSettings 'BOOTMODE')
  ROOTMODE=$(retrieveSettings 'ROOTMODE')
  BOOTDEVICE=$(retrieveSettings 'BOOTDEVICE')
  ROOTDEVICE=$(retrieveSettings 'ROOTDEVICE')
  BOOTPART=$(retrieveSettings 'BOOTPART')
  ROOTPART=$(retrieveSettings 'ROOTPART')

#  if [ $BOOTMODE = "CREATE" ] && [ $ROOTMODE = "CREATE" ]; then
#    if [ $BOOTDEVICE = $ROOTDEVICE ]; then
#      DEVICE=$(echo $BOOTPART | sed 's/[0-9]//g')
#      parted -s $DEVICE -- mklabel gpt \
#            mkpart primary fat32 0% 256MiB \
#            mkpart primary ext4 256MiB 100%
#    fi
#  fi

  case $BOOTMODE in
    "LEAVE"|"FORMAT")
      echo "Leaving the boot partition..." > /dev/stderr
      ;;
    "CREATE")
      echo "Boot partition will be created. Whole disk will be destroyed!" > /dev/stderr
      DEVICE=$(echo $BOOTPART | sed 's/[0-9]//g')
      parted -s $DEVICE -- mklabel gpt \
            mkpart primary fat32 0% 256MiB
      ;;
    esac

    case $ROOTMODE in
      "LEAVE"|"FORMAT")
        echo "Leaving the root partition..." > /dev/stderr
        ;;
      "CREATE")
        echo "Root partition will be created. Whole disk will be destroyed!" > /dev/stderr
        DEVICE=$(echo $ROOTPART | sed 's/[0-9]//g')
        parted -s $DEVICE -- mklabel gpt \
              mkpart primary fat32 0% 100%
        ;;
    esac
}

### FORMAT PARTITIONS
#mkfs.ext4 /dev/sdX1
formatParts(){
  BOOTMODE=$(retrieveSettings 'BOOTMODE')
  ROOTMODE=$(retrieveSettings 'ROOTMODE')
  BOOTPART=$(retrieveSettings 'BOOTPART')
  ROOTPART=$(retrieveSettings 'ROOTPART')

  if [ $BOOTMODE = "CREATE" ] || [ $BOOTMODE = "FORMAT" ]; then
    mkfs.fat -F32 $BOOTPART
  fi

  if [ $ROOTMODE = "CREATE" ] || [ $ROOTMODE = "FORMAT" ]; then
    mkfs.ext4 -F -F $ROOTPART
  fi
}

### Mount the file systems
mountParts(){
  BOOTPART=$(retrieveSettings 'BOOTPART')
  rOOTPART=$(retrieveSettings 'ROOTPART')

  mount $ROOTPART /mnt
  mkdir /mnt/boot
  mount $BOOTPART /mnt/boot
}


setAussieMirrors(){
cat <<EOF > /etc/pacman.d/mirrorlist
##
## Arch Linux repository mirrorlist
## Filtered by mirror score from mirror status page
## Generated on 2019-05-02
##
## Australia
Server = http://archlinux.melbourneitmirror.net/\$repo/os/\$arch
## Australia
Server = http://archlinux.mirror.digitalpacific.com.au/\$repo/os/\$arch
## Australia
Server = http://ftp.iinet.net.au/pub/archlinux/\$repo/os/\$arch
## Australia
Server = http://ftp.swin.edu.au/archlinux/\$repo/os/\$arch
## Australia
Server = http://mirror.internode.on.net/pub/archlinux/\$repo/os/\$arch
EOF
}

### Install the base packages
installBase(){
  setAussieMirrors
  pacstrap /mnt base base-devel
}

### Generate an fstab file
makeFstab(){
  genfstab -U /mnt >> /mnt/etc/fstab
}

### Change root into the new system:
chrootTime(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')

  echo "SECOND" > $SCRIPTROOT/installer.cfg
  USERNAME=$(retrieveSettings 'USERNAME')
  SCRIPTPATH=$(retrieveSettings 'SCRIPTPATH')

  mkdir /mnt/home/$USERNAME
  cp $SCRIPTROOT/installer.cfg /mnt/home/$USERNAME
  cp $SCRIPTPATH /mnt/home/$USERNAME
  cp $SCRIPTROOT/installsettings.cfg /mnt/home/$USERNAME

  #Run script from crhoot
  #arch-chroot /mnt source /mnt/home/$USERNAME/arch-build.sh
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
  HOSTNAME=$(retrieveSettings 'HOSTNAME')
  echo "$HOSTNAME" >> /etc/hostname
}

### ADD HOSTS ENTRIES
addHosts(){
  HOSTNAME=$(retrieveSettings 'HOSTNAME')

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
  pacman -S --noconfirm refind-efi intel-ucode
  refind-install
  echo "a) Fixing refind. Before: " > /dev/stderr

  cat /boot/refind_linux.conf
  sleep 5
  fixRefind

  echo "b) Fixing refind. After: " > /dev/stderr
  cat /boot/refind_linux.conf
  sleep 5
}

fixRefind(){
  ROOTPART=$(retrieveSettings 'ROOTPART')
  ROOTUUID=$(blkid | grep $ROOTPART | grep -oP '(?<= UUID=").*(?=" TYPE)')

cat <<EOF > /boot/refind_linux.conf
"Boot with standard options"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=intel-ucode.img initrd=initramfs-linux.img"
"Boot using fallback initramfs"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=intel-ucode.img initrd=initramfs-linux-fallback.img"
"Boot to terminal"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=intel-ucode.img initrd=initramfs-linux.img systemd.unit=multi-user.target"
EOF
}

enableNetworkBoot(){
  NETINT=$(retrieveSettings 'NETINT')
  sudo systemctl enable dhcpcd@$NETINT.service
}

####### add a user add to wheel group
createUser(){
  USERNAME=$(retrieveSettings 'USERNAME')
  useradd -m $USERNAME
  gpasswd -a $USERNAME wheel
  ####### change user password
  # su - $USERNAME
  echo "Set password for $USERNAME"
  passwd $USERNAME
  ###### enable wheel group for sudoers
  sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
  ###### enable wheel group for sudoers - no password. TEMPORARY
  sed -i "s/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
  echo "THIRD" > /home/$USERNAME/installer.cfg

  ##SET OWNERSHIP OF SCRIPT FILES TO BE RUN AFTER REBOOT
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  chown $USERNAME:$USERNAME $SCRIPTROOT --recursive
}


enableMultilibPackages(){
  sudo sed -i '/#\[multilib\]/a Include = \/etc\/pacman.d\/mirrorlist' /etc/pacman.conf
  sudo sed -i "s/#\[multilib\]/[multilib]/" /etc/pacman.conf

  sudo pacman -Syyu
}

######################################## Install nvidia stuff
installNvidia(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  enableMultilibPackages

  sudo pacman -S --noconfirm nvidia lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader nvidia-settings
  echo "FOURTH" > $SCRIPTROOT/installer.cfg
}

###################################### reboot

#### Login as new user on reboot

######################################## Install the good stuff
installDesktop(){
  sudo pacman -S --noconfirm plasma kcalc konsole spectacle dolphin dolphin-plugins filelight kate kwalletmanager thunderbird steam ark ffmpegthumbs gwenview gimp kdeconnect kdf kdialog kfind firefox git gnome-keyring wget
}

###### make yay
makeYay(){
  git clone https://aur.archlinux.org/yay.git
  cd ~/yay
  makepkg -sri --noconfirm
  cd ~
}

######################################## Install the good stuff
installGoodies(){
  yay -S --noconfirm gparted ntfs-3g fwupd packagekit-qt5 htop nextcloud-client adapta-kde kvantum-theme-adapta papirus-icon-theme rsync remmina freerdp-git protonmail-bridge ttf-roboto virtualbox virtualbox-guest-iso xsane spotify libreoffice-fresh discord filezilla atom-editor-bin vlc obs-studio
}

############ enable network manager/disable dhcpcd
readyFinalBoot(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  NETINT=$(retrieveSettings 'NETINT')
  sudo systemctl disable dhcpcd@$NETINT.service
  sudo systemctl enable NetworkManager
  sudo systemctl enable sddm
  echo "DONE" > $SCRIPTROOT/installer.cfg
  ###### unset no password sudoers
  sudo sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
}


###################################### reboot

#### Login as new user on reboot

driver

#!/bin/bash

# Arch Linux INSTALL SCRIPT
driver(){
  INSTALLSTAGE=$(cat ./installer.cfg)
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
      echo "LAST INSTALL STAGE"
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
  echo "8.  GOING CHROOT. RE-EXECUTE SCRIPT IN /mnt/home/username DIRECTORY" > /dev/stderr
  sleep 2
  chrootTime
  driver
}

secondInstallStage(){
  setTime
  genLocales
  applyHostname
  addHosts
  genInit
  rootPassword
  readyForBoot
  ###### Add step fix refind
  enableNetworkBoot
  createUser
  exit
  echo "Rebooting. Re-run on boot"
  reboot
}

thirdInstallStage(){
  installNvidia
  echo "Rebooting. Re-run on boot"
  reboot
}

fourthInstallStage(){
  installDesktop
  makeYay
  installGoodies
  readyFinalBoot
  echo "Rebooting. Re-run on boot"
  reboot
}

generateSettings(){
  # create settings file
  echo "" > ./installsettings.cfg

  # REQUIRE USER MODIFICATION
  $(exportSettings "USERNAME" "matt")
  $(exportSettings "HOSTNAME" "arch-vm")

  # DISKS
  BOOTPART="/dev/sda1"
  $(exportSettings "BOOTPART" $BOOTPART)
  $(exportSettings "BOOTMODE" "CREATE") #CREATE,FORMAT,LEAVE
  ROOTPART="/dev/sda2"
  $(exportSettings "ROOTPART" $ROOTPART)
  $(exportSettings "ROOTMODE" "CREATE") #CREATE,FORMAT,LEAVE)

  # DO NOT EDIT THESE
  BOOTDEVICE=$(echo $BOOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "BOOTDEVICE" $BOOTDEVICE)
  ROOTDEVICE=$(echo $ROOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "ROOTDEVICE" $ROOTDEVICE)
  #$(exportSettings "SCRIPTPATH" $( cd "$(dirname "$0")" ; pwd -P ) )
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  $(exportSettings "SCRIPTPATH" "$SCRIPTPATH")
  $(exportSettings "NETINT" $(ip link | grep "BROADCAST,MULTICAST,UP,LOWER_UP" | grep -oP '(?<=: ).*(?=: )') )

  echo "FIRST" > ./installer.cfg
}

exportSettings(){
  echo "Exporting $1=$2" > /dev/stderr
  EXPORTPARAM="$1=$2"
  ## write all settings to a file on new root
  echo -e "$EXPORTPARAM" >> ./installsettings.cfg
}

#retrieveSettings 'FILEPATH' 'SETTINGNAME'
retrieveSettings(){
  SETTINGSPATH=$1
  SETTINGNAME=$2
  SETTING=$(cat $1 | grep $2 | cut -f2,2 -d'=')
  echo $SETTING
}

###Update the system clock
systemClock(){
  timedatectl set-ntp true
}

### PARTITION DISKS
partDisks(){
  BOOTMODE=$(retrieveSettings ./installsettings.cfg 'BOOTMODE')
  ROOTMODE=$(retrieveSettings ./installsettings.cfg 'ROOTMODE')
  BOOTDEVICE=$(retrieveSettings ./installsettings.cfg 'BOOTDEVICE')
  ROOTDEVICE=$(retrieveSettings ./installsettings.cfg 'ROOTDEVICE')
  BOOTPART=$(retrieveSettings ./installsettings.cfg 'BOOTPART')

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
formatParts(){
  BOOTMODE=$(retrieveSettings ./installsettings.cfg 'BOOTMODE')
  ROOTMODE=$(retrieveSettings ./installsettings.cfg 'ROOTMODE')
  BOOTPART=$(retrieveSettings ./installsettings.cfg 'BOOTPART')
  ROOTPART=$(retrieveSettings ./installsettings.cfg 'ROOTPART')

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
  BOOTPART=$(retrieveSettings ./installsettings.cfg 'BOOTPART')
  rOOTPART=$(retrieveSettings ./installsettings.cfg 'rOOTPART')

  mount $ROOTPART /mnt
  mkdir /mnt/boot
  mount $BOOTPART /mnt/boot
}

### Install the base packages
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
  echo "SECOND" > ./installer.cfg
  USERNAME=$(retrieveSettings ./installsettings.cfg 'USERNAME')
  SCRIPTPATH=$(retrieveSettings ./installsettings.cfg 'SCRIPTPATH')

  mkdir /mnt/home/$USERNAME
  cp ./installer.cfg /mnt/home/$USERNAME
  cp $SCRIPTPATH /mnt/home/$USERNAME
  cp ./installsettings.cfg /mnt/home/$USERNAME

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
  HOSTNAME=$(retrieveSettings ./installsettings.cfg 'HOSTNAME')
  echo "$HOSTNAME" >> /etc/hostname
}

### ADD HOSTS ENTRIES
addHosts(){
  HOSTNAME=$(retrieveSettings ./installsettings.cfg 'HOSTNAME')

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
}

### FIX REFIND CONFIG https://wiki.archlinux.org/index.php/REFInd#refind_linux.conf

enableNetworkBoot(){
  NETINT=$(retrieveSettings ./installsettings.cfg 'NETINT')

  sudo systemctl enable dhcpcd@$NETINT.service
}

####### add a user add to wheel group
createUser(){
  USERNAME=$(retrieveSettings ./installsettings.cfg 'USERNAME')
  useradd -m $USERNAME
  gpasswd -a $USERNAME wheel
  ####### change user password
  # su - $USERNAME
  echo "Set password for $USERNAME"
  passwd $USERNAME
  ###### enable wheel group for sudoers
  sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
  echo "THIRD" > /home/$USERNAME/installer.cfg
}

###################################### reboot

#### Login as new user on reboot

######################################## Install nvidia stuff
installNvidia(){
  sudo pacman -S --noconfirm nvidia lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader nvidia-settings
  echo "FOURTH" > ./installer.cfg
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
  makepkg -sri
}

######################################## Install the good stuff
installGoodies(){
  yay -S --noconfirm gparted ntfs-3g fwupd packagekit-qt5 htop nextcloud-client adapta-kde kvantum-theme-adapta papirus-icon-theme rsync remmina freerdp-git protonmail-bridge ttf-roboto virtualbox virtualbox-guest-iso xsane ttf-roboto-mono spotify libreoffice-fresh discord filezilla atom-editor-bin
}

############ enable network manager/disable dhcpcd
readyFinalBoot(){
  sudo systemctl disable dhcpcd@interface.service
  sudo systemctl enable NetworkManager
  sudo systemctl enable sddm
  echo "DONE" >> ./installer.cfg
}


###################################### reboot

#### Login as new user on reboot

driver

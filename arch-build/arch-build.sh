#!/bin/bash
# Version 1
# Arch Linux INSTALL SCRIPT

generateSettings(){
  # DO NOT EDIT THESE
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}
  # create settings file
  echo "" > "$SCRIPTROOT/installsettings.cfg"

  ########### MODIFY THESE ONES \/\/\/\/\/\/\/\/ ##################
  $(exportSettings "INSTALLTYPE" "HYPERV") ## << CHANGE. "PHYS" for install on physical hardware. "VBOX" for install as VirtualBox Guest. "QEMU" for install as QEMU/ProxMox Guest.
  $(exportSettings "USERNAME" "matt")  ## << CHANGE
  $(exportSettings "HOSTNAME" "arch-temp") ## << CHANGE
  $(exportSettings "DESKTOP" "XFCE") ## << CHANGE. "KDE" for Plasma, "XFCE" for XFCE.
  BOOTPART="/dev/sda1"  ## << CHANGE BOOT PARTITION
  $(exportSettings "BOOTPART" $BOOTPART)
  $(exportSettings "BOOTMODE" "CREATE") # << CREATE WILL DESTROY THE DISK, FORMAT WILL JUST FORMAT THE PARTITION, LEAVE WILL DO NOTHING
  ROOTPART="/dev/sda2"  ## << CHANGE ROOT PARTITION
  $(exportSettings "ROOTPART" $ROOTPART)
  $(exportSettings "ROOTMODE" "CREATE") # << CREATE WILL DESTROY THE DISK, FORMAT WILL JUST FORMAT THE PARTITION, LEAVE WILL DO NOTHING
  ########### MODIFY THESE ONES ^^^^^^^^^^^^^^^^

  # DO NOT EDIT THESE
  BOOTDEVICE=$(echo $BOOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "BOOTDEVICE" $BOOTDEVICE)
  ROOTDEVICE=$(echo $ROOTPART | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "ROOTDEVICE" $ROOTDEVICE)
  $(exportSettings "SCRIPTPATH" "$SCRIPTPATH")
  $(exportSettings "SCRIPTROOT" "$SCRIPTROOT")
  $(exportSettings "NETINT" $(ip link | grep "BROADCAST,MULTICAST,UP,LOWER_UP" | grep -oP '(?<=: ).*(?=: )') )
  EFIPATH="/sys/firmware/efi/efivars"
  if [ -d "$EFIPATH" ]
  then
    $(exportSettings "BOOTTYPE" "EFI")
  else
  	$(exportSettings "BOOTTYPE" "BIOS")
  fi

  #set comparison to ignore case temporarily
  shopt -s nocasematch

  CPUTYPE=$(lscpu | grep Vendor)
  if [[ $CPUTYPE =~ "AMD" ]]; then
    CPUTYPE="amd"
  else
    CPUTYPE="intel"
  fi
  $(exportSettings "CPUTYPE" "$CPUTYPE")

  GPUTYPE=$(lspci -vnn | grep VGA)
  if [[ $GPUTYPE =~ "nvidia" ]]; then
    GPUTYPE="nvidia"
  else
    GPUTYPE="vm"
  fi
  $(exportSettings "GPUTYPE" "$GPUTYPE")

  #reset comparisons
  shopt -u nocasematch
}


driver(){
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}

  INSTALLSTAGE=$(cat "$SCRIPTROOT/installer.cfg")
  case $INSTALLSTAGE in
    "FIRST"|"")
      echo "FIRST INSTALL STAGE"
      firstInstallStage
      ;;
    "SECOND")
      echo "SECOND INSTALL STAGE"
      secondInstallStage
      ;;
    "THIRD")
      echo "THIRD INSTALL STAGE"
      thirdInstallStage
      ;;
    "FOURTH")
      echo "LAST INSTALL STAGE"
      fourthInstallStage
      ;;
    esac
}

firstInstallStage(){
  echo "1. Generate Settings"
  generateSettings

  echo "2. System Clock"
  systemClock

  echo "3. Partition Disks"
  partDisks

  echo "4. Format Partitions"
  formatParts

  echo "5. Mount partitions"
  mountParts

  echo "6. Install base packages"
  installBase

  echo "7. Making the FSTAB"
  makeFstab

  echo "8. Setup chroot."
  chrootTime

  USERNAME=$(retrieveSettings "USERNAME")

  #Go into chroot
  arch-chroot /mnt ./home/$USERNAME/arch-build.sh

  #Go into chroot as new user
  arch-chroot /mnt su $USERNAME ./home/$USERNAME/arch-build.sh

  reboot
}

secondInstallStage(){
  echo "10. chroot: Generate Settings"
  generateSettings

  echo "11. chroot: Set Time"
  setTime

  echo "12. chroot: Generate locales"
  genLocales

  echo "13. chroot: Apply HostName"
  applyHostname

  echo "14. chroot: Add hosts file entries"
  addHosts

  echo "15. chroot: Generate mkinitcpio"
  genInit

  echo "16. chroot: Set root password"
  rootPassword

  echo "17. chroot: Getting ready to boot"
  readyForBoot

  echo "18. chroot: Fix network on boot"
  enableNetworkBoot

  echo "19. chroot: Create new user"
  createUser

  thirdInstallStage

  #echo "Rebooting. Re-run on boot. Login as new user"
  exit
}

thirdInstallStage(){
  INSTALLTYPE=$(retrieveSettings "INSTALLTYPE")
  case $INSTALLTYPE in
    "PHYS")
        echo "20. install graphics stuff"
        installGraphics
      ;;
    "QEMU")
        echo "20. Setting up as QEMU Guest"
        setupAsQemuGuest
      ;;
    "VBOX")
        echo "20. Setting up as VirtualBox Guest"
        setupAsVBoxGuest
      ;;
    "HYPERV")
       echo "20. Setting up as Hyper-V Guest"
       setupAsHyperGuest
  esac
}

fourthInstallStage(){
  echo "21. : Generate Settings"
  generateSettings

  echo "22. Install Desktop Environment"
  installDesktopBase

  echo "23. Install yay - AUR package manager"
  makeYay

  echo "24. Install Base Goodies"
  installBaseGoodies

  echo "25. Install Desktop Goodies"
  installDesktopGoodies

  echo "26. Enable RDP"
  setupRDPServer

  echo "27. Readying final boot"
  readyFinalBoot

  echo "Script done. You're good to go after reboot."
  sleep 5
}

exportSettings(){
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}

  echo "Exporting $1=$2" 1>&2
  EXPORTPARAM="$1=$2"
  ## write all settings to a file on new root
  echo -e "$EXPORTPARAM" >> "$SCRIPTROOT/installsettings.cfg"
}

#retrieveSettings 'SETTINGNAME'
retrieveSettings(){
  SCRIPTPATH=$( readlink -m $( type -p $0 ))
  SCRIPTROOT=${SCRIPTPATH%/*}
  SETTINGSPATH="$SCRIPTROOT/installsettings.cfg"

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
  BOOTTYPE=$(retrieveSettings 'BOOTTYPE')
  ROOTMODE=$(retrieveSettings 'ROOTMODE')
  BOOTDEVICE=$(retrieveSettings 'BOOTDEVICE')
  ROOTDEVICE=$(retrieveSettings 'ROOTDEVICE')
  BOOTPART=$(retrieveSettings 'BOOTPART')
  ROOTPART=$(retrieveSettings 'ROOTPART')

  if [[ $BOOTTYPE = "EFI" ]]; then
    case $BOOTMODE in
      "LEAVE"|"FORMAT")
        echo "Leaving the boot partition..."
        ;;
      "CREATE")
        echo "Boot partition will be created. Whole disk will be destroyed!"
        DEVICE=$(echo $BOOTPART | sed 's/[0-9]//g')
        parted -s $DEVICE -- mklabel gpt \
              mkpart primary fat32 0% 256MiB
        ;;
    esac
  fi

    case $ROOTMODE in
      "LEAVE"|"FORMAT")
        echo "Leaving the root partition..."
        ;;
      "CREATE")
        DEVICE=$(echo $ROOTPART | sed 's/[0-9]//g')
        if [[ $BOOTTYPE = "EFI" ]]; then
          #If the root device matches the boot device, don't setup device label
          if [ $BOOTDEVICE = $ROOTDEVICE ]; then
            parted -s $DEVICE -- mkpart primary ext4 256MiB 100%
          else
            echo "Root partition will be created. Whole disk will be destroyed!"
            parted -s $DEVICE -- mklabel gpt \
                  mkpart primary ext4 0% 100%
          fi
        else
          echo "Root partition will be created. Whole disk will be destroyed!"
          parted -s $DEVICE -- mklabel mbr \
                mkpart primary ext4 0% 100% \
                set 1 boot on
        fi
        ;;
    esac
}

##FORMAT PARTITIONS

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

## Mount the file systems
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
  pacstrap /mnt base base-devel openssh git
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
  CPUTYPE=$(retrieveSettings 'CPUTYPE')
  systemctl enable sshd
  pacman -S --noconfirm refind-efi $CPUTYPE'-ucode'
  refind-install
  fixRefind
}

fixRefind(){
  ROOTPART=$(retrieveSettings 'ROOTPART')
  ROOTUUID=$(blkid | grep $ROOTPART | grep -oP '(?<= UUID=").*(?=" TYPE)')
  CPUTYPE=$(retrieveSettings 'CPUTYPE')

cat <<EOF > /boot/refind_linux.conf
"Boot with standard options"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=$CPUTYPE-ucode.img initrd=initramfs-linux.img"
"Boot using fallback initramfs"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=$CPUTYPE-ucode.img initrd=initramfs-linux-fallback.img"
"Boot to terminal"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=$CPUTYPE-ucode.img initrd=initramfs-linux.img systemd.unit=multi-user.target"
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
installGraphics(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  GPUTYPE=$(retrieveSettings 'GPUTYPE')
  enableMultilibPackages

  case $GPUTYPE in
    "nvidia" )
        sudo pacman -S --noconfirm nvidia lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader nvidia-settings
      ;;
  esac

  echo "FOURTH" > $SCRIPTROOT/installer.cfg
}


######################################## Install DE
installDesktopBase(){
  DESKTOP=$(retrieveSettings 'DESKTOP')
  case $DESKTOP in
    "KDE" )
      sudo pacman -S --noconfirm plasma kcalc konsole spectacle dolphin dolphin-plugins filelight kate kwalletmanager kdeconnect kdf kdialog kfind
      sudo systemctl enable sddm
      ;;
    "XFCE" )
      sudo pacman -S --noconfirm xfce4 xfce4-goodies lxdm
      sudo systemctl enable lxdm
      ;;
  esac
}

###### make yay
makeYay(){
  USERNAME=$(retrieveSettings "USERNAME")

  cd /home/$USERNAME
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -sri --noconfirm
  cd /home/$USERNAME
}

#TODO
setupRDPServer(){
  USERNAME=$(retrieveSettings "USERNAME")
  DESKTOP=$(retrieveSettings "DESKTOP")
  SESHNAME=""
  yay -S --noconfirm xrdp-git xorgxrdp-git xorg-xinit xterm
  sudo sytemctl enable xrdp xrdp-sesman
  #cp /etc/X11/xinit/xinitrc ~/.xinitrc
  echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
  case $DESKTOP in
    "KDE" ) $SESHNAME = "startkde"
      ;;
    "XFCE" ) $SESHNAME = "startxfce4"
      ;;
  esac

  echo "exec dbus-run-session -- $SESHNAME" > /home/$USERNAME/.xinitrc
  sudo sed -i "s/use_vsock=true/use_vsock=false/" /etc/pacman.conf
}

installBaseGoodies(){
  INSTALLTYPE=$(retrieveSettings "INSTALLTYPE")
  case $INSTALLTYPE in
    "PHYS" )
        yay -S --noconfirm fwupd virtualbox virtualbox-host-modules-arch virtualbox-guest-iso remmina freerdp-git protonmail-bridge gscan2pdf spotify libreoffice-fresh discord filezilla vlc obs-studio thunderbird gimp steam cups cups-pdf tesseract tesseract-data-eng pdftk-bin pulseaudio-bluetooth
        sudo systemctl enable org.cups.cupsd
        sudo systemctl enable bluetooth
      ;;
    "HYPERV" )
        git clone https://github.com/Microsoft/linux-vm-tools
      	cd linux-vm-tools/arch
      	yay -S --noconfirm xrdp-git
      	./makepkg.sh
      	cd ~/linux-vm-tools/arch
      	sudo ./install-config.sh
      	cd ~
      	cp /etc/X11/xinit/xinitrc ~/.xinitrc
      ;;
  esac

  yay -S --noconfirm gparted ntfs-3g htop nextcloud-client papirus-icon-theme rsync ttf-roboto filezilla visual-studio-code-bin putty networkmanager-openvpn firefox gnome-keyring wget okular masterpdfeditor-free
}

installDesktopGoodies(){
  DESKTOP=$(retrieveSettings 'DESKTOP')

  case $DESKTOP in
    "KDE" )
      yay -S --noconfirm packagekit-qt5 adapta-kde kvantum-theme-adapta ffmpegthumbs ark gwenview print-manager adapta-gtk-theme
    ;;
    "XFCE" )
      yay -S --noconfirm networkmanager network-manager-applet adapta-gtk-theme
    ;;
  esac
}

######################################## Setup install as a virtualbox guest
setupAsVBoxGuest(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  enableMultilibPackages
  sudo pacman -S --noconfirm virtualbox-guest-utils
  sudo systemctl enable vboxservice.service
  echo "\"FS0:\EFI\refind\refind_x64.efi\"" | sudo tee -a /boot/startup.nsh
  echo "FOURTH" > $SCRIPTROOT/installer.cfg
}

setupAsQemuGuest(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  enableMultilibPackages

  sudo sed -i "s/MODULES=()/MODULES=(virtio virtio_blk virtio_pci virtio_net)/" /etc/mkinitcpio.conf
  sudo mkinitcpio -p linux
  sudo pacman -S --noconfirm qemu-guest-agent
  sudo systemctl enable qemu-ga.service
  echo "FOURTH" > $SCRIPTROOT/installer.cfg
}

setupAsHyperGuest(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  enableMultilibPackages
  sudo pacman -S --noconfirm xf86-video-fbdev
  echo "FOURTH" > $SCRIPTROOT/installer.cfg
}

############ enable network manager/disable dhcpcd
readyFinalBoot(){
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  NETINT=$(retrieveSettings 'NETINT')
  sudo systemctl disable dhcpcd@$NETINT.service
  sudo systemctl disable sshd
  sudo systemctl enable NetworkManager
  echo "DONE" > $SCRIPTROOT/installer.cfg
  ###### Remove no password for sudoers
  sudo sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
}

#Start the script
driver

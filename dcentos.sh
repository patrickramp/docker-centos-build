#!/bin/bash
clear
echo "** Important Please Read! **"
echo "This script is designed to provision a secure Docker host on CentOS-9 ONLY."
echo "Please make sure you are using a fresh, fully updated version of CentOS and longed in as root."
read -r -p "Do you wish to proceed? [y/N]: " start
if [[ "$start" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  echo "Proceeding"
else
  echo "Exiting script, goodbye."
  exit 1
fi

# Set hostname.
read -r -p "Please enter desired hostname: " hostname
hostnamectl set-hostname "$hostname"

# Set system timezone.
read -r -p "Please enter desired timezone: " timezone
timedatectl set-timezone "$timezone"

#Add user account, add user to wheel group.
read -r -p "Please enter desired admin username: " username
adduser "$username"
passwd "$username"
usermod -aG wheel "$username"

# Create swapfile.
read -r -p "Do you wish to create a swapfile? [y/N]: " swapyn
if [[ "$swapyn" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  read -r -p "How many GB do you wish to use for the swapfile? " swapsize
  fallocate -l "$swapsize"G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  # Backup and update fstab for swap persistence.
  cp -p /etc/fstab /etc/fstab.orig
  echo '/swapfile   swap    swap    sw  0 0' >> /etc/fstab
fi

# Set swappiness and cache pressure to optimize ram usage.
echo 'vm.swappiness = 05' >> /etc/sysctl.conf
echo 'vm.vfs_cache_pressure = 80' >> /etc/sysctl.conf

# Verify swap, swappiness and cache pressure settings.
echo "Review swap, swappiness and cache_pressure settings. These are pre-set to optimize ram usage but can be changed later."
swapon --show
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure
read -r -p "Press any key to continue"

# Install EPEL repo on CentOS and update.
echo "Installing EPEL repo on CentOS and updating."
dnf install epel-release $$ sudo dnf update -y

# Install security applications and utilities.
echo "Installing SELinux utils, fail2ban firewalld and nano."
dnf install policycoreutils-python-utils fail2ban firewalld fail2ban-firewalld nano -y

# Update ssh port to something other than 22.
echo "Update ssh port to something other than 22, between 1024 and 65535."
read -r -p "Enter desired ssh port: " sshport

# Update ssh port in sshd_config file and restart sshd_config.
echo "Port $sshport" >> /etc/ssh/sshd_config.d/sshport.conf
service sshd_config restart

# Add and Update SELinux ssh port.
semanage port -a -t ssh_port_t -p tcp "$sshport"
semanage port -m -t ssh_port_t -p tcp "$sshport"

# Add new ssh port to firewalld enable http/s service to firewalld, reload and enable.
firewall-cmd --permanent --zone=public --add-port="$sshport"/tcp
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload
systemctl enable firewalld

# Add firewalld to fail2ban banaction.
mv /etc/fail2ban/jail.d/00-firewalld.conf /etc/fail2ban/jail.d/00-firewalld.local
# Fail2ban config for ssh.
printf "[sshd]\nenabled = true\nport = %port\nfindtime = 30m\nbantime = 15m\nmaxretry = 4" "$sshport" >> /etc/fail2ban/jail.d/sshd_config.local
systemctl start fail2ban
systemctl enable fail2ban

# Uninstall old versions of docker podman and buildah to avoid repo confilicts.
echo "Uninstalling old versions of docker podman and buildah to avoid repo confilicts."
dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman buildah runc

# Add Docker repositories and update.
echo "Adding Docker Repositories and updating."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf update

# Install Docker and Docker Compose packages.
echo "Installing Docker and Docker Compose packages."
echo "Docker GPG Key 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35"
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker and set to start at reboot
echo "Starting Docker enable starting at reboot."
systemctl start docker
systemctl enable docker

# Enable automatic updates.
read -r -p "Do you wish to enable automatic updates? [y/N]: " autoyn
if [[ "$autoyn" =~ ^([yY][eE][sS]|[yY])$ ]]
then
# Add DNF automatic updates
dnf install dnf-automatic

# Configure updates
nano /etc/dnf/automatic.conf

# Turn on update automatic service.
systemctl enable --now dnf-automatic.timer
fi

# Parting remarks.
echo "All done! Dont forget to reboot and set up ssh keys."
exit 0

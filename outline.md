
# CentOS-9 Docker Server Config #
 ```bash
 
 # Set hostname
hostnamectl set-hostname $myserver

# Set System Timezone
sudo timedatectl set-timezone America/New_York

# Create 2GB swapfile
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Backup fstab and add swapfile for persistance.
cp -p /etc/fstab /etc/fstab.orig
vi /etc/fstab
>> /swapfile   swap    swap    sw  0 0

# Set swap and Cache Pressure to optimize ram usage.
echo 'vm.swappiness = 05' >> /etc/sysctl.conf
echo 'vm.vfs_cache_pressure = 80' >> /etc/sysctl.conf

#Add user account, add user to sudo group.
adduser $username
passwd $username
usermod -aG wheel $username
visudo
## Look for this line:
## Allow root to run any commands anywhere
root      ALL=(ALL)       ALL
$username ALL=(ALL)       ALL    # < Add this line#

# Verify root
su $username
sudo whoami

# Full system update and reboot.
sudo dnf update -y
sudo reboot

# Verify swap, swappiness and cache pressure
swapon --show
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure

# Install EPEL repo on CentOS and update.
sudo dnf install epel-release $$ sudo dnf update -y

# (Optional) Install commonly used application
sudo dnf install nano btop

# Install SELinux utils
sudo dnf install policycoreutils-python-utils

# Update SELinux ssh port to something other than 22
sudo semanage port -a -t ssh_port_t -p tcp 2222

# Import SSH Keys to user home dir.
sudo mkdir ./.ssh
sudo nano ./.ssh/authorized_keys
>> $SSH_keys.pub

# Set user permissions for ~/.ssh directory 'R'ecursively
chmod -R 700 ~/.ssh

# Backup and configure SSH rules /etc/ssh/sshd_config
sudo cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
sudo nano /etc/ssh/sshd_config
## See Config file ##

# Uninstall old versions of docker podman and buildah to avoid repo confilicts
sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman buildah runc

# Add Docker Repositories and update
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf update

# Install Docker and Docker Compose pkgs
sudo dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin
## Verify GPG key 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35 ##

# Start Docker and set to start at reboot
sudo systemctl start docker
sudo systemctl enable docker.service

# Add DNF automatic updates
sudo dnf install dnf-automatic

# Configure updates
sudo nano /etc/dnf/automatic.conf

# Turn on update automatic serverice
sudo systemctl enable --now dnf-automatic.timer
 
 
 ```
 
 
 
 
#!/bin/bash

# Splash warning and disclaimer text.
clear
echo "** Important Please Read! **"
echo "This script is intended for use on a RHEL 9 based distro."
echo "It will install fail2ban and optionally docker, dnf-automatic."
echo "Please make sure you are using a fresh install and logged in as root."
read -r -p "Do you wish to proceed? [y/N]: " start
if [[ "$start" =~ ^([yY][eE][sS]|[yY])$ ]] 
then
  echo "Proceeding..."
  sleep 1
else
  echo "Exiting script, goodbye."
  exit 1
fi

# Function to print colored success messages.
print_success() {
    local message=$1
    echo -e "\e[32m$message\e[0m"
}
# Function to print colored action messages.
print_action() {
    local command=$1
    echo -e "\e[33m$command\e[0m"
}

# Add user account, add user to wheel group.
read -r -p "Please enter desired admin username: " username

# Check if user already exists
if id "$username" >/dev/null 2>&1; 
then
  echo "User $username already exists."
else
  sudo useradd -m -k /empty_skel "$username"
fi

# Add user to wheel group.
usermod -aG wheel "$username"
print_success "[Success] User $username created/exists and added to wheel group."

# Set password for user account.
passwd "$username"

# Verify passwd command succeeded.
if [ $? -eq 0 ]; 
then
  print_success "[Success] Password set for $username."
else
  print_success "[Faild] to set password for $username."
  exit 1
fi

# Move root authorized_keys to new user.
read -r -p "Move root authorized_keys to new user? [y/N]: " swapyn
if [[ "$swapyn" =~ ^([yY][eE][sS]|[yY])$ ]] 
then
print_action "Moving root SSH keys to new user."
mkdir -p /home/$username/.ssh
mv /root/.ssh/authorized_keys /home/$username/.ssh/authorized_keys
chown -R $username:$username /home/$username/.ssh
chmod 700 /home/$username/.ssh
chmod 600 /home/$username/.ssh/authorized_keys
print_success "[Success]"
fi

# Set hostname.
read -r -p "Please enter desired hostname: " hostname
hostnamectl set-hostname "$hostname"
print_success "[Success] Hostname set to $hostname."

# Set system timezone.
read -r -p "Please enter desired timezone [America/New_York]: " timezone
# Set default timezone if none is entered
if [ -z "$timezone" ]; 
then
  timezone="America/New_York"
fi
timedatectl set-timezone "$timezone"
print_success "[Success] Timezone set to $timezone."

# Create swapfile.
read -r -p "Create a swapfile? [y/N]: " swapyn
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

print_action "Optimizing swappiness and cache pressure."
# Set swappiness and cache pressure to optimize ram usage.
echo 'vm.swappiness = 10' >> /etc/sysctl.conf
echo 'vm.vfs_cache_pressure = 50' >> /etc/sysctl.conf
print_success "[Success]"

# Verify swap, swappiness and cache pressure settings.
echo "Review swap, swappiness, and cache_pressure settings. These are pre-set to optimize ram usage but can be changed later in /etc/sysctl.conf"
swapon --show
sudo sysctl -p
read -r -p "Press any key to continue"

# Install EPEL repo on CentOS and update.
print_action "Installing EPEL repo on CentOS and updating."
dnf install epel-release -y 
dnf update -y
print_success "[Success]"

# Install security-utils, firewalld, and fail2ban.
print_action "Installing security-utils, fail2ban, and firewalld."
dnf install policycoreutils-python-utils fail2ban firewalld fail2ban-firewalld -y
systemctl start firewalld
systemctl enable firewalld
systemctl start fail2ban
systemctl enable fail2ban
echo "Firewalld version"
firewall-cmd --version
echo "Fail2ban version"
fail2ban-client --version
print_success "[Success]"

# Update SSH port.
echo "Select desired SSH port number, between 1024 and 65535."
read -r -p "Port= " sshport

# Update SSH port in sshd_config.d file and restart sshd_config.
print_action "Updating SSH port and authentication methods in sshd_config. /etc/ssh/sshd_config.d/ssh.conf"
cat << EOF > /etc/ssh/sshd_config.d/ssh.conf

# Custom SSH Configuration for $hostname
Protocol 2
Port $sshport 

PermitRootLogin no
PasswordAuthentication no

MaxAuthTries 3 
MaxSessions 5
LoginGraceTime 30

AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no

EOF

print_success "[Success] Restarting sshd."
systemctl restart sshd

# Add and Update SELinux ssh port.
print_action "Updating SSH port in SELinux."
semanage port -a -t ssh_port_t -p tcp "$sshport"
semanage port -m -t ssh_port_t -p tcp "$sshport"
print_success "[Success]"

# Add new ssh port to firewalld enable http/s service to firewalld, reload and enable.
print_action "Updating ports on Firewalld."
echo "Remove default SSH port 22."
firewall-cmd --permanent --zone=public --remove-service=ssh
echo "Enabe SSH on port $sshport."
firewall-cmd --permanent --zone=public --add-port="$sshport"/tcp
echo "Enabe http on port 80."
firewall-cmd --permanent --zone=public --add-service=http
echo "Enabe https on port 442."
firewall-cmd --permanent --zone=public --add-service=https
echo "Reload and enable firewalld."
firewall-cmd --reload
print_success "[Success]"

# Configure Fail2ban.
print_action "Configuring Fail2ban custom SSH rules /etc/fail2ban/jail.d/sshd.local"
# Copy default jail.config to jail.local.
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Add sshd config to fail2ban/jail.d/sshd.local.
cat << EOF > /etc/fail2ban/jail.d/sshd.local

[sshd]
enabled = true
port = $sshport
maxretry = 5
bantime = 24h
findtime = 24h

banaction = firewallcmd-rich-rules[actiontype=<muliport>]
banaction_allports = firewallcmd-rich-rules[actiontype=<allport>]

EOF

# Restart Fail2ban
systemctl restart fail2ban
print_success "[Success]"

# Install Docker.
read -r -p "Install Docker? [y/N]: " swapyn
if [[ "$swapyn" =~ ^([yY][eE][sS]|[yY])$ ]] 
then
  # Uninstall old versions of docker podman and buildah to avoid repo confilicts.
  print_action "Uninstalling old versions of docker podman and buildah to avoid repo confilicts."
  dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman buildah runc -y
  print_success "[Success]"

  # Add Docker repositories and update.
  print_action "Adding Docker Repositories and updating."
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  dnf update
  print_success "[Success]"

  # Install Docker and Docker Compose packages.
  print_action "Installing Docker and Docker Compose packages."
  print_action "Verify Docker GPG Key 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35"
  dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
  print_success "[Success]"

  # Start Docker and set to start at reboot
  print_action "Starting Docker and setting to start at boot."
  systemctl start docker
  systemctl enable docker
  print_success "[Success]"
fi

# Enable automatic updates.
read -r -p "Install and enable automatic updates? [y/N]: " autoyn
if [[ "$autoyn" =~ ^([yY][eE][sS]|[yY])$ ]] 
then
  # Install DNF automatic updates
  dnf install dnf-automatic -y

  # Configure updates
  read -r -p "Configure automatic updates? [y/N]: " autoyn
  if [[ "$autoyn" =~ ^([yY][eE][sS]|[yY])$ ]] 
  then
    systemctl edit dnf-automatic

    # Configure automatic updates timer
    read -r -p "Change automatic updates timer? [06:00 daily] [y/N]: " autoyn
    if [[ "$autoyn" =~ ^([yY][eE][sS]|[yY])$ ]] 
    then
      systemctl edit dnf-automatic.timer
    fi
  fi

  # Turn on update automatic service.
  systemctl start dnf-automatic
  systemctl enable dnf-automatic.timer
  print_success "[Success] automatic updates enabled."
fi

# Install additional packages.
read -r -p "Install additional packages [y/N]: " swapyn
if [[ "$swapyn" =~ ^([yY][eE][sS]|[yY])$ ]] 
then
  read -r -p "List packages to install? [tmux nvim btop]: " install 
  if [ -z "$install" ];
  then
    print_action "Installing additional packages."
    dnf install tmux nvim btop -y
    print_success "[Success] additional packages installed."
  else
    dnf install $install -y
  fi
fi

# Parting remarks.
print_action "All done! Dont forget to reboot into your new user and disable root login. # sudo passwd -l root"
read -r -p "Press any key to exit."
exit 0


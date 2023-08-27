
# CentOS-9 Stream Docker Server Config Outline

## This is an outline of the intended functionality of the script.
 
- Set hostname.
- Set system timezone.
- Add admin user to wheel group.
- Create swapfile.
  - Backup and update fstab for swap persistence.
- Set swappiness and cache pressure to optimize ram usage.
- Verify swap, swappiness and cache pressure settings.
- Install EPEL repo on CentOS and update.
- Install security applications and utilities.
- Update ssh port to something other than 22.
  - Update ssh port in sshd_config file and restart sshd.
  - Add and Update SELinux ssh port.
  - Add new ssh port to firewalld enable http/s service to firewalld, reload and enable.
  - Add firewalld to fail2ban banaction.
    - Fail2ban config for ssh.
 - Uninstall old versions of docker podman and buildah to avoid repo confilicts.
 - Add Docker repositories and update.
 - Install Docker and Docker Compose pkgs
 - Start Docker and set to start at reboot
 - Enable automatic updates.
 - Add DNF automatic updates
   - Configure updates
   - Turn on update automatic service.
 - Parting remarks.


"Still need configuration to figure out how to." 

```bash
# Import SSH Keys to user home dir.
./.ssh/authorized_keys
>> $SSH_keys.pub

# Set user permissions for ~/.ssh directory 'R'ecursively
chmod -R 700 ~/.ssh

# Backup and configure SSH config /etc/ssh/sshd_config
sudo cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
sudo nano /etc/ssh/sshd_config
## See Config file ##

# Some user land sruff not done as root.

# Create a sshd config file 

 '''
 
 
 
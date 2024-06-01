
# RHEL9 Docker Server Config Outline

## This is an outline of the script fucntions.
 
- Set hostname.
- Set system timezone.
- Create admin user in wheel group.
- Set secure admin password.
- Move root SSH authorized_keys file to new admin user home dir.
- Secure shared memory.
- Disable unused network services.
- Create swapfile.
- Set swappiness and cache pressure to optimize ram usage.
- Verify swap, swappiness and cache pressure settings.
- Install EPEL repo on CentOS and update.
- Install security applications and utilities.
- Update SSH port.
  - Update SSH port and authentication method in ssh.conf.
  - Add and Update SELinux ssh port.
  - Add update SSH port and enable http/s services in firewalld, reload.
- Create Fail2ban jail for ssh and link to firewalld.
- Install Docker and Docker Compose
  - Uninstall old versions of docker podman and buildah to avoid repo confilicts.
  - Add Docker repositories and update.
  - Install Docker and Docker Compose pkgs
  - Configure Docker daemon security.
  - Start Docker and set to start at reboot
- Enable automatic updates.
  - Add DNF automatic updates
  - Configure update preferences
  - Configure update timer service.
- Install optional utilities.
- Parting remarks.
 

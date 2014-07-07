#!/bin/bash

# Google Reference: https://developers.google.com/compute/docs/images#buildingimage

CU=$(id -u -n)
echo "Running Google Image Prep as ${CU}"

# Update APT cache, upgrade packages
sudo apt-get update && sudo apt-get -yq upgrade

# Install mandatory software
sudo apt-get install -yq openssh-server python vim ntp sed

# Set timezone to UTC
sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Setting up ntp
sudo sed -i -e '/^server/d' /etc/ntp.conf ## Removes all previously defined `server` statements.
echo 'server metadata.google.internal' | sudo tee -a /etc/ntp.conf

# Log syslog messages to /dev/ttyS0, so you can debug with gcutil getserialportoutput
cat <<EOF | sudo tee /etc/init/ttyS0.conf
# ttyS0 - getty
start on stopped rc or RUNLEVEL=[2345]
stop on runlevel [!2345]
respawn
exec /sbin/getty -L 115200 ttyS0 vt102
EOF

sudo sed -i 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 ignore_loglevel"\nGRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"/' /etc/default/grub
sudo sed -i 's/^#GRUB_TERMINAL=console/GRUB_TERMINAL=console/' /etc/default/grub


# Add Required Linux Kernel Options
cat <<EOF | sudo tee -a /etc/default/grub

# to enable paravirtualization functionality.
CONFIG_KVM_GUEST=y

# to enable the paravirtualized clock.
CONFIG_KVM_CLOCK=y

# to enable paravirtualized PCI devices.
CONFIG_VIRTIO_PCI=y

# to enable access to paravirtualized disks.
CONFIG_SCSI_VIRTIO=y

# to enable access to the networking.
CONFIG_VIRTIO_NET=y
EOF


# Update grub after all of our changes
sudo /usr/sbin/update-grub2


# Disable IPv6
cat <<EOF | sudo tee /etc/sysctl.d/11-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF


# Removing hostname, adding internal hosts
sudo rm /etc/hostname
cat <<EOF | sudo tee /etc/hosts
127.0.0.1 localhost
169.254.169.254 metadata.google.internal metadata
EOF


# Install GCE specific software
wget -q https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.4/google-startup-scripts_1.1.4-1_all.deb
sudo dpkg -i google-startup-scripts_1.1.4-1_all.deb
sudo apt-get install -f -yq
wget -q https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.4/python-gcimagebundle_1.1.4-1_all.deb
sudo dpkg -i python-gcimagebundle_1.1.4-1_all.deb
sudo apt-get install -f -yq
wget -q https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.4/google-compute-daemon_1.1.4-1_all.deb
sudo dpkg -i google-compute-daemon_1.1.4-1_all.deb
sudo apt-get install -f -yq


# Install gcloud utilities
sudo mkdir -p /opt/google
pushd /opt/google
sudo wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz
sudo tar zxf google-cloud-sdk.tar.gz
pushd google-cloud-sdk
sudo CLOUDSDK_CORE_DISABLE_PROMPTS=1 ./install.sh --disable-installation-options --path-update=true --bash-completion=true --rc-path=/etc/bash.bashrc
popd
popd


# Remove sshd host keys
sudo rm -f /etc/ssh/ssh_host_key
sudo rm -f /etc/ssh/ssh_host_*_key*

# Reconfigure sshd
sudo sed -r -i -e "s/#?PermitRootLogin without-password/PermitRootLogin no/g" /etc/ssh/sshd_config
sudo sed -r -i -e "s/#?PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
sudo sed -r -i -e "s/#?X11Forwarding yes/X11Forwarding no/g" /etc/ssh/sshd_config
cat <<EOF | sudo tee -a /etc/ssh/sshd_config
PermitTunnel no
AllowTcpForwarding yes
ClientAliveInterval 420
UseDNS no
EOF
echo "GOOGLE" | sudo tee /etc/ssh/sshd_not_to_be_run

cat <<EOF | sudo tee /etc/ssh/ssh_config
Host *
Protocol 2
ForwardAgent no
ForwardX11 no
HostbasedAuthentication no
StrictHostKeyChecking no
Ciphers aes128-ctr,aes192-ctr,aes256-ctr,arcfour256,arcfour128,aes128-cbc,3des-cbc
Tunnel no

# Google Compute Engine times out connections after 10 minutes of inactivity.
# Keep alive ssh connections by sending a packet every 7 minutes.
ServerAliveInterval 420
EOF

# Lock root user
sudo /usr/sbin/usermod -L root

# Disable CAP_SYS_MODULE
echo 1 | sudo tee > /proc/sys/kernel/modules_disabled

# Remove System.map
sudo rm /boot/System.map*

# Fix sysctl values
cat <<EOF | sudo tee /etc/sysctl.d/12-gce-strongly-recommended.conf
# enables syn flood protection
net.ipv4.tcp_syncookies = 1

# ignores source-routed packets
net.ipv4.conf.all.accept_source_route = 0

# ignores source-routed packets
net.ipv4.conf.default.accept_source_route = 0

# ignores ICMP redirects
net.ipv4.conf.all.accept_redirects = 0

# ignores ICMP redirects
net.ipv4.conf.default.accept_redirects = 0

# ignores ICMP redirects from non-GW hosts
net.ipv4.conf.all.secure_redirects = 1

# ignores ICMP redirects from non-GW hosts
net.ipv4.conf.default.secure_redirects = 1

# don't allow traffic between networks or act as a router
net.ipv4.ip_forward = 0

# don't allow traffic between networks or act as a router
net.ipv4.conf.all.send_redirects = 0

# don't allow traffic between networks or act as a router
net.ipv4.conf.default.send_redirects = 0

# reverse path filtering - IP spoofing protection
net.ipv4.conf.all.rp_filter = 1

# reverse path filtering - IP spoofing protection
net.ipv4.conf.default.rp_filter = 1

# reverse path filtering - IP spoofing protection
net.ipv4.conf.default.rp_filter = 1

# ignores ICMP broadcasts to avoid participating in Smurf attacks
net.ipv4.icmp_echo_ignore_broadcasts = 1

# ignores bad ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# logs spoofed, source-routed, and redirect packets
net.ipv4.conf.all.log_martians = 1

# log spoofed, source-routed, and redirect packets
net.ipv4.conf.default.log_martians = 1

# implements RFC 1337 fix
net.ipv4.tcp_rfc1337 = 1

# randomizes addresses of mmap base, heap, stack and VDSO page
kernel.randomize_va_space = 2
EOF

cat <<EOF | sudo tee /etc/sysctl.d/13-gce-recommended.conf
# provides protection from ToCToU races
fs.protected_hardlinks=1

# provides protection from ToCToU races
fs.protected_symlinks=1

# makes locating kernel addresses more difficult
kernel.kptr_restrict=1

# set ptrace protections
kernel.yama.ptrace_scope=1

# set perf only available to root
kernel.perf_event_paranoid=2
EOF


# Upstart scripts
cat <<EOF | sudo tee /etc/init/prep-set-hostname.conf
start on (starting ssh or starting sshd)

# this is a task, so only run once
task

script
  # set hostname to the one returned by the google metadata server
  hostname \`/usr/share/google/get_metadata_value hostname\`
end script
EOF

cat <<EOF | sudo tee /etc/init/prep-remove-bootstrap.conf
start on (starting ssh or starting sshd)

# this is a task, so only run once
task

script
  # delete bootstrap user
  userdel -f -r bootstrap
  rm /etc/init/prep-remove-bootstrap.conf
end script
EOF

initctl reload-configuration


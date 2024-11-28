#!/bin/bash

############################################
# PLEASE RUN THIS AS ROOT USER !           #
# AND DON'T FORGET TO SET THE PERMISSION   #
# ---------------------------------------- #
# Cilogs - A Centralized Log Server        #
# Automation Script                        #
# ---------------------------------------- #
# Author:                                  #
# 1. Adryan Usfirahiman                    #
# 2. Dafi Nafidz Radhiyya                  #
# 3. Jerry Jardianto                       #
# 4. Wahyu Priambodo                       #
# 5. Wilsen Lau                            #
# ---------------------------------------- #
# Tested on: RHEL 9.0 & UBI 9 Image        #
# ---------------------------------------- #
# Created at: Nov 27, 2024                 #
# ---------------------------------------- #
# Run this script with this commands:      #
# 1. su -                                  #
# 2. chmod a+x setup.sh                    #
# 3. ./setup.sh                            #
############################################

# Display the banner
show_banner() {
    banner="
       __ __                    
.----.|__|  |.-----.-----.-----.
|  __||  |  ||  _  |  _  |__ --|
|____||__|__||_____|___  |_____|
                   |_____|      
"
    echo -e "$banner\n"
} 

# Configure NTP server and set server time to cloudflare
config_ntp() {
    # Configure NTP server on workstation (node 2)
    echo "[+] Configuring NTP server..."
    sed -i 's|pool 2.centos.pool.ntp.org iburst|server time.cloudflare.com iburst|g' /etc/chrony.conf
    systemctl restart chronyd
    chronyc sources
    echo -e "[+] Done.\n"
}

# Update the repo and install some dependencies
install_deps() {
    echo "[+] Installing dependencies ..."
    dnf install -y container-tools autofs
    echo -e "[+] Done.\n"
}

# Configure the RHEL repository
config_repo() {
    # Add repo to RHEL
    echo "[+] Add CentOS Stream repository ..."
    dnf config-manager --add-repo "https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/"
    dnf config-manager --add-repo "https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/"
    dnf repolist all
    echo -e "[+] Done.\n"

    # Set the 'gpgcheck' to 0
    echo "[+] Setting gpgcheck to 0..."
    echo "gpgcheck=0" >> /etc/yum.repos.d/mirror.stream.centos.org_9-stream_BaseOS_x86_64_os_.repo
    echo "gpgcheck=0" >> /etc/yum.repos.d/mirror.stream.centos.org_9-stream_AppStream_x86_64_os_.repo
    echo -e "[+] Done.\n"
}

# Setup container for node 1 and node 3
setup_ctr() {
    echo "[+] Setting up the container for node 1 and node 3 ..."
    # Create a container network
    podman network create --subnet 192.168.1.0/24 --gateway 192.168.1.1 wazuh-net

    # Pull the `ubi9-init` image
    podman pull docker.io/redhat/ubi9-init

    # Create mount point for node 1
    mkdir -p /node1/log

    # Configure fcontext of mount point node 1
    semanage fcontext -a -t container_file_t "/node1/log(/.*)?"
    restorecon -RFvv /node1/log

    # Create and run the container for node 1
    podman run -d --name node1-ctr --hostname node1 --network wazuh-net -p 2221:22 \
    -v /node1/log:/var/log:Z --privileged docker.io/redhat/ubi9-init /sbin/init

    # Configure fcontext of mount point
    semanage fcontext -a -t container_file_t "/node3/log(/.*)?"
    restorecon -RFvv /node3/log

    # Create and run the container for node 3
    podman run -d --name node3-ctr --hostname node3 --network wazuh-net -p 2222:22 -p 2049:2049/tcp \
    -v /node3/log:/var/log:Z -v /var/ossec/logs:/${BACKUP_MOUNT_POINT}:Z --privileged \
    docker.io/redhat/ubi9-init /sbin/init

    # Install sshd on node 1 and node 3
    podman exec -it node1-ctr /bin/bash -c "dnf install -y openssh-server iputils vim net-tools ncurses rsyslog openssh-clients"
    podman exec -it node3-ctr /bin/bash -c "dnf install -y openssh-server iputils vim net-tools ncurses rsyslog openssh-clients"

    # Start the sshd service
    podman exec -it node1-ctr /bin/bash -c "systemctl enable --now sshd"
    podman exec -it node3-ctr /bin/bash -c "systemctl enable --now sshd"

    # Start the rsyslog service
    podman exec -it node1-ctr /bin/bash -c "systemctl enable --now rsyslog"
    podman exec -it node3-ctr /bin/bash -c "systemctl enable --now rsyslog"

    # Change PermitRootLogin to yes on node 1 and node 3
    podman exec -it node1-ctr /bin/bash -c 'sed -i "s|#PermitRootLogin prohibit-password|PermitRootLogin yes|g" /etc/ssh/sshd_config'
    podman exec -it node3-ctr /bin/bash -c 'sed -i "s|#PermitRootLogin prohibit-password|PermitRootLogin yes|g" /etc/ssh/sshd_config'

    # Restart the sshd service
    podman exec -it node1-ctr /bin/bash -c "systemctl restart sshd"
    podman exec -it node3-ctr /bin/bash -c "systemctl restart sshd"

    # Set the root password on node 1 and node 3
    podman exec -it node1-ctr /bin/bash -c "echo 'root:${ROOT_PASS_NODE1}' | chpasswd"
    podman exec -it node3-ctr /bin/bash -c "echo 'root:${ROOT_PASS_NODE3}' | chpasswd"

    echo -e "[+] Done.\n"
}

setup_wazuh_manager() {
    # Setup wazuh manager on workstation (NOT IN CONTAINER)
    # Download and run the wazuh central components installer script.
    # Current Wazuh version: 4.9 (CHANGE THIS IF NEEDED)
    echo "[+] Download and run the installer script..."
    curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh && bash ./wazuh-install.sh -a -i 
    if [[ $? -ne 0 ]]; then
        echo "[-] Failed to install Wazuh manager."
        exit 1
    else
        echo "[+] Wazuh manager installed successfully."
    fi

    # Setting the firewalld
    echo "[+] Setting the firewalld..."
    firewall-cmd --zone=public --permanent --add-port=443/tcp
    firewall-cmd --zone=public --permanent --add-port=1514/tcp
    firewall-cmd --zone=public --permanent --add-port=1515/tcp
    firewall-cmd --reload
    echo -e "[+] Done.\n"

    # Enable PermitRootLogin in workstation (Wazuh manager)
    echo "[+] Enabling PermitRootLogin in SSH configuration..."
    sed -i 's|#PermitRootLogin prohibit-password|PermitRootLogin yes|g' /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "[+] Done.\n"

    # Set the root password to 'rootpw'
    echo "[+] Setting the root password for node 2..."
    echo "root:${ROOT_PASS_NODE2}" | chpasswd
    echo -e "[+] Done.\n"
}

main() {
    show_banner # Display the banner
    config_ntp # configure NTP server for node 2 (Wazuh manager)
    config_repo # configure the RHEL repository for node 2 (Wazuh manager)
    install_deps # install dependencies for node 2 (Wazuh manager)
    setup_wazuh_manager # setup Wazuh manager on node 2 (Wazuh manager)
    setup_ctr # setup container for node 1 and node 3

    echo "[+] Setup completed."
    echo "[!] Don't forget to copy the password of Wazuh manager."
    echo "[!] Root password has been set on each nodes!"
    echo "[+] Thank you!"
}

main # Run main function
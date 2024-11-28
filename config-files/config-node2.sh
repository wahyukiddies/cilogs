#!/bin/bash

######################################
# THIS SCRIPT IS TO CONFIGURE NODE 2 #
######################################

# Load and export the environment variables
set a; source ~/.env; set +a

# Configure RHEL repository
config_repo() {
    # Add repo to RHEL
    echo "[+] Adding CentOS Stream repository ..."
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

install_deps() {
    # Install required dependencies
    echo "[+] Installing required dependencies..."
    dnf install -y nfs-utils python3 python3-pip
    echo -e "[+] Done.\n"

    # Install Python packages
    echo "[+] Installing some python libraries..."
    pip3 install requests python-dotenv
    echo -e "[+] Done.\n"
}

setup_wazuh_manager() {
    # Setup wazuh manager on node 2 / workstation (NOT IN CONTAINER)
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
}

config_wazuh_manager() {
    echo "[+] Adding configuration script to /var/ossec/etc/ossec.conf file..."
    tee -a /var/ossec/etc/ossec.conf << EOF
<!-- Added by cilogs script -->
<ossec_config>
  <!-- Add an active response to block attacker incoming connection from alert level 10 -->
  <!-- Ref: https://documentation.wazuh.com/current/user-manual/capabilities/active-response/how-to-configure.html -->
  <active-response>
    <disabled>no</disabled>
    <!-- Drop incoming connection from attackers -->
    <command>firewall-drop</command>
    <!-- Protect the Wazuh agent -->
    <location>local</location>
    <!-- Block start from alert level 10 -->
    <level>10</level>
    <!-- Block for 24 hours -->
    <timeout>86400</timeout>
  </active-response>

  <!-- Change default alert level to 2 -->
  <!-- Ref: https://documentation.wazuh.com/current/user-manual/manager/alert-management.html#alert-management  -->
  <alerts>
    <!-- Change default alert from level 3 to level 2 -->
    <log_alert_level>2</log_alert_level>
  </alerts>

  <integration>
    <!-- Add custom integration for Telegram -->
    <name>custom-telegram</name>
    <!-- Send alert notification to Telegration start from alert level 10 -->
    <level>10</level>
    <!-- Using specified Telegram API token -->
    <hook_url>https://api.telegram.org/bot${TELEGRAM_API_TOKEN}/sendMessage</hook_url>
    <!-- Default format to send the notification is set to JSON -->
    <alert_format>json</alert_format>
  </integration>

  <!-- Enable archiving -->
  <global>
    <!-- Ref: https://documentation.wazuh.com/current/user-manual/manager/event-logging.html#log-compression-and-rotation -->
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>yes</logall>
    <logall_json>yes</logall_json>
  </global>
</ossec_config>
EOF

    # Move custom-telegram script to the integrations folder
    echo "[+] Moving 'custom-telegram' script to the integrations folder..."
    mv ~/custom-telegram/* /var/ossec/integrations/
    echo -e "[+] Done.\n"

    # Enable the archive to visualize the events on the dashboard
    # Ref: https://documentation.wazuh.com/current/user-manual/manager/event-logging.html#visualizing-the-events-on-the-dashboard
    echo "[+] Enabling the archive feature..."
    sed -i '/archives:/!b;n;c\      enabled: true' filebeat.yml
    echo -e "[+] Done.\n"

    # Restart the Wazuh manager
    echo "[+] Restarting Wazuh Manager..."
    systemctl restart wazuh-manager
    if [[ $? -eq 0 ]]; then
        echo "[+] Wazuh Manager has been restarted."
    else
        echo "[-] Failed to restart Wazuh Manager."
    fi
    echo -e "[+] Done.\n"
}

config_nfs_server() {
    echo "[+] Configuring NFS share..."

    # Add the directory to the exports file
    echo "/var/ossec/logs/ *(rw,sync)" > /etc/exports

    # Restart the NFS server
    exportfs -rav

    # Enable and start the NFS server
    systemctl enable --now nfs-server
    if [[ $? -eq 0 ]]; then
        echo "[+] NFS server has been configured successfully."
    else
        echo "[-] Failed to configure NFS server."
        exit 1
    fi

    # Check the NFS share 
    showmount -e localhost

    # Add service to firewalld (if enabled)
    systemctl is-enabled firewalld &> /dev/null
    if [[ $? -eq 0 ]]; then
        firewall-cmd --zone=public --add-service={mountd,nfs,rpc-bind} --permanent
        firewall-cmd --reload
    else
        echo "[-] Firewalld is not enabled. Skipping..."
    fi

    echo -e "[+] Done.\n"
}

main() {
    config_repo
    install_deps

    # Check if the Wazuh manager is already installed
    if [ -d /var/ossec/ ]; then
        echo "[-] Wazuh manager is already installed. Skipping..."
    else
        setup_wazuh_manager
    fi

    config_wazuh_manager
    config_nfs_server
}

main # run the main function
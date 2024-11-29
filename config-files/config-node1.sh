#!/bin/bash

######################################
# THIS SCRIPT IS TO CONFIGURE NODE 1 #
######################################

# Load and export the environment variables
set a; source ~/.env; set +a

# Configure RHEL repository
config_repo() {
    # Add repo to RHEL
    echo "[+] Adding CentOS Steam repository ..."
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

# Install Wazuh agent on node 1
install_wazuh_agent() {
    # Validate variable
    if [ -z "${IP_NODE2}" ]; then
        echo "[-] Required parameters for install Wazuh agent are missing. Check your configuration!."
        exit 1
    fi

    # Import the Wazuh repo GPG key 
    echo "[+] Importing Wazuh GPG key..."
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    echo -e "[+] Done.\n"

    # Add the Wazuh repo
    echo "[+] Adding official Wazuh repository..."
    cat > /etc/yum.repos.d/wazuh.repo << EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF
    echo -e "[+] Done.\n"

    # Deploy the Wazuh Agent on node 1
    echo "[+] Installing Wazuh agent..."
    WAZUH_MANAGER="${IP_NODE2}" dnf install -y wazuh-agent
    echo -e "[+] Done.\n"

    # Start the Wazuh agent service
    echo "[+] Starting Wazuh agent..."
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent
    echo -e "[+] Done.\n"

    # Recommended step in Wazuh official docs: Disable Wazuh updates
    echo "[+] Disabling Wazuh updates..." 
    sed -i "s|^enabled=1|enabled=0|" /etc/yum.repos.d/wazuh.repo
    echo -e "[+] Done.\n"
}

# Configure the Wazuh agent to send logs to the Wazuh manager
config_wazuh_agent() {
    # Send all logs from /var/log to the Wazuh manager
    echo "[+] Configuring wazuh agent..."
    tee -a /var/ossec/etc/ossec.conf << EOF
<!-- Added by cilogs script -->
<!-- Ref: https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/monitoring-log-files.html -->
<ossec_config>
  <!-- Log collection configuration -->
  <localfile>
    <location>/var/log/*</location>
    <log_format>syslog</log_format>
  </localfile>
</ossec_config>
EOF
    echo -e "[+] Done.\n"

    # Restart the Wazuh agent
    echo "[+] Restarting Wazuh agent..."
    systemctl restart wazuh-agent
    if [[ $? -eq 0 ]]; then
        echo "[+] Restart Wazuh agent success!"
    else
        echo "[-] Restart Wazuh agent failed!"
    fi

    echo -e "[+] Done.\n"
}

main() {
    config_repo 
    install_wazuh_agent 
    config_wazuh_agent 
}

main # run the main function
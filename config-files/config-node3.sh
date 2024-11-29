#!/bin/bash

######################################
# THIS SCRIPT IS TO CONFIGURE NODE 3 #
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

    # Set the `gpgcheck` to 0
    echo "[+] Setting gpgcheck to 0..."
    echo "gpgcheck=0" >> /etc/yum.repos.d/mirror.stream.centos.org_9-stream_BaseOS_x86_64_os_.repo
    echo "gpgcheck=0" >> /etc/yum.repos.d/mirror.stream.centos.org_9-stream_AppStream_x86_64_os_.repo
    echo -e "[+] Done.\n"
}

install_deps() {
    # Install required dependencies
    echo "[+] Installing required dependencies..."
    dnf install -y autofs gnupg2
    echo -e "[+] Done.\n"
}

config_autofs() {
    # Validate variables
    if [[ -z "${IP_NODE2}" || -z "${BACKUP_MOUNT_POINT}" ]]; then
        echo "[-] Required parameters to configure autofs are missing. Check your configuration!."
        exit 1
    fi

    # Check if backup mount point exists
    if [ ! -d "${BACKUP_MOUNT_POINT}" ]; then
        echo "[-] Backup mount point does not exist."
        mkdir -pm750 "${BACKUP_MOUNT_POINT}"
    else 
        echo "[+] Backup mount point exists. Skipping..."
    fi

    # Configure direct autofs method 
    echo "[+] Configuring autofs..."
    echo "/- /etc/child.direct" > /etc/auto.master.d/master.autofs # Create master map

    echo "${BACKUP_MOUNT_POINT} -rw,sync,fstype=nfs4 ${IP_NODE2}:/var/ossec/logs" > /etc/child.direct # Create direct map
    systemctl enable --now autofs
    if [[ $? -eq 0 ]]; then
        echo "[+] Autofs has been configured successfully."
    else
        echo "[-] Failed to configure autofs."
        exit 1
    fi

    echo -e "[+] Done.\n"
}

# Encrypt backed up compressed log file using GPG
generate_gpg_key() {
    # Validate variables
    if [[ -z "${GPG_KEY_NAME}" || -z "${GPG_KEY_COMMENT}" || -z "${GPG_KEY_MAIL}" || -z "${GPG_KEY_PASSPHRASE}" ]]; then
        echo "[-] Required parameters for generate GPG key are missing. Check your configuration!."
        exit 1
    fi

    # Generate new GPG key
    # Make sure that the GPG directory is exist
    if [ ! -d "${GPG_KEY_HOME}" ]; then
        echo "[-] GPG directory does not exist."
        mkdir -pm700 "${GPG_KEY_HOME}"
    else 
        echo "[+] GPG directory exists. Skipping..."
    fi    

    # File batch untuk membuat kunci
cat > gpg_key_batch << EOF
%echo Generate GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${GPG_KEY_NAME}
Name-Comment: ${GPG_KEY_COMMENT}
Name-Email: ${GPG_KEY_MAIL}
Expire-Date: 0
Passphrase: ${GPG_KEY_PASSPHRASE}
%commit
%echo done
EOF

    echo "[+] Generating new GPG key..."
    gpg --batch --generate-key gpg_key_batch
    gpg --list-keys | grep -q "${GPG_KEY_MAIL}"
    if [[ $? -eq 0 ]]; then
        echo "[+] GPG key has been generated successfully."
    else
        echo "[-] Failed to generate GPG key."
        exit 1
    fi 
}

# Configure cron job to schedule backup log files as user provided + compressed backed up log files + encrypt the compressed log files
create_cron_job() {
    # Validate variables
    if [[ -z "${BACKUP_IN_DAYS}" || -z "${COMPRESSED_LOG_DIR}" || -z "${BACKUP_MOUNT_POINT}" || -z "${GPG_KEY_MAIL}" ]]; then
        echo "[-] Required parameters for create cronjob are missing. Check your configuration!."
        exit 1
    fi

    # Check if compressed log directory is exist
    if [ ! -d "${COMPRESSED_LOG_DIR}" ]; then
        echo "[-] Compressed log directory does not exist."
        mkdir -pm750 "${COMPRESSED_LOG_DIR}"
    else 
        echo "[+] Compressed log directory exists. Skipping..."
    fi

    # Create cron job to compress and encrypt log files according to the BACKUP_IN_DAYS variable
    echo "[+] Create cron job to performing automatic compress and encrypt log files..."
    cat > /etc/cron.d/auto_compress_and_encrypt_log_files << EOF
* * */${BACKUP_IN_DAYS} * * root tar -czf ${COMPRESSED_LOG_DIR}/backup_log_$(date +%Y-%m-%d).tar.gz ${BACKUP_MOUNT_POINT}/* && gpg --encrypt --recipient ${GPG_KEY_MAIL} ${COMPRESSED_LOG_DIR}/backup_log_$(date +%Y-%m-%d).tar.gz
EOF

    # Make sure the cron job has been created
    if [ -f /etc/cron.d/auto_compress_and_encrypt_log_files ]; then
        echo "[+] Cron job has been created successfully."
    else
        echo "[-] Failed to create cron job."
        exit 1
    fi
    echo -e "[+] Done.\n"
}

main() {
    config_repo
    install_deps
    config_autofs
    generate_gpg_key
    create_cron_job
}

main # run the main function
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
# 2. chmod a+x install.sh                  #
# 3. ./install.sh                          #
############################################

# Load and export the environment variables
set a; source .env; set +a

# Display the banner
show_banner() {
    banner="
       __ __                    
.----.|__|  |.-----.-----.-----.
|  __||  |  ||  _  |  _  |__ --|
|____||__|__||_____|___  |_____|
                   |_____|      
"
    echo    "$banner"
    echo    "#############################################################"
    echo    "| PLEASE RUN THIS AS ROOT USER !                            |"
    echo    "| AND MAKE SURE ROOT LOGIN IS ENABLED VIA SSH IN EACH NODE. |"    
    echo -e "#############################################################\n"
}

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

# Install all dependencies
install_deps() {
    # Install all dependencies
    echo "[+] Installing required dependencies..."
    dnf install -y sshpass openssh-clients # 2 required packages
    echo -e "[+] Done.\n"
}

# Generate SSH keys
gen_and_cp_ssh_keys() {
    echo "[+] Generating passwordless SSH pubkeys ..."
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/node1 -C "Node 1 - Client Log Server"
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/node2 -C "Node 2 - Central Log Server"
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/node3 -C "Node 3 - Storage Log Server"
    echo -e "[+] Done.\n"

    # Copy the SSH keys to the respective servers
    echo "[+] Copying the public SSH keys to the respective servers ..."
    sshpass -p "${ROOT_PASS_NODE1}" ssh-copy-id -i ~/.ssh/node1.pub -p ${SSH_PORT_NODE1} root@${IP_NODE1}
    sshpass -p "${ROOT_PASS_NODE2}" ssh-copy-id -i ~/.ssh/node2.pub -p ${SSH_PORT_NODE2} root@${IP_NODE2}
    sshpass -p "${ROOT_PASS_NODE3}" ssh-copy-id -i ~/.ssh/node3.pub -p ${SSH_PORT_NODE3} root@${IP_NODE3}
    echo -e "[+] Done.\n" 
}

cp_file_to_all_nodes() {
    # Copy the .env file to all nodes
    echo "[+] Copying the environment variables file to all nodes ..."
    scp -i ~/.ssh/node1 -P ${SSH_PORT_NODE1} .env root@${IP_NODE1}:~/
    scp -i ~/.ssh/node2 -P ${SSH_PORT_NODE2} .env root@${IP_NODE2}:~/
    scp -i ~/.ssh/node3 -P ${SSH_PORT_NODE3} .env root@${IP_NODE3}:~/
    echo -e "[+] Done.\n"

    # Copy custom-telegram script to all nodes
    echo "[+] Copying the custom-telegram script to node 2..."
    scp -i ~/.ssh/node2 -P ${SSH_PORT_NODE2} integrations/custom-telegram root@${IP_NODE2}:~/
    scp -i ~/.ssh/node2 -P ${SSH_PORT_NODE2} integrations/custom-telegram.py root@${IP_NODE2}:~/
    echo -e "[+] Done.\n"
}

# Configure all nodes
config_all_nodes() {
    # Make sure to add execute permission to config all node script
    echo "[+] Setting execute permission to all node configuration scripts ..."
    chmod a+x config-files/*.sh
    echo -e "[+] Done.\n"

    echo "[+] ==== NODE 1 CONFIGURATION ===="
    # SSH Node 1 and run the script
    ssh -i '~/.ssh/node1' -p ${SSH_PORT_NODE1} root@${IP_NODE1} '/bin/bash -s' < config-files/config-node1.sh || { echo "[-] ==== FAILED ===="; exit 1; }
    echo -e "[+] ==== SUCCESS ====\n"

    # SSH Node 2 and run the script
    echo "[+] ==== NODE 2 CONFIGURATION ===="
    ssh -i '~/.ssh/node2' -p ${SSH_PORT_NODE2} root@${IP_NODE2} '/bin/bash -s' < config-files/config-node2.sh || { echo "[-] ==== FAILED ===="; exit 1; }
    echo -e "[+] ==== SUCCESS ====\n"

    # SSH Node 3 and run the script
    echo "[+] ==== NODE 3 CONFIGURATION ===="
    ssh -i '~/.ssh/node3' -p ${SSH_PORT_NODE3} root@${IP_NODE3} '/bin/bash -s' < config-files/config-node3.sh || { echo "[-] ==== FAILED ===="; exit 1; }
    echo -e "[+] ==== SUCCESS ====\n"
}

# Main function
main() {
    show_banner
    config_repo
    install_deps
    gen_and_cp_ssh_keys
    cp_file_to_all_nodes
    config_all_nodes

    echo "[+] Thank you!"
}

main # run the main function
#!/bin/bash

# Decrypt the compressed log files
FILE_TO_DECRYPT="/mnt/compressed/backup_logs_xxxx.tar.gz" # change with your compressed log file
GPG_KEY_RECIPIENT="testing@mail.com" # change with your GPG key recipient
GPG_KEY_PASSPHRASE="testing123" # change with your GPG key passphrase
OUTPUT_DIR="/mnt/decrypted" # change with your output directory that will store the decrypted file

# Check if the output directory exists
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "[-] Output directory does not exist."
    mkdir -pm750 "${OUTPUT_DIR}"
else
    echo "[+] Output directory exists. Skipping..."
fi

# Decrypt the file
echo "[+] Decrypting the compressed log files..."
gpg --batch --yes --passphrase "${GPG_KEY_PASSPHRASE}" --output "${OUTPUT_DIR}/backup_logs.tar.gz" --decrypt "${FILE_TO_DECRYPT}"
if [[ $? -eq 0 ]]; then
    echo "[+] Decryption success!"
else
    echo "[-] Decryption failed!"
    exit 1
fi

echo -e "[+] Done.\n"
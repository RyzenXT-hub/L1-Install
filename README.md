# Bash Shell Auto Install Titan Node L1 Guardian - Cassini Testnet on Ubuntu 22.04 + 

This repository contains a bash script designed to automate the installation of K3s, Helm, and the Titan L1 Guardian Node. The script also provides an option for migrating an existing Titan L1 node, checks for necessary folders, and configures the node to run as a systemd service for easy management.
```
curl -O https://raw.githubusercontent.com/RyzenXT-hub/Titan-L1/main/install-L1.sh && chmod u+x install-L1.sh && ./install-L1.sh
```
## Features

- Installs K3s (lightweight Kubernetes)
- Configures `kubectl` and installs Helm (Kubernetes package manager)
- Installs and configures Ingress Nginx for routing HTTP traffic
- Configures local storage on `/mnt/storage`
- Installs and runs the Titan L1 Guardian Node
- Sets up the Titan L1 node as a systemd service for automatic startup and management
- Offers both fresh installation and migration options for existing setups

## Prerequisites

- A Linux distribution that supports `systemd` (e.g., Ubuntu, Debian, CentOS, Fedora)
- Root access
- Ports 9000, 2345, 80, and 443 should be open on your firewall
- Access to `/mnt/storage` for local storage configuration
- Your Titan L1 identity code

## Supported Operating Systems

The script is designed to run on Linux-based systems, specifically:
- Ubuntu / Debian
- CentOS / Fedora
- Any Linux distribution that supports `systemd`, `bash`, `curl`, and `wget`

**Note:** This script is not supported on macOS or Windows directly but can be run using a Linux virtual machine or container.



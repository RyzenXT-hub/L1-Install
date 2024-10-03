#!/bin/bash

# Function to check if the previous command succeeded
check_command() {
  if [ $? -ne 0 ]; then
    echo -e "\033[31mError: $1 failed. Please check and try again.\033[0m"
    exit 1
  fi
}

# Function to check if the .titancandidate folder exists in /root/
check_titan_candidate_folder() {
  if [ -d "/root/.titancandidate" ]; then
    echo -e "\033[32mThe .titancandidate folder is found in /root/.\033[0m"
  else
    echo -e "\033[31mThe .titancandidate folder is not found in /root/. Please ensure the folder is extracted in /root/.\033[0m"
    exit 1
  fi
}

# Prompt user for installation type: first-time or migration
echo -e "\033[93mAre you performing a first-time installation or migrating L1? (Enter 1 for installation, 2 for migration)\033[0m"
echo "1) First-time installation"
echo "2) Migrate L1"
read -p "Your choice: " install_type

if [[ "$install_type" == "1" ]]; then
  echo -e "\033[93mProceeding with the first-time installation...\033[0m"
elif [[ "$install_type" == "2" ]]; then
  echo -e "\033[93mYou have chosen L1 migration.\033[0m"

  # Ask if the .titancandidate folder exists in /root/
  echo -e "\033[93mHas the .titancandidate folder already been extracted in /root/? (Y/N)\033[0m"
  read -p "Your answer: " answer

  if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
    echo -e "\033[93mChecking for the existence of the .titancandidate folder...\033[0m"
    check_titan_candidate_folder
  elif [[ "$answer" == "N" || "$answer" == "n" ]]; then
    echo -e "\033[31mPlease extract your backup files in /root/ and run this script again.\033[0m"
    exit 1
  else
    echo -e "\033[31mInvalid response. Please choose Y or N.\033[0m"
    exit 1
  fi
else
  echo -e "\033[31mInvalid option. Please choose either 1 (Installation) or 2 (Migration).\033[0m"
  exit 1
fi

# Update and upgrade the system packages
echo -e "\033[93mUpdating and upgrading system packages...\033[0m"
apt update && apt upgrade -y
check_command "System update and upgrade"

# Install essential packages
echo -e "\033[93mInstalling essential packages (nano, curl, wget, etc.)...\033[0m"
apt install -y nano curl wget
check_command "Installation of essential packages"

# Continue with the installation process (regardless of choice)
# Prerequisite: Install K3s
echo -e "\033[93mInstalling K3s...\033[0m"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -s -
check_command "K3s installation"

# Configure kubeconfig
echo -e "\033[93mConfiguring kubeconfig...\033[0m"
mkdir -p ~/.kube
sudo cat /etc/rancher/k3s/k3s.yaml | tee ~/.kube/config >/dev/null
check_command "kubeconfig configuration"

# Verify K3s installation
echo -e "\033[93mVerifying K3s installation...\033[0m"
kubectl get nodes
check_command "K3s verification"

# Install Helm
echo -e "\033[93mInstalling Helm...\033[0m"
wget https://get.helm.sh/helm-v3.11.0-linux-amd64.tar.gz
tar -zxvf helm-v3.11.0-linux-amd64.tar.gz
sudo install linux-amd64/helm /usr/local/bin/helm
check_command "Helm installation"

# Install Ingress Nginx
echo -e "\033[93mInstalling Ingress Nginx...\033[0m"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
check_command "Ingress Nginx installation"

# Configure storage on /mnt/storage
echo -e "\033[93mConfiguring local storage...\033[0m"
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Create storageclass.yaml
cat <<EOF > storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
parameters:
  path: "/mnt/storage"
EOF

# Apply StorageClass to the K3s cluster
kubectl apply -f storageclass.yaml
check_command "StorageClass application"

# Update ConfigMap to use /mnt/storage
echo -e "\033[93mUpdating ConfigMap...\033[0m"
kubectl patch configmap local-path-config -n kube-system --type=json -p='[{"op": "replace", "path": "/data/config.json", "value":"{\n  \"nodePathMap\":[\n    {\n    \"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\n    \"paths\":[\"/mnt/storage\"]\n  }\n  ]\n}"}]'
check_command "ConfigMap update"

# Titan L1 Node installation
echo -e "\033[93mDownloading Titan L1 Node...\033[0m"
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.21/titan-l1-guardian
chmod 0755 titan-l1-guardian

# Ask for user input for identity code
read -p "Please enter your Titan identity code: " IDENTITY_CODE

# Configure environment variables
echo -e "\033[93mSetting environment variables for Titan L1...\033[0m"
export TITAN_METADATAPATH=/mnt/storage
export TITAN_ASSETSPATHS=/mnt/storage

# Create systemd service file for Titan L1
echo -e "\033[93mCreating systemd service for Titan L1...\033[0m"
cat <<EOF > /etc/systemd/system/titan-l1.service
[Unit]
Description=Titan Guardian Service
After=network.target

[Service]
ExecStart=/root/titan-l1-guardian daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 --code $IDENTITY_CODE
WorkingDirectory=/root
StandardOutput=file:/var/log/guardian.log
StandardError=file:/var/log/guardian.log
User=root
Group=root
Restart=always
RestartSec=8
Environment="TITAN_METADATAPATH=/mnt/storage"
Environment="TITAN_ASSETSPATHS=/mnt/storage"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
echo -e "\033[93mEnabling Titan L1 service...\033[0m"
systemctl daemon-reload
systemctl enable titan-l1.service
systemctl start titan-l1.service
check_command "Titan L1 service activation"

echo -e "\033[32mInstallation and configuration complete!\033[0m"

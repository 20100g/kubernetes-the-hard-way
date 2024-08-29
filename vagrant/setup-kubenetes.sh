#to automate with Ansible

# Container.d install (ref: https://docs.docker.com/engine/install/debian/#install-using-the-repository)
# Ansible Ref : geerlingguy.containerd
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install containerd.io

# Ansible Ref : Tasks https://www.reddit.com/r/linuxadmin/comments/flzx5r/ansible_how_to_disable_swap/
# Disable swap
sudo -i
swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

#SystemD

# Ansible Ref : geerlingguy.containerd
# Resets to default config as package seem incompatible (https://github.com/kubernetes/kubernetes/issues/110177)
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd

# Ansible Ref : geerlingguy.kubernetes
#Install Kubetctl, kubeadm and kubelet
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Init cluster using load balancer endpoint on first master node
sudo kubeadm init --control-plane-endpoint=10.0.0.230:6443 --upload-certs --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/16

# Ansible Ref : githubixx.cilium_kubernetes
# Install Helm on first master node
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium -n kube-system --set ipam.operator.clusterPoolIPv4PodCIDRList=10.244.0.0/16

# Install cilim cli
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

  kubeadm join 10.0.0.230:6443 --token j54xq5.ehm3udzdos7rvhg5 \
        --discovery-token-ca-cert-hash sha256:38c55d031d13f581cdee601fe9f4f019a3fe30e229ab604d8b3b27db68132972 \
        --control-plane --certificate-key f35d0124c66465a42b706a79e79e036145f3f4f79bfeff8cdd49b1671060348a

#sudo systemctl enable --now kubelet
# Add additional control plane node
sudo kubeadm join 10.0.0.230:6443 --token 9kel4q.x61cizvqh2krzv75 \
        --discovery-token-ca-cert-hash sha256:128aeb23203c84fa5284ffa5d0315387849794f94a3c58dd4baf17f2c6c74e69 \
        --control-plane --certificate-key 8621761a95a13c912e4bc33ae5fa02c27b947bb34d2a6c45b6a9ca23b89214a7


sudo kubeadm join 10.0.0.230:6443 --token 9kel4q.x61cizvqh2krzv75 \
        --discovery-token-ca-cert-hash sha256:128aeb23203c84fa5284ffa5d0315387849794f94a3c58dd4baf17f2c6c74e69 \
        --certificate-key 8621761a95a13c912e4bc33ae5fa02c27b947bb34d2a6c45b6a9ca23b89214a7

#GPU support (worker nodes with GPU)  with the operator (bare-metal only - Hyper-V GPU-Paravirtualization appears problematic at best) 
#https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html#operator-install-guide
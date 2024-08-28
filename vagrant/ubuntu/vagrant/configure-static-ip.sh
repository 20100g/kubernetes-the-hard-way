#!/bin/sh
primaryIp=$1
gatewayIp=$2
dnsServer=$3

echo 'Setting static IP address for Hyper-V...'

cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [$primaryIp]
      gateway4: $gatewayIp
      nameservers:
        addresses: [$dnsServer]
EOF
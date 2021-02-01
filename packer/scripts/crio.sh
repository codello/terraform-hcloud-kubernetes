#!/usr/bin/env sh

# This script installs the cri-o container runtime. It requires the following
# environment variables:
# - $CRIO_VERSION: The crio version matching the Kubernetes version (e.g. 1.18).
# 								 Version pinning is possible like so: CRIO_VERSION=1.18:1.18.3

set -e

OS=CentOS_8

cat <<-EOF | sudo tee /etc/modules-load.d/crio.conf >/dev/null
	# Kernel modules required by the cri-o container engine.
	overlay
	br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# net.ipv4.ip_forward seems to be required for cri-o. See: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o
cat <<-EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf >/dev/null
	net.bridge.bridge-nf-call-iptables  = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

sudo curl -fSL -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo

# conntrack is not required but cri-o issues a warning if it is missing.
sudo yum install -y conntrack cri-o

# The default crio bridge has a fixed IP CIDR. Thus the IP range for each node
# is fixed resulting in conflicting IP ranges. Deleting the interface solves
# this problem.
# See: https://github.com/cri-o/cri-o/issues/2411
sudo rm -f /etc/cni/net.d/100-crio-bridge.conf

sudo systemctl enable --now cri-o

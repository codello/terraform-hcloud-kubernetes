#!/usr/bin/env sh

# This script installs the kubernetes components (kubeadm, kubelet). It
# requires the following environment variables to be set:
# - $K8S_VERSION: The kubernetes version that should be installed.

set -e

# Disable SELinux
sudo setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

cat <<-EOF | sudo tee /etc/yum.repos.d/kubernetes.repo >/dev/null
	[kubernetes]
	name=Kubernetes
	baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
	enabled=1
	gpgcheck=1
	repo_gpgcheck=1
	gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
	exclude=kubelet kubeadm kubectl
EOF

# tc is not required but kubeadm issues a warning if it can't find the binary.
# ipvsadm may improve debugging IPVS problems.
sudo yum install -y --disableexcludes=kubernetes \
		kubelet-$K8S_VERSION \
		kubeadm-$K8S_VERSION \
		kubectl-$K8S_VERSION \
		tc \
		ipvsadm
sudo kubeadm config images pull --kubernetes-version "$K8S_VERSION"
sudo systemctl enable --now kubelet

#!/usr/bin/env bash
#
# Kubernetes Setup Add yum repository
#
cat >/etc/yum.repos.d/kubernetes.repo<<__EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
__EOF
#
# Install Kubernetes components
yum install -y kubectl --disableexcludes=kubernetes 
#
wait $!

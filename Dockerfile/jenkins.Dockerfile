# escape=\
### <REQUIRED SCRIPT>: __kubelet__.sh
################################################################
################################################################
#FROM jenkins/jenkins:lts-centos
FROM registry.dellius.app/jenkins:lts-centos-v2.277.2 
# Make changes as user root
USER root
RUN yum update && yum update -y
# verify build ARG's
RUN echo "Jenkins home: /var/jenkins_home"
# Pipelines with Blue Ocean UI and Kubernetes
RUN jenkins-plugin-cli --plugins blueocean kubernetes
# Setup environment variables
ENV DOCKER_HOST=unix:///var/run/docker.sock
ENV HOST_UID=1003
ENV JENKINS_HOME=/var/jenkins_home
ENV KUBECONFIG=/var/jenkins_home/secrets/kubeconfig
# Update & install docker, kubectl, kubelet
RUN yum update -y && yum install -y yum-utils
RUN  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
RUN yum install -y docker-ce docker-ce-cli containerd.io
# Kubernetes Setup Add yum repository
COPY ./__kubectl__.sh .
# Copy CentOS-Base.repo
COPY ./CentOS-Base.repo  /etc/yum.repos.d/
RUN chmod +x ./__kubectl__.sh
RUN ./__kubectl__.sh
RUN yum install -y kubectl
RUN usermod -u ${HOST_UID} jenkins
RUN usermod -aG docker jenkins && newgrp docker
# EXPOSE PORTS
EXPOSE 80
EXPOSE 8080
EXPOSE 50000
# Change to User Jenkins
USER jenkins


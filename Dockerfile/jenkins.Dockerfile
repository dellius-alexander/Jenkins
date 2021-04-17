FROM registry.dellius.app/jenkins:lts-centos-v2.277.2 

# Pipelines with Blue Ocean UI and Kubernetes
RUN jenkins-plugin-cli --plugins blueocean kubernetes
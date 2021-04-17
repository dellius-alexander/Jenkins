#!/usr/bin/env bash
################################################################
################################################################
if [[ $1 =~ ^(start)$ ]]; then
export $(cat $(find -type f -name 'jenkins.env') | grep -v '#' | awk '/=/ {print $1}')
kubectl apply -f $(find -type f -name 'jenkins-rbac.yaml')
kubectl apply -f $(find -type f -name 'jenkins-volume.yaml')
kubectl apply -f $(find -type f -name 'private-docker-registry.yaml')
kubectl apply -f $(find -type f -name 'jenkins-deployment.yaml')
elif [[ $1 =~ ^(stop)$ ]]; then
export $(cat $(find -type f -name 'jenkins.env') | grep -v '#' | awk '/=/ {print $1}')
kubectl delete -f $(find -type f -name 'jenkins-deployment.yaml')
kubectl delete -f $(find -type f -name 'jenkins-volume.yaml')
kubectl delete -f $(find -type f -name 'jenkins-rbac.yaml')
fi


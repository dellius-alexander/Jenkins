#!/usr/bin/env bash
################################################################
################################################################
kubectl apply -f $(find -type f -name 'jenkins-rbac.yaml')
kubectl apply -f $(find -type f -name 'jenkins-volume.yaml')
kubectl apply -f $(find -type f -name 'private-docker-registry.yaml')
kubectl apply -f $(find -type f -name 'jenkins-deployment.yaml')
#!/usr/bin/env bash
################################################################
################################################################
################################################################
__KUBECTL__=$( command -v kubectl)
__JENKINS_ENV__=$( (find ~+ -type f -name 'jenkins.env') )
################################################################
export $(cat (find ~+ -type f -name 'jenkins.env') | grep -v '#' | awk '/=/ {print $1}')
__start(){
${__KUBECTL__} apply -f $(find -type f -name 'jenkins-rbac.yaml') &&
${__KUBECTL__} apply -f $(find -type f -name 'jenkins-volume.yaml') &&
${__KUBECTL__} apply -f $(find -type f -name 'private-docker-registry.yaml') &&
${__KUBECTL__} apply -f $(find -type f -name 'jenkins-deployment.yaml')
}
################################################################
__stop(){
${__KUBECTL__} delete -f $(find -type f -name 'jenkins-deployment.yaml') &&
${__KUBECTL__} delete -f $(find -type f -name 'jenkins-volume.yaml') &&
${__KUBECTL__} delete -f $(find -type f -name 'jenkins-rbac.yaml')
}
################################################################
if [[ $1 =~ ^(start)$ ]]; then
__start
    if [[ $? -ne 0 ]]; then
        echo "Something went wrong.  I will try and run \"__init_jenkins_bare__.sh\ script..."
        if [[ $(hostnamectl | grep -i 'Operating System' | awk '{print $3}' | grep -ic 'centos') -eq 1 ]]; then
            sudo ./__init_jenkins_bare__.sh
        else
            echo "Sorry this script is based on \"CentOS Operating System\"."
        fi;
    fi;
elif [[ $1 =~ ^(stop)$ ]]; then
__stop
fi;


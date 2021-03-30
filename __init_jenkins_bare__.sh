#!/usr/bin/env bash
# env(Centos7)
###############################################################################
###############################################################################
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
###############################################################################
function __color__(){
    printf "${RED}$*${NC}"
}
###############################################################################
###############################################################################
set -e
    # Require sudo to run script
if [[ $UID != 0 ]]; then
    __color__ "\nPlease run this script with sudo: \n"
    __color__ "\n${RED} sudo $0 $* ${NC}\n\n";
    exit 1
fi

__KUBECTL__=$(command -v kubectl)
__PACKAGE_MGR__=$( command -v yum)
__JENKINS_ENV__=$(find ~+ -type f -name 'jenkins.env')

if [ ! -f ${__JENKINS_ENV__} ]; then
    __color__ "\nUnable to locate \"jenkins.env\" file.......exiting......\n"
    exit 1
else
    printf "${__JENKINS_ENV__}"
    source "${__JENKINS_ENV__}"
fi
###############################################################################
# echo "Found Local Directory: ${__JENKINS_DATA_DIR___}"
# echo "Found Remote Host: ${__NFS_REMOTE_HOST__}"
# echo "Found NFS Share: ${__NFS_VOLUME__}"
###############################################################################
###############################################################################
# Create Jenkins Namespace 
###############################################################################
if [  $(kubectl get namespaces -A | grep -ic "jenkins") == 0  ]; then
    ${__KUBECTL__} create namespace jenkins
    wait $!
    printf "\n${RED}Jenkins Namespace created......${NC}\n\n"
    #echo "$(kubectl get namespaces -A | grep -c 'jenkins')"
    wait $!
fi
###############################################################################
###############################################################################
#               VERIFY __KUBECTL__ BINARIES
###############################################################################
function __kube_binary__(){
    # Require sudo to run script
if [ $(rpm -q kubectl | grep -ic 'kubectl') == 0 ]; then
    printf "\nUnable to locate ${RED}kubectl${NC} binary.\n\
    Please install \"kubectl\"......\n";
    exit 1
#else
    #echo "Kubectl found:  ${__KUBECTL__}"
fi

}
###############################################################################
###############################################################################
function __auth_certs_(){

# Kubernetes URL: the Kubernetes API Server URL 
#kubectl config view --minify | grep server
#
# Retrieve the Service Account token and API Server CA
# When a Service Account is created, a secret is automatically generated and 
# attached to it. This secret contains base64 encoded information that can be 
# used to authenticate to the Kubernetes API Server as this ServiceAccount:
# - the Kubernetes API Server CA Certificate
# - the Service Account token
# Retrieve the ServiceAccount token with this one liner command (the value 
# will be required to configure Jenkins credentials later on):
#
kubectl get secret $(kubectl get sa jenkins -n jenkins -o jsonpath={.secrets[0].name}) \
-n jenkins -o jsonpath={.data.token} | base64 --decode
#
# Retrieve the Kubernetes API Server CA Certificate this one liner command 
# (the value will be required to configure the kubernetes plugin later on):

kubectl get secret $(kubectl get sa jenkins -n jenkins -o jsonpath={.secrets[0].name}) \
-n jenkins -o jsonpath={.data.'ca\.crt'} | base64 --decode
#
# (Note: For more details about those values, have a look at Kubernetes - 
# Authentication - Service Account Tokens)
}
###############################################################################
###############################################################################
function __check_env__(){
###############################################################################
wait $!
    # verify required package nfs-utils exists
if [[ $(rpm -q 'nfs-utils' | grep -c "nfs-utils") == 0 ]]; then 
    printf "\n${RED}Installing nfs-utils to enable nfs volume mounts...${NC}\n"
    ${__PACKAGE_MGR__} install -y nfs-utils
fi
wait $!
    # install firewalld
if [[ $(rpm -q 'firewalld' | grep -c "firewalld") == 0 ]]; then
    printf "\n${RED}Installing firewalld to enable firewall rules...${NC}\n"
    ${__PACKAGE_MGR__} install -y firewalld
fi
wait $!
    # Create local nfs directory
if [[  ! -d ${__JENKINS_DATA_DIR___} ]]; then
    echo "Creating local nfs......"
   [[  -d ${__JENKINS_DATA_DIR___}  ]] &&  mkdir -p ${__JENKINS_DATA_DIR___}
fi
# check if nfs volume set to persist reboot
if [ $(cat /etc/fstab | grep -i ${__NFS_VOLUME__} | grep -ic ${__JENKINS_DATA_DIR___}) != 1 ]; then
# set nfs volume to persist reboot
        cat >>/etc/fstab <<EOF
        ${__NFS_REMOTE_HOST__}:${__NFS_VOLUME__}  ${__JENKINS_DATA_DIR___}  nfs4    _netdev,auto,nosuid,rw,sync,hard,intr    0   0
EOF
# Now we mount the newly added nfs share.
mount -a
fi

if [ $(mount | grep -i ${__NFS_VOLUME__} | grep -ic ${__JENKINS_DATA_DIR___}) != 1 ]; then
    # mount nfs volume for jenkins persistent volume 
    mount -t nfs -o ${__NFS_REMOTE_HOST__}:${__NFS_VOLUME__}  ${__JENKINS_DATA_DIR___}

    if [[  $(firewall-cmd --state | grep -ic 'not running') == 1  ]]; then
        printf "\n ${RED}Firewalld is not running. \n Restart firewalld and re-run the ${0}......${NC}\n"
        exit 1
    else
        #
        firewall-cmd --add-service=nfs --zone=internal --permanent
        firewall-cmd --add-service=mountd --zone=internal --permanent
        firewall-cmd --add-service=rpc-bind --zone=internal --permanent
        firewall-cmd --reload
        #
        wait $!
        #
        printf "\nPorts assignments...\n"
        firewall-cmd --zone=public --permanent --list-ports
        wait $!
        echo "Local directory created..."
        sleep 3
        wait $!
    fi 
fi
    # Verify and/or start dbus
if [[ $(ls -lia /run  | grep -ic "dbus") == 0  ]]; then
    echo "Setting up dbus configuration..."
    dbus-uuidgen > /var/lib/dbus/machine-id
    mkdir -p /var/run/dbus
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address
fi

}
###############################################################################
###############################################################################
#    Startup Process
###############################################################################
function __setup__(){
###############################################################################

$(__check_env__)

wait $!
    # Setup the storage class, persistent volume and persistent volume claim
if [  $(${__KUBECTL__} get pvc -A &>/dev/null | grep -ic jenkins) == 0  ]; then
    ${__KUBECTL__} apply -f $(find ~+ -type f -name 'jenkins-volume.yaml')
    printf "\n${RED}Jenkins persistent volume created...${NC}\n"
    wait $!
else
    printf "\n${RED}Jenkins persistent volume exists...${NC}\n"
fi
}
###############################################################################
###############################################################################
#       Startup Process
###############################################################################
    # verify __KUBECTL__ binary
__kube_binary__
    # setup jenkins
$(__setup__)
if [ $? != 0 ]; then
    printf "Something went wrong....exit codes...\n\n"
    exit 1
fi
    # Setup jenkins.rbac.yaml, namespace & service account
${__KUBECTL__} apply -f $(find ~+ -type f -name 'jenkins-rbac.yaml')
wait $!
#     # Setup volume claim
# ${__KUBECTL__} apply -f jenkins-volume.yaml
# wait $!
    # Setup the service account and jenkins deployment
${__KUBECTL__} apply -f $(find ~+ -type f -name 'jenkins-deployment.yaml')
wait $!

echo "Completed......"
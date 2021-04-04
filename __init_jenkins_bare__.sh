#!/usr/bin/env bash
# env(Centos7)
###############################################################################
###############################################################################
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
###############################################################################
function __print_red__(){
    printf "${RED}$*${NC}"
}
###############################################################################
    # Require sudo to run script
if [[ $UID != 0 ]]; then
    __print_red__ "\nPlease run this script with sudo: \n"
    __print_red__ "\n${RED} sudo $0 $* ${NC}\n\n";
    exit 1
fi
###############################################################################
__KUBECTL__=$( command -v kubectl)
__PACKAGE_MGR__=$( command -v yum)
__JENKINS_ENV__=$( (find ~+ -type f -name 'jenkins.env') )
###############################################################################
if [ ! -f ${__JENKINS_ENV__} ]; then
    __print_red__ "\nUnable to locate \"jenkins.env\" file.......exiting......\n"
    exit 1
fi
printf "${__JENKINS_ENV__}"
source "${__JENKINS_ENV__}"
###############################################################################
# echo "Found Local Directory: ${__JENKINS_DATA_DIR___}"
# echo "Found Remote Host: ${__NFS_REMOTE_HOST__}"
# echo "Found NFS Share: ${__NFS_VOLUME__}"
###############################################################################
###############################################################################
# Create Jenkins Namespace 
###############################################################################
if [  $(${__KUBECTL__} get --kubeconfig=${__KUBECONFIG__} namespaces -A | grep -ic "jenkins") == 0  ]; then
    ${__KUBECTL__} create namespace jenkins
    wait $!
    printf "\n${RED}Jenkins Namespace created......${NC}\n\n"
    #echo "$(${__KUBECTL__} get namespaces -A | grep -c 'jenkins')"
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
${__KUBECTL__} get --kubeconfig=${__KUBECONFIG__} secret $(${__KUBECTL__} get \
--kubeconfig=${__KUBECONFIG__} sa jenkins -n jenkins -o jsonpath={.secrets[0].name}) \
-n jenkins -o jsonpath={.data.token} | base64 --decode
#
# Retrieve the Kubernetes API Server CA Certificate this one liner command 
# (the value will be required to configure the kubernetes plugin later on):

${__KUBECTL__} get --kubeconfig=${__KUBECONFIG__} secret $(${__KUBECTL__} get --kubeconfig=${__KUBECONFIG__} sa jenkins -n jenkins -o jsonpath={.secrets[0].name}) \
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
if [  ! -d ${__JENKINS_DATA_DIR___} ]; then
    echo "Creating local nfs......"
    mkdir -p "${__JENKINS_DATA_DIR___}"
fi
# check if nfs volume set to persist reboot
if [ $(cat /etc/fstab | grep -ic "jenkins_data") != 2 ]; then
# set nfs volume to persist reboot
    __print_red__ "\n\nSetting up nfs volume to persist reboot...\n\n"
    cat >>/etc/fstab <<EOF
    ${__NFS_REMOTE_HOST__}:${__NFS_VOLUME__}  ${__JENKINS_DATA_DIR___}  nfs4    _netdev,auto,nosuid,rw,sync,hard,intr    0   0
EOF
# Now we mount the newly added nfs share.
mount -a
fi
__print_red__ "****************************************************************"
if [ $(mount | grep -i ${__NFS_VOLUME__} | grep -ic ${__JENKINS_DATA_DIR___}) == 0 ]; then
    # mount nfs volume for jenkins persistent volume 
    mount -t nfs -o nfsvers=4 ${__NFS_REMOTE_HOST__}:${__NFS_VOLUME__}  ${__JENKINS_DATA_DIR___}
    __print_red__ "\n\nNFS share mounted locally at [ ${__JENKINS_DATA_DIR___} ]\n\n"
    if [[  $(firewall-cmd --state | grep -ic 'not running') == 1  ]]; then
        printf "\n ${RED}Firewalld is not running. \n Restart firewalld and re-run the ${0}......${NC}\n"
        exit 1
    else
        # Setup firewall rules for nfs share
        __print_red__ "\n\nSetting up firewall rules...\n\n"
        firewall-cmd --add-service=nfs --zone=internal --permanent
        firewall-cmd --add-service=mountd --zone=internal --permanent
        firewall-cmd --add-service=rpc-bind --zone=internal --permanent
        firewall-cmd --reload
        #
        wait $!
        #
        __print_red__ "\nPorts assignments...\n"
        firewall-cmd --zone=public --permanent --list-ports
        wait $!
        echo "Local directory created..."
        sleep 3
        wait $!
    fi 
fi
    # Verify and/or start dbus
if [ $(ls -lia /run  | grep -ic 'dbus') == 0  ]; then
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

__check_env__

wait $!
    # Setup the storage class, persistent volume and persistent volume claim
if [  $(${__KUBECTL__} get --kubeconfig=${__KUBECONFIG__} pvc -A &>/dev/null | grep -ic jenkins) == 0  ]; then
    ${__KUBECTL__} apply --kubeconfig=${__KUBECONFIG__} -f $(find ~+ -type f -name 'jenkins-volume.yaml')
    printf "\n${RED}Jenkins persistent volume created...${NC}\n"
    wait $!
else
    printf "\n${RED}Jenkins persistent volume claim exists...${NC}\n"
fi
}
###############################################################################
###############################################################################
#       Startup Process
###############################################################################
    # verify __KUBECTL__ binary
__kube_binary__
    # setup jenkins
__setup__
if [ $? != 0 ]; then
    printf "\nSomething went wrong....exit codes...\n\n"
    exit 1
fi
    # Setup jenkins.rbac.yaml, namespace & service account
${__KUBECTL__} apply --kubeconfig=${__KUBECONFIG__} -f $(find ~+ -type f -name 'jenkins-rbac.yaml')
wait $!
#     # Setup volume claim
# ${__KUBECTL__} apply --kubeconfig=${__KUBECONFIG__} -f jenkins-volume.yaml
# wait $!
    # Setup the service account and jenkins deployment
${__KUBECTL__} apply --kubeconfig=${__KUBECONFIG__} -f $(find ~+ -type f -name 'jenkins-deployment.yaml')
wait $!

echo "Completed......"

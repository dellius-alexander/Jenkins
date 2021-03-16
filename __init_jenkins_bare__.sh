#!/usr/bin/env bash
# env(Centos7)
###############################################################################
###############################################################################
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
__JENKINS_ENV__=$([ -d $(find ~+ -type f -name jenkins.env) ] && cat )
__KUBECTL__=$( command -v kubectl)
__PACKAGE_MGR__=$( command -v apt || command -v apt-get || command -v yum)
__DIR_ARRAY__=() # Array variable storing
__DIR_ARRAY__=(${PWD},  ${__KUBECTL__})
###############################################################################
    # Verify kubelet present on host

echo ${__PACKAGE_MGR__}
echo ${__DIR_ARRAY__} 
    # source environment file
if [[ -f $(find ~+ -type f -name jenkins.env) ]]; then
    source $(find ~+ -type f -name 'jenkins.env')
    printf "\nFound jenkins.env file......\n"
else
    printf "\nUnable to locate jenkins.env file.......exiting......\n"
    exit 1
fi
#
# echo "Found Local Directory: ${__LOCAL_DIRECTORY__}"
# echo "Found Remote Host: ${__NFS_REMOTE_HOST__}"
# echo "Found NFS Share: ${__NFS_VOLUME__}"
###############################################################################
###############################################################################
# Create Jenkins Namespace 
###############################################################################
if [[  $(kubectl get namespaces -A | grep -ic 'jenkins') == 0 ]]; then
    ${__KUBECTL__} create namespace jenkins
    wait $!
    printf "\n${RED}Jenkins Namespace created......${NC}\n"
    #echo "$(kubectl get namespaces -A | grep -c 'jenkins')"
    wait $!
fi
###############################################################################
###############################################################################
###############################################################################
    # Require sudo to run script
if [[ $UID != 0 ]]; then
    printf "\nPlease run this script with sudo: \n";
    printf "\n${RED} sudo $0 $* ${NC}\n\n";
    exit 1
fi
###############################################################################
###############################################################################
###############################################################################
#               VERIFY __KUBECTL__ BINARIES
###############################################################################
function __kube_binary__(){
    # Require sudo to run script
if [[ $(rpm -q kubectl | grep -ic 'kubectl') == 0 ]]; then
    printf "\nUnable to locate ${RED}kubelet${NC} binary. \nPlease re-run this \
    script using the ${RED}--setup${NC} flag.\n Usage:${RED} $0 [ --reset | --setup ]${NC}\n"
    printf "\n$RED}sudo $0 $*${NC}";
    exit 1
#else
    #echo "Kubectl found:  ${__KUBECTL__}"
fi

}
###############################################################################
###############################################################################
function __dir_exists__(){
if [[ -d "${1}" ]]; then
    ### Take action if $DIR exists ###
    DIR=$1 
    # count array of directories
    local CNT=${#DIR[@]}
    echo "CNT Directories..."
else
     ###  Control will jump here if $DIR does NOT exists ###
        echo "Error: ${1} not found. Can not continue."
        exit 1
fi
sleep 2

# use for loop read all directories
for (( i=0; i<${#DIR[@]}; i++ ));
do
    ### Take action while $CNT -ne 0 ###
    printf "\nDIR #: ${CNT}:\t"
    printf "${MSG} ${DIR[$i]}\n"
    ((i++))
done
}  # END OF DIR_EXISTS()
###############################################################################
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
if [[  ! -d ${__LOCAL_DIRECTORY__} ]]; then
    echo "Creating local nfs......"
   [[  -d ${__LOCAL_DIRECTORY__}  ]] &&  mkdir -p ${__LOCAL_DIRECTORY__}
   
    # mount nfs volume for jenkins persistent volume 
    mount -t nfs -o ${__NFS_REMOTE_HOST__}:${__NFS_VOLUME__}  ${__LOCAL_DIRECTORY__}
    # verify mounted volume NFS share
    if [[  $(cat /etc/fstab | grep -c  ${__LOCAL_DIRECTORY__}) == 0  ]]  \
    && [[  $(ls -lia ${__LOCAL_DIRECTORY__} | grep -c "${__LOCAL_DIRECTORY__}")  == 0 ]]; then
            # check if nfs volume set to persist reboot
        if [[ $(cat /etc/fstab &> /dev/null | grep -c "${__NFS_VOLUME__}") == 0 ]]; then 
                # set nfs volume to persist reboot
        cat >>/etc/fstab <<EOF
        ${__NFS_REMOTE_HOST__}:${__NFS_VOLUME__}  ${__LOCAL_DIRECTORY__} nfs  rw,defaults 0 0
EOF
        fi
        wait $!
        if [[  $(firewall-cmd --state | grep -c 'not running') == 1  ]]; then
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
#
wait $!
fi
    # Verify and/or start dbus
if [[ $(ls -lia /run  | grep -c "dbus") == 0  ]]; then
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
    # color highlighting
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP

__check_env__

wait $!
    # Setup the storage class, persistent volume and persistent volume claim
if [[  $(${__KUBECTL__} get pvc -A &>/dev/null | grep -c jenkins) == 0  ]]; then
    ${__KUBECTL__} apply -f jenkins-volume.yaml
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
    # check directory
eval __dir_exists__ ${__DIR_ARRAY__}
    # setup jenkins
__setup__
if [[ $? != 0  ]]; then
    printf "Something went wrong....exit codes...\n$?\n"
fi
    # Setup jenkins.rbac.yaml, namespace & service account
${__KUBECTL__} apply -f jenkins-rbac.yaml
wait $!
#     # Setup volume claim
# ${__KUBECTL__} apply -f jenkins-volume.yaml
# wait $!
    # Setup the service account and jenkins deployment
${__KUBECTL__} apply -f jenkins-deployment.yaml
wait $!

echo "Completed......"
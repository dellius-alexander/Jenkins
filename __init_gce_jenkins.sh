#!/usr/bin/env bash
# env(Centos7)
###############################################################################
###############################################################################
###############################################################################
    # Verify kubelet present on host
__KUBECTL__=$( command -v kubectl)
__PACKAGE_MGR__=$( command -v apt || command -v apt-get || command -v yum)
__DIR_ARRAY__=("${PWD}")
echo -n "Package manager: ${__PACKAGE_MGR__}"
echo -n "Directories: ${__DIR_ARRAY__} "
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
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
if [[  $(kubectl get namespaces -A | grep -c 'jenkins') == 0 ]]; then
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
#                         VERIFY __KUBECTL__ BINARIES
###############################################################################
###############################################################################
function __kube_binary__(){
###############################################################################
    # Require sudo to run script
if [[ $(rpm -q kubectl | grep -c 'kubectl') == 0 ]]; then
    printf "\nUnable to locate ${RED}kubelet${NC} binary. \nPlease re-run this \
    script using the ${RED}--setup${NC} flag.\n Usage:${RED} $0 [ --reset | --setup ]${NC}\n"
    printf "\n$RED}sudo $0 $*${NC}";
    exit 1
#else
    #echo "Kubectl found:  ${__KUBECTL__}"
fi

}
###############################################################################
#                          CHECK IF DIRECTORIES EXIST
###############################################################################
###############################################################################
function dir_exists(){
if [[ -d "${1}" ]]; then
    ### Take action if $DIR exists ###
    DIR=$1 
    CNT=${#DIR[@]}
    #echo ${DIR[@]}
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
    printf "DIR #: ${CNT}\n"
    printf "${MSG} ${DIR[$i]}\n"
    ((CNT--))
done

}  # END OF DIR_EXISTS()
###############################################################################
#      GET JENKINS ServiceAccount & Kubernetes API Server CA Certificate
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
#       CHECK THE ENVIRONMENT FOR ALL ACCESS RULES
###############################################################################
###############################################################################
function __check_env__(){
###############################################################################
source $(find )
}
###############################################################################
###############################################################################
#    Startup Process
###############################################################################
###############################################################################
###############################################################################
function __setup__(){
###############################################################################
    # color highlighting
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP

__check_env__ 2>/dev/null
wait $!

}
###############################################################################
###############################################################################
###############################################################################
function __volume__(){
###############################################################################
wait $!
    # Setup the storage class, persistent volume and persistent volume claim
if [[  $(${__KUBECTL__} get pvc -A &>/dev/null | grep -c jenkins) == 0  ]]; then
    ${__KUBECTL__} apply -f jenkins-gce-volume.yaml
    printf "\n${RED}Jenkins persistent volume created...${NC}\n"
    wait $!
else
    printf "\n${RED}Jenkins persistent volume exists...${NC}\n"
fi
}
###############################################################################
###############################################################################
###############################################################################
#       Startup Process
###############################################################################
    # verify __KUBECTL__ binary
__kube_binary__
wait $!
    # check directory
eval dir_exists ${__DIR_ARRAY__} 
wait $!
    # setup jenkins
__setup__
wait $!
if [[ $? != 0  ]]; then
    printf "Something went wrong....exit codes...\n$?\n"
fi
wait $!
    # Setup jenkins.rbac.yaml, namespace & service account
${__KUBECTL__} apply -f jenkins-rbac.yaml
wait $!
#
# Setup your PersistentVolume
#     # Setup volume claim
# ${__KUBECTL__} apply -f jenkins-volume.yaml
# wait $!
    # Setup the service account and jenkins deployment
${__KUBECTL__} apply -f jenkins-gcd-deployment.yaml
wait $!

echo "Completed......"
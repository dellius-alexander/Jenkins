# Jenkins Deployment
---
*Note: To create your own bare-metal k8s cluster see [kubernetes bare-metal](https://github.com/dellius-alexander/kubernetes)*<br/>
*Please see [Jenkins House Cleaning Considerations](notes.md) for post-installation configurations to harden your Jenkins instance.*

---

### <a id="deploy-jenkins">Jenkins Kubernetes Deployment</a>

---
---

Jenkins offers a `Kubernetes` Plugin different methods to authenticate to a remote Kubernetes cluster.  I addition we have a [__kubectl__.sh](__kubectl__.sh) script located in this repository. To use the Kubernetes plugin to access your Kbernetes cluster, we will need an access method.  Several credential options are listed here:

- Secret Text Credentials: using a Service Account token (see [Kubernetes - Authentication - Service Account Tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens))
- Secret File Credentials: using a KUBECONFIG file (see [Kubernetes - Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/))
- Username/Password Credentials: using a username and password (see [Kubernetes - Authentication - Static Password File authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-password-file))
- Certificate Credentials: using client certificates (see [Kubernetes - Manage TLS Certificates in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/))
- Evolution of my Jenkins Environment (see [Jenkins and Kubernetes - Secret Agents in the Clouds](https://www.jenkins.io/blog/2018/09/14/kubernetes-and-secret-agents/))
    


<br/>
We have made setting up Jenkins much simpler by defining our jenkins deployment within the corresponding YAML files, these define the resources and context of our Jenkins Kubernetes (k8s) deployment.  
<br/><br/>
In order to properly run jenkins we will need to create each resource object below by accessing the Kubernetes API Server.  Each Yaml file contains the definitions for each Jenkins resource object used for:
<br/><br/>

- ***[Service Account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)***, ***[ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole)*** & ***[RoleBindings](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding)*** --- [jenkins-rbac.yaml](./jenkins-rbac.yaml)
- ***[StorageClass](https://kubernetes.io/docs/concepts/storage/storage-classes/#the-storageclass-resource)***, ***[PersistentVolume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistent-volumes)*** & ***[PersistentVolumeClaim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims)*** --- [jenkins-volume.yaml](./jenkins-volume.yaml)
- ***[Jenkins Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)***, ***[Jenkins Service](https://kubernetes.io/docs/concepts/services-networking/service/#service-resource)*** --- [jenkins-deployment.yaml](./jenkins-deployment.yaml)
<br/><br/>

Use kubectl to define our resource via the k8s API:
```bash
# create a Jenkins namespace

$ kubectl create namespace jenkins
  namespace/jenkins created

# Deploy Jenkins resources

$ kubectl apply -f jenkins-rbac.yaml && \
  kubectl apply -f jenkins-volume.yaml && \
  kubectl apply -f jenkins-deployment
```
Once jenkins is running. We can access the jenkins service via: **http:\/\/Kubernetes_API_Server_URL\>:\<Service_Port\>**

You can retrieve these using ***kubectl***. [See below](#What-comes-next)

---
### <a id="first-time-access">First Time Accessing Jenkins</a>
---

<br/>
You will need the admin access token upon initial setup. Once you have created the first admin account this option will not work again.  You will have to delete your entire jenkins data to reset defaults, so don't forget your password. But this assumes you have access to the persisted volume location where Jenkins installed up initial deployment. Enter the following command to retrieve the Jenkins admin password upon first startup.  
<br/><br/>

Access Jenkins default password on first time login: <br/>
    *[See Access Jenkins dashboard for more details](https://www.jenkins.io/doc/book/installing/kubernetes/#access-jenkins-dashboard)*
```bash
# This will be removed after you setup admin account.
$ kubectl exec -it -n jenkins jenkins-deployment-<unique_hash> -- \
  cat /var/jenkins_home/secrets/initialAdminPassword
```

The password is at the end of the log formatted as a long alphanumeric string:

```bash

*************************************************************
*************************************************************
*************************************************************

Jenkins initial setup is required.
An admin user has been created and a password generated.
Please use the following password to proceed to installation:

94b73ef6578c4b4692a157f768b2cfef

This may also be found at:
/var/jenkins_home/secrets/initialAdminPassword

*************************************************************
*************************************************************
*************************************************************
```

<p><strong>That's it you're all set to start using jenkins. Please see:</strong>
<a href="https://www.jenkins.io/doc/book/installing/kubernetes/" id="JenkinsInstallReference">Jenkins install reference for more details</a>

### <a id="init-jenkins-script">Init Jenkins Script: (Alternative)</a>
<br/>

As an alternative, you may choose to use the ***[init.sh](init.sh)*** scripts or start Jenkins using ***kubectl*** as shown above.<br/>

---
---
## Authentication
---

If you plan to use Jenkins to connect to the k8s cluster resources you will need the Service Account token and k8s API Server CA. When a Service Account is created, a secret is automatically generated and attached to it. This secret contains base64 encoded information that can be used to authenticate to the Kubernetes API Server Url as this ServiceAccount using the K8s API Server CA Certificate.  Lastly, accessing the Docker REST API Url: <br/><br/>
**Note: You will need these values for various global and system configuration options upon first time login.**

1. Service Account token
2. Kubernetes URL: the Kubernetes API Server URL
3. Kubernetes API Server CA Certificate
4. Docker server REST API URL

*These objects will be needed if you intend to setup cloud services authentication to the k8s cluster.  This will enable the Jenkins service account to access Pod and the k8s cluster resources.*

---
---
### 1. Service Account
Retrieve the ServiceAccount token with this one liner command (the value 
will be required to configure Jenkins credentials later on):

```bash
# Retrieve the ServiceAccount token
$ kubectl get secret $(kubectl get sa -n jenkins jenkins \
  -o jsonpath={.secrets[0].   name}) \
  -n jenkins -o jsonpath={.data.token} | base64 --decode
```
---
### 2. Kubernetes API Server URL & Port<a id="KubernetesServerURL&Ports"></a>
*This will be needed later when configuring Jenkins field reference: k8s API Server URL & Port, and the Kubernetes Plugin.*
```bash
# Jenkins Server URL
$ kubectl config view --minify | grep server

     server: https://10.240.0.12:6443

# Jenkins Service Port
$ kubectl get -n jenkins services | gawk -p {'print $5'} | cut -c 1-14

  PORT(S)
# <container port>:<service port>
  8080:32307/TCP
```
---

## 3. Kubernetes API Server CA Certificate
Retrieve the Kubernetes API Server CA Certificate this one liner command 
(the value will be required to configure the kubernetes plugin post-installation ):

```bash
# Retrieve the Kubernetes API Server CA Certificate for the Kubernetes Plugin
$ kubectl get secret $(kubectl get sa -n jenkins jenkins \
-o jsonpath={.secrets[0].name}) \
-n jenkins -o jsonpath={.data.'ca\.crt'} | base64 --decode

-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTIxMDMxNzA3NDExN1oXDTMxMDMxNTA3NDExN1owFTETMBEGA1UE
......
-----END CERTIFICATE-----
```

After first login and initial setup, navigate to: <br/>

* `Manage Jenkins --> Manage Plugins --> Available [TAB]` 

Install the below plugins.

* Kubernetes, Kubernetes CLi & Kubernetes Client API

Copy the above CA Certificate after you install the Kubernetes Plugins above and paste it in the `Kubernetes server certificate key` field, by navigating to the below: 

* `Manage Jenkins --> Manage Node and Clouds --> Configure Clouds --> [Add a new cloud](Dropdown) --> Kubernetes`

Expand the `Kubernetes Cloud details` option and fill in the details.

```YAML
Name: Kubernetes or your-cluster-name
Kubernetes URL: https://10.240.0.12:6443    # (Kubernetes API Server URL & Port)
Kubernetes server certificate key: CA Certificate    # (Kubernetes API Server CA Certificate)
```

(Note: For more details about this topic, have a look at [Kubernetes - Authentication - Service Account Tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens), [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/), [Access Clusters Using the Kubernetes API](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/))

---
## 4. Docker server REST API URL

The Docker daemon can listen for Docker Engine API requests via three different types of Socket: 

*Note: select a link for more details.*

- [unix:///var/run/docker.sock](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-socket-option)
- [tcp://\<Docker Host IP address>:\<Service Port>](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-socket-option)
- [fd](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-socket-option)

By default, a unix domain socket (or IPC socket) is created at **/var/run/docker.sock**, requiring either root permission, or docker group membership.

For this project we used the [unix:///var/run/docker.sock](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-socket-option) socket option to connect to the docker daemon on our k8s host.

*Note: If you’re using an HTTPS encrypted socket, keep in mind that only TLS1.0 and greater are supported. Protocols SSLv3 and under are not supported anymore for security reasons.*

The daemon listens on  but you can Bind Docker to another host/port or a Unix socket.

```
DOCKER_HOST='tcp://[host]:[port][path] or unix://path'
```

---


## 5. <a href="" id="What-comes-next"></a>What comes next...

1. Access jenkins from a browser via the ***http:\/\/\<Kubernetes_API_Server_URL>:\<Service_Port>**

2. Once you have setup the admin account you can begin setting up your pipeline.
    
    *[Read More about Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/#pipeline-syntax)*
<br/>
    See below sample declarative pipeline:    

    ```groovy
    pipeline{
        agent any
        options {
            ansiColor('xterm')
        }
        environment { // Define some environment variables
            // DOCKER_CERT_PATH is automatically picked up by the Docker client
            // Usage: $DOCKER_CERT_PATH or $DOCKER_CERT_PATH_USR or $DOCKER_CERT_PATH_PSW
            DOCKER_CERT_PATH = credentials('PRIVATE_CNTR_REGISTRY')
        }
        stages {
            stage('Build Test Images...'){
                steps {
                    script {
                        // Define some variables
                        env.BUILD_RESULTS="failure"    
                        def jenkins_image
                        def jenkins_dockerfile
                        
                        try{ // try and catch errors
                            // Test environment...
                            sh '''
                            ls -lia;
                            env;
                            '''
                            // name the dockerfile
                            jenkins_dockerfile = 'jenkins.Dockerfile'
                            // build the cypress test image
                            jenkins_image = docker.build("jenkins:${env.BUILD_ID}", "-f ${jenkins_dockerfile} .")
                            // Login to private container registry:
                            //   - [ registry.dellius.app ]
                            //   - Image: registry.dellius.app/jenkins:lts-centos-v2.277.2          
                            sh '''
                            docker login -u $DOCKER_CERT_PATH_USR -p $DOCKER_CERT_PATH_PSW registry.dellius.app;
                            '''
                            // tag the cypress image to private repository
                            sh '''
                            docker tag cypress/custom:${BUILD_ID} registry.dellius.app/jenkins:lts-centos-v2.277.3;
                            '''
                            // Push image to private container registry
                            sh '''
                            docker push registry.dellius.app/jenkins:lts-centos-v2.277.3;
                            '''
                            env.BUILD_RESULTS="success"
                            sh '''
                            echo "Intermediate build ${BUILD_RESULTS}......";
                            '''
                        }
                        catch(e){
                            env.BUILD_RESULTS="failure"
                            sh '''
                            echo "Intermediate build ${BUILD_RESULTS}......";
                            '''
                            throw e
                        }
                        cleanWs() // clean up workspace post-Build
                    } // End of script block
                } // Enc of steps()
            } // End of Build Test images stage()
        } // End of stages
    } // End of pipeline
    ```

3. Execute a bash shell script instead of a declarative pipeline Jenkinsfile

      This script uses a shell script to automate Jenkins build process. Her a snippet of the main driver.
        
      ```Bash
      #!/usr/bin/env bash
      ################################################################
      #                 ... START OF BUILD STEPS ...
      ################################################################
      
      printf "\n\n"
      __remove_repo__ # function to delete contents of PwD
      #
      wait $!
      #
      [ $? != 0 ] && echo "Something went wrong removing...${?}"
      #
      __remove_cntr__ # delete duplicate containers
      #
      wait $!
      #
      [ $? != 0 ] && echo "Something went wrong removing...${?}"
      
      
      ################################################################
      git clone ${PROJECT_REPO_MAIN}
      #
      wait $!
      #
      cd Testing-Strategy
      # Use a secondary script to build your container and sends 
      # stderr to /dev/null
      ./__init_container__.sh  2>/dev/null
      #
      wait $!
      # check for return error code and exits build
      [ ${?} != 0 ] && echo "Build errors found...${?}" \
      && exit 4
      #
      # Remove deployments
      if [[]  $(kubectl get deployments.apps -A | grep -c hyfi ) != 0  ]]; then
          kubectl delete -f $(find ~+ -type f -name 'hyfi-deployment.yaml')  2>/dev/null \
          && printf "\n\n${RED}$1${NC}\n\n" 
          printf "\n\nRemoving Test Deployment.....\n\n"
      fi
      echo "Build completed......"
      
      ```

---

## Conclusion

Jenkins is a powerful CI/CD tool and it can be configured to do just about anything.  Please remember to setup your Global and System user configurations upon first time login. I hope this was helpful to your Jenkins journey. 

 **Note: Please review the [Jenkins House Cleaning Considerations](notes.md) for post-installation configurations to harden your Jenkins instance.**

---
---
<br/><br/>
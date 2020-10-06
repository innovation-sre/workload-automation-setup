# workload-automation-setup
Workload automation/pipeline configuration and setup

### Dependencies

#### For bootstraping and configuration

Following are the dependencies required before you run the `bootstrap.sh` file,
 
- Jenkins server
- Jenkins job builder (pip install --user jenkins-job-builder, remember to add to system PATH)
- java/jre openjdk version "1.8.0_265" (yum)

#### On the Orchestration Host

Following are the dependencies required on the orchestration host which is used for scale-ci,

- ansible version=2.9.12 (pip)
- jmespath version=0.9.0 (pip)
- wget (yum)
- git (yum)


### Assumptions
You have a preinstalled Jenkins server with OpenShift CLI (oc) and cached appropriate kubernetes config. 

For lack of integration with Vault (at the moment), we assume that this Jenkins server/worker is already setup with the necessary tooling to connect to the control plane of the target OpenShift cluster.

### Configure Jenkins job ini and workload-env sh file
- username/jenkins_user_id
- password/jenkins_api_token
- url/jenkins_url


### Bootstraping

1. Run `bootstrap.sh` as follows,
   ```
   ./bootstrap.sh \
      --jenkins-user <value> \
      --jenkins-password <value>  \
      --jenkins-url <value> \
      --host-username <value>  \
      --host-pk-file <value>
   ```
   
   For example,
   
   ```
    ./bootstrap.sh --jenkins-user admin --jenkins-password passwd --jenkins-url "http://jenkins_url:8080" --host-user root --host-pk-file ~/.ssh/id_rsa
   ```
   
   Type `./bootstrap.sh --help` for more details.

2. Goto the Jenkins URL and traverse to the main Jenkins URL Pipeline Job - http://<JENKINS_URL>/job/SCALE-CI-PIPELINE/

3. Next enter the token and url for the Kubernetes Cluster and select the Workloads that you want to run.
    
   ![alt text](images/pipeline.png "Pipeline Image")
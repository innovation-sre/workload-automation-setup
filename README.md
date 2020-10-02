# workload-automation-setup
Workload automation/pipeline configuration and setup

### Dependencies
- Jenkins server
- Jenkins job builder (pip install --user jenkins-job-builder, remenber to add to system PATH)
- wget (yum install)
- java/jre (yum install)
- git (yum install)

### Assumptions
You have a preinstalled Jenkins server with OpenShift CLI (oc) and cached appropriate kubernetes config. For lack of integration with Vault (at the moment), we assume that this Jenkins server/worker is already setup with the necessary tooling to connect to the control plane of the desired cluster.

### Configure Jenkins job ini and workload-env sh file
- username/jenkins_user_id
- password/jenkins_api_token
- url/jenkins_url


### Deployment

1. Run `setup.sh` as follows,
   ```
   ./setup.sh -u USER -p PASSWORD -s JENKINS_URL
   ```

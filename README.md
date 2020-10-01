# workload-automation-setup
Workload automation/pipeline configuration and setup

### Dependencies
- Jenkins server
- Jenkins job builder (pip install --user jenkins-job-builder, remenber to add to system PATH)
- wget (yum install)
- java/jre (yum install)
- git (yum install)


### Configure Jenkins job ini and workload-env sh file
- username/jenkins_user_id
- password/jenkins_api_token
- url/jenkins_url


### Deployment

1. Run `setup.sh` as follows,
   ```
   ./setup.sh -u USER -p PASSWORD -s JENKINS_URL
   ```

#!/usr/bin/env bash
#set -x
shopt -s expand_aliases
check_dependencies()
{
    # pip
    pip > /dev/null 2>&1
    if [ $? == 127 ]; then
        echo "pip command not found in path"
        pip3 > /dev/null 2>&1
        if [ $? == 127 ]; then
            echo "pip3 command not found in path"
            exit 1
        else
          PIP_COMMAND="pip3"
        fi
    else
      PIP_COMMAND="pip"
    fi

    # git
    git > /dev/null 2>&1
    if [ $? == 127 ]; then
        echo "git command not found in path"
        yum install git -y
    fi

    # wget
    wget > /dev/null 2>&1
    if [ $? == 127 ]; then
        echo "wget command not found in path"
        yum install wget -y
    fi

    # java
    java > /dev/null 2>&1
    if [ $? == 127 ]; then
        echo "java runtime command not found in path"
        exit 1
    fi

    # jenkins-job
    jenkins-jobs > /dev/null 2>&1
    if [ $? == 127 ]; then
        echo "jenkins-job command not found in path"
        ${PIP_COMMAND} install jenkins-job-builder
    fi
}

# Setup Jenkins CLI
setup_jenkins_cli()
{
    echo "Downloading CLI from ${JENKINS_CLI_URL}"
    wget --output-document=${JENKINS_CLI_PATH}/jenkins-cli.jar ${JENKINS_CLI_URL}
    if [[ $? -eq 0 ]]; then
      echo "Successfully downloaded the CLI."
    else
      echo "Error occurred while downloading the file the Jenkins Server."
    fi
}

setup_orchestrator_credentials()
{
  java -jar ${JENKINS_CLI} -s ${JENKINS_URL} -auth ${JENKINS_USER_ID}:${JENKINS_API_TOKEN} create-credentials-by-xml system::system::jenkins _  < $(pwd)/conf/credentials.xml
  echo "Jenkins Credentials setup. Ensure that 'authorized_keys' on the orchestrator host has the following public key ..."
  ssh-keygen -y -f ${host_pk_file}
}

# Install Plugins function
install_jenkins_plugins()
{
    export JENKINS_USER_ID=${JENKINS_USER_ID}
    export JENKINS_API_TOKEN=${JENKINS_API_TOKEN}

    declare -a JENKINS_PLUGIN_NAMES
    JENKINS_PLUGIN_NAMES[0]="pipeline-build-step:2.13"
    JENKINS_PLUGIN_NAMES[1]="pipeline-stage-step:2.5"
    JENKINS_PLUGIN_NAMES[2]="pipeline-utility-steps:2.6.1"
    JENKINS_PLUGIN_NAMES[3]="credentials-binding:1.23"
    JENKINS_PLUGIN_NAMES[4]="nodelabelparameter:1.7.2"

    for plugin_name in "${JENKINS_PLUGIN_NAMES[@]}"
    do
        echo "Installing plugin: $plugin_name"
        java -jar ${JENKINS_CLI} -s ${JENKINS_URL} install-plugin ${plugin_name}
    done
}

# Create SSH keys for Scale-CI
create_ssh_keys()
{
  ssh-keygen -t rsa -b 4096 -C "scale-ci@rbc" -N '' -f ~/.ssh/scale_ci_rsa
  [[ $? -eq 0 ]] && echo "Successfully created private key at ~/.ssh/scale_ci_rsa"
  touch ~/.ssh/authorized_keys
  echo "# For Scale-CI Orchestration" >> ~/.ssh/authorized_keys
  cat ~/.ssh/scale_ci_rsa >> ~/.ssh/authorized_keys
  echo "Successfully added to ~/.ssh/authorized_keys"
  systemctl reload sshd > /dev/null 2>&1
  [[ $? -eq 0 ]] && echo "Reloaded SSHD Service"
}

# Install static pipeline
setup_jenkins_jobs()
{
    # Build static job/workload
    jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/static/scale-ci-pipeline.yml > /dev/null 2>&1
    [[ $? -eq 0 ]] && echo "Successfully imported Main Pipeline Job"
    # Build dynamic job/workload
    while read workload_name
    do
        echo "Installing workload ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/dynamic/${workload_name}"
        jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/dynamic/${workload_name} > /dev/null 2>&1
        [[ $? -eq 0 ]] && echo "Successfully imported ${workload_name} Job"
    done < ${WORKLOAD_NAMES}
}

# Safely restart jenkins
restart_jenkins()
{
    # reload jenkins after plugin has been installed
    java -jar ${JENKINS_CLI} -s ${JENKINS_URL} safe-restart
}

print_usage()
{
    echo "usage: $0 <options>"
    echo "Setups the Scale-CI Orchestration"
    echo ""
    echo "-h,--help print this help"
    echo "--jenkins-user|-u Username for Jenkins URL"
    echo "--jenkins-password|-p Password for Jenkins URL"
    echo "--jenkins-url|-s Jenkins URL"
    echo "--host-user|-o Orchestration host username."
    echo "--host-pk-file|-k Private key file for the Orchestration host."
}

IFS=$'\n\t'

# Print usage
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            print_usage
            exit 1
            ;;
        --jenkins-user|-u)
            jenkins_user="$2"
            echo "Jenkins User: $jenkins_user"
            shift
            shift
            ;;
        --jenkins-password|-p)
            jenkins_password=$2
            echo "Jenkins Password/token: ****"
            shift
            shift
            ;;
        --jenkins-url|-s)
            jenkins_url=$2
            echo "Jenkins URL: $jenkins_url"
            shift
            shift
            ;;
        --host-user)
            host_user=$2
            echo "Host user: $host_user"
            shift
            shift
            ;;
        --host-pk-file|-k)
            host_pk_file=$2
            echo "Host private key path: $host_pk_file"
            shift
            shift
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            shift
            ;;
    esac
done
echo ""
set +u
set -- "${POSITIONAL[@]}" # restore positional parameters
REMAIN_OPTS="$1"
set -u

# Move this into the script
read -p 'Enter Scale-CI Pipeline Git Repo: ' WORKLOAD_REPO

if [[ -z ${WORKLOAD_REPO} ]]; then
  # Default Scale-CI Repo
  WORKLOAD_REPO=http://rbcgithub.fg.rbc.com/SFT0/scale-ci-pipeline
  echo "Falling back to default repo: ${WORKLOAD_REPO}"
fi

if [[ -z $jenkins_password ]]; then
  read -sp 'Enter Jenkins Password: ' jenkins_password
else
  echo "Password already provided. Ignoring Jenkins Password prompt."
fi

if [[ ! -e ${host_pk_file} || -z ${host_pk_file} ]]; then
  echo "Error: Private key file does not exist at ${host_pk_file}. Creating one"
  create_ssh_keys
  host_pk_file=~/.ssh/scale_ci_rsa
fi

# update workload-env.sh variables with args
sed -i.bak -e "s/JENKINS_USER_ID=.*/JENKINS_USER_ID=${jenkins_user}/g" $(pwd)/workload-env.sh
sed -i.bak -e "s/JENKINS_API_TOKEN=.*/JENKINS_API_TOKEN=${jenkins_password}/g" $(pwd)/workload-env.sh
sed -i.bak -e "s|JENKINS_URL=.*|JENKINS_URL=${jenkins_url}|g" $(pwd)/workload-env.sh && rm $(pwd)/workload-env.sh.bak

# update conf/jenkins-jobs.ini variables with args
sed -i.bak -e "s/user=.*/user=${jenkins_user}/g" $(pwd)/conf/jenkins-jobs.ini
sed -i.bak -e "s/password=.*/password=${jenkins_password}/g" $(pwd)/conf/jenkins-jobs.ini
sed -i.bak -e "s|url=.*|url=${jenkins_url}|g" $(pwd)/conf/jenkins-jobs.ini && rm $(pwd)/conf/jenkins-jobs.ini.bak

check_dependencies

# Source variables and create alias
source workload-env.sh

# Create credentials file
cat <<EOF >$(pwd)/conf/credentials.xml
<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.13">
    <scope>GLOBAL</scope>
    <id>ORCHESTRATION_HOST</id>
    <description>Private key for the Scale-CI Orchestration Host</description>
    <username>${host_user}</username>
    <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
        <privateKey>$(cat ${host_pk_file})</privateKey>
    </privateKeySource>
</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
EOF

if [ ! -d "${WORKDIR}" ] ; then
    # Make dir for cloning scale-ci repo and jenkins cli install dir
    mkdir -p ${WORKDIR} ${JENKINS_CLI_PATH}
    git clone ${WORKLOAD_REPO} ${WORKDIR} 2>/dev/null
else
    rm -rf ${WORKDIR}
    mkdir -p ${JENKINS_CLI_PATH}
    git clone ${WORKLOAD_REPO} ${WORKDIR} 2>/dev/null
fi

CLONE_SUCCESS=$?

if [ "${CLONE_SUCCESS}" = "0" ]; then
    echo "Clone successful"
    # configure jenkins cli
    setup_jenkins_cli

    # setup credentials for the job
    setup_orchestrator_credentials

    # install jenkins plugins
    install_jenkins_plugins

    # setup scale-ci jobs in jenkins
    setup_jenkins_jobs

    # restart jenkins
    restart_jenkins
else
    echo "Unable to clone git repo: ${WORKLOAD_REPO}"
fi
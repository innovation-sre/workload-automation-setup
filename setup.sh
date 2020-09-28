#!/usr/bin/env bash
#set -x

check_dependencies()
{
    # git
    git > /dev/null 2>&1 
    if [ $? == 127 ]; then
        echo "git command not found in path"
        exit
    fi

    # wget
    wget > /dev/null 2>&1 
    if [ $? == 127 ]; then
        echo "wget command not found in path"
        exit
    fi

    # java
    java > /dev/null 2>&1 
    if [ $? == 127 ]; then
        echo "java runtime command not found in path"
        exit
    fi

    # jenkins-job
    jenkins-jobs > /dev/null 2>&1 
    if [ $? == 127 ]; then
        echo "jenkins-job command not found in path"
        exit
    fi
}

# Setup Jenkins CLI
setup_jenkins_cli() 
{
    wget --output-document=${JENKINS_CLI_PATH}/jenkins-cli.jar --quiet ${JENKINS_CLI_URL}
    jenkins_cli="java -jar ${JENKINS_CLI} -s ${JENKINS_URL}"
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

    for plugin_name in ${JENKINS_PLUGIN_NAMES[@]}
    do
        echo "Installing plugin: $plugin_name"
        java -jar ${JENKINS_CLI} -s ${JENKINS_URL} install-plugin ${plugin_name}
    done
}

# Install static pipeline
setup_jenkins_jobs() 
{
    # Build static job/workload
    jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/static/scale-ci-pipeline.yml

    # Build dynamic job/workload
    while read workload_name
    do
        echo "Installing workload ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/dynamic/${workload_name}"
        jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/dynamic/${workload_name}
    done < ${WORKLOAD_NAMES}
}

# Main section
# check script dependencies are available
check_dependencies

# Source variables
source workload-env.sh

# Make dir for cloning scale-ci repo and jenkins cli install dir
mkdir ${WORKDIR} ${JENKINS_CLI_PATH}

# Clone Workload repository
git clone ${WORKLOAD_REPO} ${WORKDIR}
CLONE_SUCCESS=$?

if [ "${CLONE_SUCCESS}" = "0" ]; then
    echo "Clone successful"
    setup_jenkins_cli

    install_jenkins_plugins

    setup_jenkins_jobs
else
    echo "Unable to clone git repo: ${WORKLOAD_REPO}"
fi
#!/usr/bin/env bash
#set -x

# set variables
source workload-env.sh

# Delete Jenkins Jobs
remove_jenkins_jobs()
{
    declare -a job_names
    job_names[0]="ATS-SCALE-CI-HPA"
    job_names[1]="ATS-SCALE-CI-CONFORMANCE"
    job_names[2]="ATS-SCALE-CI-HTTP"
    job_names[3]="ATS-SCALE-CI-MASTERVERTICAL"
    job_names[4]="SCALE-CI-PIPELINE"
    job_names[5]="ATS-SCALE-CI-NODEVERTICAL"
    job_names[6]="ATS-SCALE-CI-FIO"

    export JENKINS_USER_ID=${JENKINS_USER_ID}
    export JENKINS_API_TOKEN=${JENKINS_API_TOKEN}

    for job in ${job_names[@]}
    do 
        echo "Deleting jenkins job: ${job}"
        java -jar ${JENKINS_CLI} -s ${JENKINS_URL} delete-job ${job}
    done
}

# Uninstall Plugins function
uninstall_jenkins_plugins()
{
    export JENKINS_USER_ID=${JENKINS_USER_ID}
    export JENKINS_API_TOKEN=${JENKINS_API_TOKEN}

    declare -a JENKINS_PLUGIN_NAMES
    JENKINS_PLUGIN_NAMES[0]="pipeline-build-step"
    JENKINS_PLUGIN_NAMES[1]="pipeline-stage-step"
    JENKINS_PLUGIN_NAMES[2]="pipeline-utility-steps"
    JENKINS_PLUGIN_NAMES[3]="credentials-binding"
    JENKINS_PLUGIN_NAMES[4]="nodelabelparameter"
    JENKINS_PLUGIN_NAMES[5]="image-gallery:2.0.2"

    for plugin_name in ${JENKINS_PLUGIN_NAMES[@]}
    do
        echo "Disable plugin: $plugin_name"
        java -jar ${JENKINS_CLI} -s ${JENKINS_URL} disable-plugin ${plugin_name}
    done
}

# Remove cloned dir
remove_scale_ci_dir() {
    echo "File-system clean-up"
    rm -rf ${WORKDIR} ${JENKINS_CLI_PATH}
}

# Delete Jenkins Jobs
remove_jenkins_jobs

# Uninstalled jenkins plugins
uninstall_jenkins_plugins

# Call Remove cloned dir
remove_scale_ci_dir
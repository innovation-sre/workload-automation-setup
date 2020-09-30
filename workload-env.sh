#!/usr/bin/env bash

# Jenkins user
JENKINS_USER_ID=admin

#Jenkins API token
JENKINS_API_TOKEN=112607e9d2569c89e331bcd7f235d6ec18

# Jenkins host
JENKINS_URL=http://localhost:9090

# Jenkins node label
JENKINS_NODE_LABEL=scale-ci

# Jenkins Plugin Dir
JENKINS_PLUGIN_DIR=$(pwd)

# Jenkins plugins to install
JENKINS_PLUGIN_NAMES=${JENKINS_PLUGIN_DIR}/conf/plugins.txt

# Jenkins CLI
JENKINS_CLI_URL=${JENKINS_URL}/jnlpJars/jenkins-cli.jar

#Jenkins CLI path
JENKINS_CLI_PATH=$(pwd)/bin

#Jenkins CLI 
JENKINS_CLI=${JENKINS_CLI_PATH}/jenkins-cli.jar

# INSTALL DIR
WORKDIR=scale-ci

# WORKLOAD AUTOMATION REPO
WORKLOAD_REPO=https://github.com/innovation-sre/scale-ci-pipeline.git

# List of Workloads to install
WORKLOAD_NAMES_DIR=$(pwd)
WORKLOAD_NAMES=${WORKLOAD_NAMES_DIR}/conf/workloads.txt

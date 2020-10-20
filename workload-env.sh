#!/usr/bin/env bash

# Jenkins user
JENKINS_USER_ID=_USERNAME_

#Jenkins API token
JENKINS_API_TOKEN=_TOKEN_

# Jenkins host
JENKINS_URL=_URL_

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

# List of Workloads to install
WORKLOAD_NAMES_DIR=$(pwd)
WORKLOAD_NAMES=${WORKLOAD_NAMES_DIR}/conf/workloads.txt

alias jenkins_cli="java -jar ${JENKINS_CLI} -s ${JENKINS_URL} -auth ${JENKINS_USER_ID}:${JENKINS_API_TOKEN}"

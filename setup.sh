#!/usr/bin/env bash
set -x

source workload-env.sh

mkdir $WORKDIR 

git clone ${WORKLOAD_REPO} ${WORKDIR}

# Build scale-ci-pipeline job/workload
jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKDIR}/jjb/static/scale-ci-pipeline.yml

# Build ci_conformance job/workload
jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKDIR}/jjb/dynamic/scale-ci_conformance.yml

# Build mastervertical workload
jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKDIR}/jjb/dynamic/scale-ci_mastervertical.yml 

# Build nodevertical workload
jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKDIR}/jjb/dynamic/scale-ci_nodevertical.yml

# Build HTTP workload
jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKDIR}/jjb/dynamic/scale-ci_http.yml
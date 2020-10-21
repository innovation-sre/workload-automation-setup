#!/usr/bin/env bash
#set -x
shopt -s expand_aliases

# The following function prints a text using custom color
# -c or --color define the color for the print. See the array colors for the available options.
# -n or --noline directs the system not to print a new line after the content.
# Last argument is the message to be printed.
cecho () {

    declare -A colors;
    colors=(\
        ['black']='\E[0;47m'\
        ['red']='\E[0;31m'\
        ['green']='\E[0;32m'\
        ['yellow']='\E[0;33m'\
        ['blue']='\E[0;34m'\
        ['magenta']='\E[0;35m'\
        ['cyan']='\E[0;36m'\
        ['white']='\E[0;37m\E[1m'\
    );

    local default_msg="No message passed.";
    local default_color="white";
    local default_newline=true;

    while [[ $# -gt 1 ]];
    do
    key="$1";

    case $key in
        -c|--color)
            color="$2";
            shift;
        ;;
        -n|--noline)
            default_newline=false;
        ;;
        *)
            # unknown option
        ;;
    esac
    shift;
    done

    message=${1:-$default_msg};   # Defaults to default message.
    color=${color:-$default_color};   # Defaults to default color, if not specified.
    default_newline=${default_newline:-$default_newline};

    echo -en "${colors[$color]}";
    echo -en "$message";
    if [ "$default_newline" = true ] ; then
        echo;
    fi
    tput sgr0; #  Reset text attributes to normal without clearing screen.

    return;
}

warning() {
    cecho -c 'yellow' "$@";
}

error() {
    cecho -c 'red' "$@";
}

info() {
    cecho -c 'blue' "$@";
}

question() {
    cecho -c 'white' -n "$@";
}

info_bold() {
    cecho -c 'white' -n "$@";
}

check_dependencies()
{
    # pip
    pip > /dev/null 2>&1
    if [ $? == 127 ]; then
        warning "pip command not found in path. Trying to fall back to pip3"
        pip3 > /dev/null 2>&1
        if [ $? == 127 ]; then
            error "pip3 command not found in path"
            exit 1
        else
          info "pip3 found in path"
          PIP_COMMAND="pip3"
        fi
    else
      PIP_COMMAND="pip"
    fi

    # git
    git > /dev/null 2>&1
    if [ $? == 127 ]; then
        error "git command not found in path"
        yum install git -y
    fi

    # wget
    wget > /dev/null 2>&1
    if [ $? == 127 ]; then
        error "wget command not found in path"
        yum install wget -y
    fi

    # java
    java > /dev/null 2>&1
    if [ $? == 127 ]; then
        error "java runtime command not found in path"
        exit 1
    fi

    # jenkins-job
    jenkins-jobs > /dev/null 2>&1
    if [ $? == 127 ]; then
        error "jenkins-job command not found in path"
        ${PIP_COMMAND} install jenkins-job-builder
    fi
}

# Setup Jenkins CLI
setup_jenkins_cli()
{
    info "Downloading CLI from ${JENKINS_CLI_URL}"
    rm -f ${JENKINS_CLI_PATH}/jenkins-cli.jar
    wget --output-document=${JENKINS_CLI_PATH}/jenkins-cli.jar -nv ${JENKINS_CLI_URL}
    if [[ $? -eq 0 ]]; then
      info "Successfully downloaded the CLI."
    else
      warning "Error occurred while downloading the file the Jenkins Server."
    fi
}

setup_orchestrator_credentials()
{
  ret_val=$(java -jar ${JENKINS_CLI} -s ${JENKINS_URL} -auth ${JENKINS_USER_ID}:${JENKINS_API_TOKEN} create-credentials-by-xml system::system::jenkins _  < $(pwd)/conf/credentials.xml)
  info "Successfully set up Jenkins SSH Credentials. Ensure that 'authorized_keys' on the orchestrator host has the following public key ..."
#  ssh-keygen -y -f ${host_pk_file}
}

setup_github_credentials()
{
  ret_val=$(java -jar ${JENKINS_CLI} -s ${JENKINS_URL} -auth ${JENKINS_USER_ID}:${JENKINS_API_TOKEN} create-credentials-by-xml system::system::jenkins _  < $(pwd)/conf/credentials_git.xml)
  info "Successfully set up Jenkins Github Credentials."
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
        java -jar ${JENKINS_CLI} -s ${JENKINS_URL} install-plugin ${plugin_name}
    done
}

# Create SSH keys for Scale-CI
create_ssh_keys()
{
  ssh-keygen -t rsa -b 4096 -C "scale-ci@jenkins" -N '' -f ~/.ssh/scale_ci_rsa
  [[ $? -eq 0 ]] && info "Successfully created private key at ~/.ssh/scale_ci_rsa"
  touch ~/.ssh/authorized_keys
  echo "# For Scale-CI Orchestration" >> ~/.ssh/authorized_keys
  cat ~/.ssh/scale_ci_rsa >> ~/.ssh/authorized_keys
  info "Successfully added to ~/.ssh/authorized_keys"
  systemctl reload sshd > /dev/null 2>&1
  [[ $? -eq 0 ]] && info "Reloaded SSHD Service"
}

# Install static pipeline
setup_jenkins_jobs()
{
    # Build static job/workload
    jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/static/scale-ci-pipeline.yml > /dev/null 2>&1
    [[ $? -eq 0 ]] && info "Successfully imported Main Pipeline Job"
    # Build dynamic job/workload
    while read workload_name
    do
        warning "Installing workload ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/dynamic/${workload_name}"
        jenkins-jobs --conf conf/jenkins-jobs.ini update ${WORKLOAD_NAMES_DIR}/${WORKDIR}/jjb/dynamic/${workload_name} > /dev/null 2>&1
        [[ $? -eq 0 ]] && info "Successfully imported ${workload_name} Job"
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
info "---------------------------------------------"
info "          Bootstrap Parameters               "
info "---------------------------------------------"
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
            info "Jenkins User: $jenkins_user"
            shift
            shift
            ;;
        --jenkins-password|-p)
            jenkins_password=$2
            info "Jenkins Password/token: ****"
            shift
            shift
            ;;
        --jenkins-url|-s)
            jenkins_url=$2
            info "Jenkins URL: $jenkins_url"
            shift
            shift
            ;;
        --host-user)
            host_user=$2
            info "Host user: $host_user"
            shift
            shift
            ;;
        --host-pk-file|-k)
            host_pk_file=$2
            info "Host private key path: $host_pk_file"
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
info "---------------------------------------------"
echo -e "\n\n"
set +u
set -- "${POSITIONAL[@]}" # restore positional parameters
REMAIN_OPTS="$1"
set -u

# Move this into the script
question 'Enter Scale-CI Pipeline Git Repo [Default: https://github.com/innovation-sre/scale-ci-pipeline]: '
read WORKLOAD_REPO

DEFAULT_PREFIX=https://github.com/innovation-sre

if [[ -z ${WORKLOAD_REPO} ]]; then
  # Default Scale-CI Repo
  WORKLOAD_REPO=https://github.com/innovation-sre/scale-ci-pipeline
fi

repo_name="${WORKLOAD_REPO##*/}"
prefix="${WORKLOAD_REPO%/*}"
git_hostname="${prefix##*https://}"

# Parse Github Username and Password if already part of the repo provided.
if [[ "$WORKLOAD_REPO" == *"@"* ]]; then
  USER_PASSWD=${git_hostname%@*}
  github_username=${USER_PASSWD%:*}
  github_password=${USER_PASSWD##*:}
  warning "Parsed the Git username and password from repo provided."
fi

set +u

# Read Github Username only if it is not present
while true; do
  if [[ -z "$github_username" ]]; then
    question 'Enter Github Username: '
    read github_username
  else
    break
  fi
done

# Read Github Password only if it is not present
while true; do
  if [[ -z "$github_password" ]]; then
    question 'Enter Github Password: '
    read -s github_password
    echo
  else
    break
  fi
done

while true; do
  if [[ -z $jenkins_password ]]; then
    question 'Enter Jenkins Password: '
    read -s jenkins_password
    echo
  else
    break
  #else
  #  warning "Password already provided. Ignoring Jenkins Password prompt."
  fi
done

set -u

# If github username and password are separately specified and not part of the repo provided
if [[ -n "$github_username" && -n "$github_password" && "$WORKLOAD_REPO" != *"@"* ]]; then
  WORKLOAD_REPO="https://${github_username}:${github_password}@${git_hostname}/${repo_name}"
  warning "Updated repo to ${WORKLOAD_REPO}"
fi


if [[ ! -e ${host_pk_file} || -z ${host_pk_file} ]]; then
  warning "Error: Private key file does not exist at ${host_pk_file}. Creating one"
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

cat <<EOF > $(pwd)/conf/credentials_git.xml
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl plugin="credentials@2.1.14">
  <scope>GLOBAL</scope>
  <id>GITHUB_REPO</id>
  <username>${github_username}</username>
  <password>${github_password}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF

if [ ! -d "${WORKDIR}" ] ; then
    # Make dir for cloning scale-ci repo and jenkins cli install dir
    mkdir -p ${WORKDIR} ${JENKINS_CLI_PATH}
    git clone ${WORKLOAD_REPO} ${WORKDIR}
else
    rm -rf ${WORKDIR}
    mkdir -p ${JENKINS_CLI_PATH}
    git clone ${WORKLOAD_REPO} ${WORKDIR}
fi


CLONE_SUCCESS=$?
if [ "${CLONE_SUCCESS}" = "0" ]; then
    info "Clone successful"

    if [[ "${DEFAULT_PREFIX}" != "${prefix}" ]]; then
      warning "Updating references for ${prefix}"
      find ${WORKDIR}/jjb -type f -name .git -prune -o -type f -exec sed -i "s#${DEFAULT_PREFIX}#${prefix}#g" {} +
      info "Successfully updated references for ${prefix}"
    fi

    # configure jenkins cli
    setup_jenkins_cli

    # setup credentials for the job
    setup_orchestrator_credentials
    setup_github_credentials

    # install jenkins plugins
    install_jenkins_plugins

    # setup scale-ci jobs in jenkins
    setup_jenkins_jobs

    # restart jenkins
    restart_jenkins

    info_bold "\nAll done here! You can now execute workloads from ${JENKINS_URL}/job/SCALE-CI-PIPELINE/ \n\n"
else
    echo "Unable to clone git repo: ${WORKLOAD_REPO}"
fi
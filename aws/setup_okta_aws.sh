#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 DE:AD:10:C5 <franklin@dead10c5.org>
#
# SPDX-License-Identifier: GPL-3.0-or-later

#set -euo pipefail
#IFS=$'\n\t'

# Tue Mar 30 09:40:40 AM EST 2021
# Wed Jul 28 07:24:20 AM EDT 2021 :: Update on checking OKTA username

# Based on this Confluence page: 
# https://confluence.paloaltonetworks.local/pages/viewpage.action?spaceKey=IS&title=How+to+install+gimme-aws-creds+and+log+in+via+OKTA

#set -o nounset  # Treat unset variables as an error

#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37

RED='\033[0;31m'
#LRED='\033[1;31m'
#LGREEN='\033[1;32m'
CYAN='\033[0;36m'
#LPURP='\033[1;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MY_OS="unknown"

# If your user name on this host does not match your okta user name, 
# you can correct this by passing your username as an argument to this script
if [ ! -z "$1" ]; then 
  OKTA_USER="${1}"
else 
  OKTA_USER=""
fi

function check_if_root() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Dont run this script as root.${NC}"
    exit 1
  fi
}

function detect_os() {
    if [ "$(uname)" == "Darwin" ]
    then
        echo -e "${CYAN}Deteted MacOS${NC}"
        MY_OS="mac"
    elif [ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]
    then
        echo -e "${CYAN}Detected Debian/Ubuntu/Mint${NC}"
        MY_OS="deb"
    elif grep -q Microsoft /proc/version
    then
        echo -e "${CYAN}Detected Windows pretending to be Linux${NC}"
        MY_OS="win"
    else
        echo -e "${YELLOW}Unrecongnized architecture.${NC}"
        exit 1
    fi
}

# Otherwise we go with the name you logged in as.
function check_okta_user {
  if [ ! -z $OKTA_USER ]; then
    echo -e "${CYAN}OKTA username set as: ${YELLOW}$OKTA_USER${NC}"
  else
    OKTA_USER=$(whoami)
    echo -e "${CYAN}No OKTA username set in script. Guessing your username as: ${YELLOW}$OKTA_USER${NC}"
    echo -e "${CYAN}Update the OKTA_USER variable in the script if this is not what you want.${NC}"
  fi
}

function write_config() {
    echo -e "${CYAN}Writing user config file to home directory.${NC}"
cat <<EOF > ${HOME}/.okta_aws_login_config
[DEFAULT]
okta_org_url = https://paloaltonetworks.okta.com
okta_auth_server =
client_id =
gimme_creds_server = appurl
aws_appname = AWS Universal IDP
aws_rolename = all
write_aws_creds = True
cred_profile = default
okta_username = ${OKTA_USER}
app_url = https://paloaltonetworks.okta.com/home/amazon_aws/0oae0k7sqyScYDeY31t7/272
resolve_aws_alias = True
include_path = True
preferred_mfa_type = push
remember_device = True
aws_default_duration = 3600
device_token =
output_format = export
EOF
}

# Making sure they have Python3 installed.
function check_python(){
    pyv="$(python3 -V 2>&1)"
    if [ -n "$pyv" ]; then
        echo -e "${CYAN}Found Python3: ${YELLOW}${pyv}${NC}"
    else
        echo -e "${RED}Python3 not found${NC}"
        exit 1
    fi
}

# Create a Python3 virtual environment. This will keep the application dependencies
# contained to a working directory and avoid conflicts with whatever Python modules
# they already have installed.
function python_venv {
    echo -e "${CYAN}Setting up Python3 venv${NC}"
    python3 -m venv _build
    echo -e "${CYAN}Starting Python3 venv${NC}"
    if [ -d "_build" ] ; then . ./_build/bin/activate; fi
    if [ ! -f "_build/bin/pip3" ]; then
        echo -e "${CYAN}Installing Python3 packages${NC}"
        venv/bin/python3 -m pip install -U pip
        venv/bin/python3 -m pip install gimme-aws-creds
    fi
}

function main() {
    echo -e "${CYAN}OPTIONAL: Call the script with \"source\" to export the creds as environment vars. For example: ${YELLOW}source bin/setup_okta_aws.sh${NC}" 
    check_if_root
    detect_os
    check_okta_user
    if [ -f "${HOME}/.okta_aws_login_config" ]; then 
        echo -e "${CYAN}NOT overwriting your existing configuration file: ~/.okta_aws_login_config${NC}"
    else 
        write_config
    fi
    check_python
    python_venv
    echo -e "${CYAN}Running gimme creds${NC}"
    gimme-aws-creds -u ${OKTA_USER}

    if [ -f "${HOME}/.aws/credentials" ]; then
        echo -e "${CYAN}Exporting AWS credentials from ${HOME}/.aws/credentials${NC}"
        AWS_ACCESS_KEY_ID=$(cat ${HOME}/.aws/credentials | grep aws_access_key_id | cut -f2 -d"=")
        # now remove that annoying leading space
        export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID#"${AWS_ACCESS_KEY_ID%%[![:space:]]*}"}"
        AWS_SECRET_ACCESS_KEY=$(cat ${HOME}/.aws/credentials | grep aws_secret_access_key | cut -f2 -d"=")
        # now remove that annoying leading space
        export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY#"${AWS_SECRET_ACCESS_KEY%%[![:space:]]*}"}"
        AWS_SECURITY_TOKEN=$(cat ${HOME}/.aws/credentials | grep aws_security_token | cut -f2 -d"=")
        # now remove that annoying leading space
        export AWS_SECURITY_TOKEN="${AWS_SECURITY_TOKEN#"${AWS_SECURITY_TOKEN%%[![:space:]]*}"}"
    else
        echo -e "${RED}${HOME}/.aws/credentials not found${NC}"
    fi

    if [ "${MY_OS}" == "mac" ]; then
        open https://paloaltonetworks.okta.com/home/amazon_aws/0oae0k7sqyScYDeY31t7/272
        #venv/bin/python3 -m webbrowser -n https://paloaltonetworks.okta.com/home/amazon_aws/0oae0k7sqyScYDeY31t7/272
        echo -e "${CYAN}If your browser did not open, navigate to ${YELLOW}https://paloaltonetworks.okta.com/home/amazon_aws/0oae0k7sqyScYDeY31t7/272${CYAN} for AWS Universal IDP${NC}"
    fi

    if [ ! -d "/nix" ]; then
        echo -e "${CYAN}Deactivate python venv${NC}"
        deactivate
    fi
}

main

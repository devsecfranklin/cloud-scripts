#!/bin/bash

#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37

RED='\033[0;31m'
LRED='\033[1;31m'
LGREEN='\033[1;32m'
CYAN='\033[0;36m'
LPURP='\033[1;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MY_OS="unknown"
TERRAFORM_LINK="https://releases.hashicorp.com/terraform/1.2.3/terraform_1.2.3_linux_amd64.zip"

function detect_os() {
    if [ "$(uname)" == "Darwin" ]
    then
        echo -e "${CYAN}Detected MacOS${NC}"
        MY_OS="mac"
    elif [ -f "/etc/redhat-release" ]
    then
        echo -e "${CYAN}Detected Red Hat/CentoOS/RHEL${NC}"
        MY_OS="rh"
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

function macos() {
  echo -e "${CYAN}Updating brew for MacOS (this may take a while...)${NC}"
  brew cleanup
  brew upgrade
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
}

function debian() {
  sudo apt update && sudo apt upgrade -y
  # curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  # sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  # sudo apt-get update && sudo apt-get install terraform
}

function redhat() {
  sudo yum update -y
  sudo yum install wget -y
  wget
}

function amazon_linux() {
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  sudo yum -y install terraform
}

function shell_manual(){
  TF_FILE=`echo ${TERRAFORM_LINK} |  tr '/' '\n' | tail -n1`

  if [ ! -f "${TF_FILE}" ]; then
    echo -e "${CYAN}Download new: ${TF_FILE}${NC}"
    wget ${TERRAFORM_LINK}
  else
    echo -e "${CYAN}Use existing: ${TF_FILE}${NC}"
  fi

  echo -e "${CYAN}Uncompressing ${TF_FILE}${NC}"
  unzip ${TF_FILE}
  ./terraform -version # validate it
  echo -e "${CYAN}Installing ${TF_FILE} to /usr/local/bin${NC}"
  sudo mv ./terraform /usr/local/bin
}
function main() {
  detect_os
  if [ "${MY_OS}" == "mac" ]; then
    macos
  fi

  # RHEL, CentOS, etc.
  if [ "${MY_OS}" == "rh" ]; then
    redhat
    shell_manual
  fi

  # Ubuntu and Debian
  if [ "${MY_OS}" == "deb" ]; then
    debian
    shell_manual
  fi

  # Amazon Linux

}

main
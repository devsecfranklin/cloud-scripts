#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 DE:AD:10:C5 <franklin@dead10c5.org>
#
# SPDX-License-Identifier: GPL-3.0-or-later

# ChangeLog:
#
# v0.1 10/05/2024 initial version

# Run this tool from the jump host or the GCP console

# Palo Alto Lab Labels:

# nonstop-reason test-pipeline
# nonstop_expected_end_date dec-2025
# lab-franklin nam-ps-east
# runstatus nonstop

#set -x
#set -euo pipefail
#set -euf -x -o pipefail

# The special shell variable IFS determines how Bash
# recognizes word boundaries while splitting a sequence of character strings.
#IFS=$'\n\t'

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
LBLUE='\033[1;34m'
CYAN='\033[0;36m'
LCYAN='\033[1;36m'
LPURP='\033[1;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Some config Variables ----------------------------------------
declare -a fw_names
declare -A my_arr
DATA_DIR="/tmp/palo/data"
LOGGING_DIR="/tmp/palo/log"
MY_DATE=$(date '+%Y-%m-%d-%H')
RAW_OUTPUT="palo_gcloud_deploy_${MY_DATE}.txt" # log file name
#SSH_KEY='admin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCu+5vKjTtTWZwlDlm7AlmQdWKujHq7cWnoeJZa/sUGNj+rg8d+SfJZCF+cSuOEFxqJ6wVbX5WSAvB0MNETtncVsC6NvKNSGFsc8vIrIas5cQtyk8frp6SA9aJ/M90p2ekYwPVhqshGCLiRZ1enbm+8uvpGZkWW/g7eQV8HbxFnFCsdf9JZzHcnXWOD8tkRO9r/uuIX31BmVxEG2YE8IPC3Xq18hGglLsi0vOGdBicfOGGc/DRsw6wxXSjXF66nJAxmKZgg4lWzNIe8MkEJthI9cWPsTWcJC3XPpRuKQY6crofZa+atwkymhYJ/MUIJW4172cWLpbA1+4dvSFKSUpyo/Qs+0Zpft8vVvceaDhOsNCpzKk/qINZ3Z+Q/B4I9Ribw83K3FwfAlr6t35Z4j7cCw3VrlJtyVHrwUnVwkCNuw2zcWISfXSnCCFyVgxiJltnqk6CBOUfk6P3qIXqvQqQqp3cB1SiimVtSN5bzITiNnAdySnOUYJIsmMxkPH0Qua8cOQNNs2Ns9zAjgilTZtzG0siJtWmHJrg8+3jMG5mwzOvIgT3DadAx5ao1/+8ak4gBfoqSrLSJXPwW8Myl/I3/uxVkbxb4+jjJwnxKsbGS5LnfVGSvqEFXgtGYfNz79emdIWf3Tbh6Lv9+3Rrt9maCPg3/i5QtWBpaflI2RxurbQ== fdiaz@paloaltonetworks.com'
 SSH_KEY='admin:ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAuGlWP+TBdHo3ixHg/NCVGCJuqeLO+jWklyLEVHrzJPRqz69XGqtZR40KgOI2sItuoLm1Us3ja6WeauSssDkcoZBuzdO9fF999w/FoPa+yGu6GzBxQ2m4Q8pYznDqKuGVKxIb0aoj5XL/mYcD8EZxuh0Oa3lE/wx7cV8qiL3uaVwEfB9MgbqO+i6flmrwLzmL5fJVNmF9L6dI1d1NDruwSxtj9/jgFXyDqrX+NVFSUsiKBF0Rjp60+XR6MhXewTghxvhVFqhLz+fOItSDpRzFVdgoxuEMFnAYGJyVUUi5HKTHNhoDflHb+DZ5YthZ/vEOAxfOzXohNg/VSkcrxXSrsQ== admin@Rob'
YAML_FILE="deploy_fw.yaml"

function usage() {
  # Display Help
  echo -e "\n${YELLOW}Deploy GCP FW script."
  echo
  echo "Syntax: ${0} [-h|-t]"
  echo "options:"
  echo "-h     Print this Help."
  echo -e "-t     Test the YAML file.\n${NC}"
}

function directory_setup() {
  if [ ! -d "${LOGGING_DIR}" ]; then
    echo -e "${LRED}Did not find log dir: ${LCYAN}${LOGGING_DIR}${NC}"
    mkdir -p ${LOGGING_DIR}
    echo -e "${LGREEN}Creating logging directory: ${LCYAN}${LOGGING_DIR}${NC}" | tee -a "${RAW_OUTPUT}"
  fi

  RAW_OUTPUT="${LOGGING_DIR}/${RAW_OUTPUT}"

  echo -e "\n${LCYAN}------------------ Starting GCP Deployment Tool ------------------${NC}" | tee -a "${RAW_OUTPUT}"
  echo -e "${LGREEN}Log file path is: ${LCYAN}${RAW_OUTPUT}${NC}" | tee -a "${RAW_OUTPUT}"

  if [ ! -d "${DATA_DIR}" ]; then
    echo -e "${LRED}Did not find data dir: ${LCYAN}${DATA_DIR}${NC}"
    mkdir -p ${DATA_DIR}
  fi
  echo -e "${LGREEN}Data directory is: ${LCYAN}${DATA_DIR}${NC}" | tee -a "${RAW_OUTPUT}"
}

function check_installed() {
  if ! command -v ${1} &>/dev/null; then
    echo -e "${LRED}${1} could not be found${NC}"
    return 1
  else
    echo -e "${LPURP}Found command: ${1}${NC}"
    return 0
  fi
}

function parse_yaml {
  #local prefix=${2}
  local prefix=""
  #if [ -z ${2+x} ]; then echo -e "${LGREEN}YAML local_prefix is unset${NC}"; local prefix=""; else echo -e "${LGREEN}YAML local_prefix is set to '$var'${NC}" | tee -a "${RAW_OUTPUT}"; local prefix=${2}; fi

  # erase the trailing vn="" on line 81 to prepend the fwname to var name
  i=0
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*'
  local fs
  local key=""
  local val=""
  fs=$(echo @|tr @ '\034')

  doo_doo=$(sed -ne "s|^\($s\):|\1|" \
      -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    for line in $( awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_");vn=""}
        printf("%s%s%s \"%s\"\n", "'$prefix'",vn, $2, $3);}}'
      );
    do
      if [[ $((i % 2)) -eq 0 ]]; then
        key=$(echo $line|cut -f1 -d"=");
      else
        val=$(echo $line|cut -f2- -d"=")
      fi
      i=$((i+1))
    done)
    printf -v key "%q" "$key"
    printf -v val "%q" "$val"
    my_arr["$key"]+="${val}"
    echo ${doo_doo} # this line is needed so we can capture the output from the child process
}

function deploy_firewall() {
  # change "no-address" to "address" to get a public IP
  gcloud compute instances create ${my_arr["FW_NAME"]} \
    --zone=${my_arr["FW_ZONE"]} \
    --machine-type=${my_arr["INSTANCE_TYPE"]} \
    --boot-disk-size=${my_arr["DISK_SIZE"]} \
    --boot-disk-type=${my_arr["DISK_TYPE"]} \
    --network-interface subnet=${my_arr["UNTRUST_SUBNET"]},address \
    --network-interface subnet=${my_arr["MGMT_SUBNET"]},address \
    --network-interface subnet=${my_arr["TRUST_SUBNET"]},no-address \
    --image-project=${my_arr["INSTANCE_PROJECT"]} \
    --image=${my_arr["IMAGE"]} \
    --maintenance-policy=MIGRATE \
    --can-ip-forward \
    --tags=${my_arr["TAGS"]} \
    --metadata="block-project-ssh-keys=true,ssh-keys=${my_arr["SSH_KEY"]},serial-port-enable=false,mgmt-interface-swap=enable,type=dhcp-client,panorama-server=${my_arr["PANORAMA1"]},panorama-server-2=${my_arr["PANORAMA2"]},tplname=${my_arr["TEMPLATE"]},dgname=${my_arr["DEVICEGROUP"]},hostname=${my_arr["FW_NAME"]},dns-primary=${my_arr["DNS"]},vm-auth-key=$AUTHKEY,dhcp-accept-server-hostname=yes,dhcp-accept-server-domain=yes" |
    tee -a "${RAW_OUTPUT}"
}

function test_array() {

  # check to make sure the fields all exist in the YAML
  declare -a my_fields=( "KEY" )
  for i in "${!my_arr[@]}"
  do
    echo "key  : $i"
    echo "value: ${my_arr[$i]}"
  done

  echo -e "final length: ${#my_arr[@]}"
  for key in "${!my_arr[@]}"; do
    echo -e "key: $key"
  done
  for i in "${!my_arr[@]}"
  do
  echo -e "${i}=${my_arr[$i]}"
  done
  if [[ -n "${my_arr["FW_NAME"]}" ]]
  then
    echo -e "True"
  else
    echo -e "False"
  fi
  exit 0
}

function main() {
cat <<"EOF"
                     .
         /^\     .
    /\   "V"
   /__\   I      O  o
  //..\\  I     .
  \].`[/  I
  /l\/j\  (]    .  O
 /. ~~ ,\/I          .
 \\L__j^\/I       o
  \/--v}  I     o   .
  |    |  I   _________
  |    |  I c(`       ')o
  |    l  I   \.     ,/
_/j  L l\_!  _//^---^\\_    deploy_fw_gcp.sh
EOF

  while getopts "ht" opt; do
    case "${opt}" in
    h)
      usage
      exit 0
      ;;
    t)
      TESTING=true
      echo -e "${LGREEN}Test the YAML file.${NC}"
      ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      usage
      exit 1
      ;;
    esac
  done

  # shift "$(( OPTIND - 1 ))" # is this needed

  directory_setup # the logging directory

  # load the YAML file
  if [ ! -f "${YAML_FILE}" ]; then
    echo -e "${LRED}Unable to find YAML file: ${YAML_FILE}${NC}" | tee -a "${RAW_OUTPUT}"
    exit 1
  else
    if check_installed yamllint; then
      echo -e "${LGREEN}Validating YAML file: ${LCYAN}${YAML_FILE}${NC}" | tee -a "${RAW_OUTPUT}"
      yamllint ${YAML_FILE}
    else
      echo -e "${LRED}yamllint could not be found, skipping YAML validation${NC}" | tee -a "${RAW_OUTPUT}"
    fi
    echo -e "${LGREEN}Loading YAML file: ${LCYAN}${YAML_FILE}${NC}" | tee -a "${RAW_OUTPUT}"
    result=$(parse_yaml ${YAML_FILE})
  fi

  while IFS='' read -r first second
  do
    fixed=$(echo ${first} | cut -f1 -d" " | cut -f1 -d":" ) # trailing colon?
    printf -v key "$fixed"
    val=$(echo $first | cut -f2 -d" ")
    if [ "${key}:" != "$val" ];
    then
       eval my_arr["$key"]+="${val}"
    else
      echo -e "${LGREEN}Found firewall: ${LCYAN}${key}${NC}"
      if [ "${key}:" != "DISK:" ] && [ "${key}:" != "INSTANCE:" ];
      then
        eval fw_names+=("${key}")
      fi
    fi
  done < ${YAML_FILE}

  if [ "${TESTING}" = true ]; then test_array; fi # validate the YAML file

  # example auth key: 2:9KD16LjLR_OSGlJKUAU0Mq3uSVu1k0K1pfLkNCZ9zLCkPl-Oe7m64WzQtXLswbcGVMyorgc_5CO3mO5w8FKx8g
  echo -e "${LGREEN}Generate auth key from Panorama CLI like so: ${LPURP}request bootstrap vm-auth-key generate lifetime 8760${NC}" | tee -a "${RAW_OUTPUT}"
  echo -e "${LGREEN}Enter your auth key: ${NC}"
  read -p ""
  # echo ${fw_names[*]}

  # add check to be sure subnets exist in GCP

  # add a check for DG and STK on Panorama

  for k in "${fw_names[@]}"; do
    echo -e "${YELLOW}Deploying firewall: ${k}${NC}" | tee -a "${RAW_OUTPUT}"
    FW_NAME="${k}"
    deploy_firewall
  done
}

main "$@"

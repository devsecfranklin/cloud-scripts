#!/usr/bin/env bash

# ------------------------------------------------------------------
# Author: Franklin D <devsecfranklin@duck.com>
#
#     Shell script to gather details about OpenShift configuration.
#
# Repository:
#
#     https://github.com/devsecfranklin/cloud-scripts
#
# Example:
#
#     Run the script twice on two different namespaces.
#
#     ./oc_check.sh -n kube-system
#     ./oc_check.sh -n my-web-application-ns
#
#     All results are captured to a single compressed
#     TAR file with today's date at the end of each execution.
#
# ------------------------------------------------------------------

set -euo pipefail

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
CYAN='\033[0;36m'
LCYAN='\033[1;36m'
LPURP='\033[1;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Some config Variables ----------------------------------------
MY_DATE=$(date '+%Y-%m-%d-%H')
RAW_OUTPUT="results/oc_check_raw_output_${MY_DATE}.txt"
REPORT="results/oc_check_report_${MY_DATE}.txt"

function usage() {
  # Display Help
  echo -e "\n${LGREEN}OpenShift config check script."
  echo
  echo "Syntax: oc_check.sh [-h|-n|-V]"
  echo "options:"
  echo "h     Print this Help."
  echo -e "${YELLOW}n     Specify a Namespace.${LGREEN}"
  echo -e "V     Print software version and exit.\n${NC}"
}

function my_version() {
  echo -e "${LGREEN}oc_check.sh - version 0.1 - fdiaz@paloaltonetworks.com${NC}"
}

function delete_output_file() {
  if [ -f "${OUTPUT}" ]; then
    echo -e "${LCYAN}removing stale file: ${OUTPUT}${NC}\n"
    rm "${OUTPUT}"
  fi
}

function save_results() {
  echo -e "\n${LCYAN}# --- Saving Results ----------------------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
  TARFILE="results_${MY_DATE}.tar"
  
  if [ -f "${TARFILE}" ]; then
    echo -e "\n${YELLOW}Found an existing TAR file, removing: ${TARFILE}${NC}\n"
    rm ${TARFILE}
  fi
  if [ -f "${TARFILE}.xz" ]; then
    echo -e "\n${YELLOW}Found an existing COMPRESSED TAR file. Removing ${TARFILE}.xz${NC}\n"
    rm ${TARFILE}.xz
  fi
  
  tar cvf ${TARFILE} results/*.json results/*.txt
  
  ZIP=("xz" "bzip2" "gzip" "zip") # order matters in this string array
  for PROG in ${ZIP[@]}; do
    if command -v ${PROG} &>/dev/null; then
      echo -e "\n${LGREEN}Compressing tar file with ${PROG}${NC}\n"
      #if [ -f *"results/results_${MY_DATE}.tar."* ]; then rm results/results_${MY_DATE}.tar.*; fi
      ${PROG} -9 ${TARFILE}
      exit 0
    else
      echo -e "\n${RED}${PROG} not found${NC}\n"
    fi
  done
}

function get_cluster_ver() {
  OUTPUT="results/oc_cluster_ver_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift Cluster Version-----------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc describe clusterversion --output=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_nodes() {
  OUTPUT="results/oc_nodes_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift Cluster Version-----------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc get nodes --output=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_ns() {
  OUTPUT="results/oc_namespaces_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift Namespaces ---------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc get na
}

function get_ds() {
  OUTPUT="results/oc_ds_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift DS -----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc get ds --all-namespaces --output=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_ingress() {
  OUTPUT="results/oc_ingress_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift DS -----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc get ingress -n ${NAMESPACE} --output=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_service() {
  OUTPUT="results/oc_services_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift DS -----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc get service -n ${NAMESPACE} --output=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_pods() {
  OUTPUT="results/oc_pods_${NAMESPACE}_${MY_DATE}.txt"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect OpenShift DS -----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  oc get pods -n ${NAMESPACE} --output=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# --- The main() function ----------------------------------------
function main() {
  get_cluster_ver
  get_nodes
  get_ns
  get_ds
  get_ingress
  get_service
  get_pods
  # loop through and descirbe each node
  # roles
  # labels
  # annotations
  # taints
  save_results
}

while getopts "hV" option; do
  case $option in
    h)
      usage
      exit 0
    ;;
    n)
      NAMESPACE=${OPTARG}
      main
      exit 0
    ;;
    V)
      my_version
      exit 0
    ;;
    \?)
      usage
      exit 1
    ;;
  esac
done
if [ "$option" = "?" ]; then
  usage && exit 1
fi

#!/bin/bash

#set -euo pipefail
#IFS=$'\n\t'

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
# ------------------------------------------------------------------

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
	echo "Syntax: oc_check.sh [-h|-v|-V]"
	echo "options:"
	echo "h     Print this Help."
	echo -e "V     Print software version and exit.\n${NC}"
}

function my_version() {
	echo -e "${LGREEN}aws_check.sh - version 0.1 - fdiaz@paloaltonetworks.com${NC}"	
}

function delete_output_file() {
	if [ -f "${OUTPUT}" ]; then
		echo -e "${LCYAN}removing stale file: ${OUTPUT}${NC}\n"
		rm "${OUTPUT}"
	fi
}

# --- The main() function ----------------------------------------
function main() {
    oc describe clusterversion --output=json

    # get the nodes
    oc get nodes --output=json
    # loop through and descirbe each node
    # roles
    # labels
    # annotations
    # taints


    oc get namespaces --output=json

    oc get ds --all-namespaces --output=json
}

while getopts "hV" option; do
	case $option in
	h)
		usage
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

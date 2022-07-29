#!/bin/bash

#set -euo pipefail
#IFS=$'\n\t'

# ------------------------------------------------------------------
# Author: Franklin Diaz <fdiaz@paloaltonetworks.com>
#
#     Shell script to gather details about AWS configuration.
#
# Repository:
#
#     https://github.com/devsecfranklin/cloud-scripts
#
# Example:
#
#     Run the script twice on two different VPC. Results are captured
#     to a single log file with today's date.
#
#     ./ibm_check.sh -v ti-ai-network-host
#     ./ibm_check.sh -v ti-ai-outside
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
RAW_OUTPUT="results/ibm_check_raw_output_${MY_DATE}.txt"
REPORT="results/ibm_check_report_${MY_DATE}.txt"


function my_version() {
	echo -e "${LGREEN}ibm_check.sh - version 0.1 - fdiaz@paloaltonetworks.com${NC}"	
}

function delete_output_file() {
	if [ -f "${OUTPUT}" ]; then
		echo -e "${LCYAN}removing stale file: ${OUTPUT}${NC}\n"
		rm "${OUTPUT}"
	fi
}

function save_results() {
	echo -e "\n${LCYAN}# --- Saving Results ----------------------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	TARFILE="results/results_${MY_DATE}.tar"
	tar cvf ${TARFILE} results/*.json results/*.txt
	ZIP=("xz" "bzip2" "gzip" "zip") # order matters in this string array
	for PROG in ${ZIP[@]}; do
		if command -v ${PROG} &>/dev/null; then
			echo -e "\n${LGREEN}Compressing tar file with ${PROG}${NC}\n"
			if [ -f *"results_${MY_DATE}.tar."* ]; then rm results_${MY_DATE}.tar.*; fi
			${PROG} -9 ${TARFILE}
			exit 0
		else
			echo -e "\n${RED}${PROG} not found${NC}\n"
		fi
	done
}

function get_subnets() {
	OUTPUT="results/ibm_subnets_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect IBM Subnet Details ------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	ibmcloud sl subnet list --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_hardware() {
	OUTPUT="results/ibm_hardware_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect IBM Hardware Details ------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	ibmcloud sl hardware list --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# --- The main() function ----------------------------------------
function main() {
	echo -e "${LCYAN}# --- ibm_check.sh --- ${YELLOW}REGION: ${REGION} ${LCYAN}---------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	my_version | tee -a ${RAW_OUTPUT}

    ibmcloud resource groups --output json
    ibmcloud resource tags --output json
    get_subnets
    ibmcloud sl firewall list --output json
    ibmcloud sl securitygroup list --output json
    ibmcloud sl dns zone-list --output json
    ibmcloud sl globalip list --output json
    ibmcloud sl vlan list --output json
    ibmcloud sl autoscale list --output json
    ibmcloud sl block object-list --output json
    ibmcloud sl block volume-list --output json
    ibmcloud sl file volume-list --output json
    get_hardware
    save_results
}

main

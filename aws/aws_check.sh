#!/bin/bash

#set -euo pipefail
#IFS=$'\n\t'

# ------------------------------------------------------------------
# Author: Franklin D <devsecfranklin@duck.com>
#
#     Shell script to gather details about AWS configuration.
#
# Repository:
#
#     https://github.com/devsecfranklin/cloud-scripts
#
# Example:
#
#     Run the script twice on two different VPC.
#
#     ./aws_check.sh -v ti-ai-network-host
#     ./aws_check.sh -v ti-ai-outside
#
#     All results are captured to a single compressed
#     TAR file with today's date at the end of each execution.
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
RAW_OUTPUT="results/aws_check_raw_output_${MY_DATE}.txt"
REPORT="results/aws_check_report_${MY_DATE}.txt"

REGION=$(aws configure get region)

function usage() {
	# Display Help
	echo -e "\n${LGREEN}AWS config check script."
	echo
	echo "Syntax: aws_check.sh [-h|-v|-V]"
	echo "options:"
	echo "h     Print this Help."
	echo -e "${YELLOW}v     Specify a Network Name (VPC).${LGREEN}"
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

function get_tgw() {
	OUTPUT="results/aws_tgw_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS TGW Details --------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws ec2 describe-transit-gateways | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
	aws ec2 describe-transit-gateway-vpc-attachments | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_tgw_rt() {
	OUTPUT="results/aws_tgw_route_tables_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS TGW RT Details -----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws ec2 describe-transit-gateway-route-tables --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_lb() {
	OUTPUT="results/aws_load_balancers_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS LB Details ---------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws elb describe-load-balancers --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_lb_target_grps() {
	OUTPUT="results/aws_target_groups_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS TGT GRP Details ----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws elbv2 describe-target-groups --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_sg() {
	OUTPUT="results/aws_security_groups_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS SG Details ---------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws ec2 describe-security-groups | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_instances() {
	OUTPUT="results/aws_instances_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS Instance Details ---------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws ec2 describe-instances --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_interfaces() {
	OUTPUT="results/aws_interfaces_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS Interface Details ---------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws ec2 describe-network-interfaces --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_eip() {
	OUTPUT="results/aws_elasitc_ip_${VPC}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect AWS EIP Details ---------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	aws ec2 describe-addresses --output json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
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

# --- The main() function ----------------------------------------
function main() {
	#if [ ! -d "results" ]; then mkdir results; fi
	#delete_output_file
	echo -e "${LCYAN}# --- aws_check.sh --- ${YELLOW}REGION: ${REGION} ${LCYAN}---------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	my_version | tee -a ${RAW_OUTPUT}
	aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]' | tee -a ${RAW_OUTPUT}

	# Networking
	get_tgw
	get_tgw_rt
	get_lb
	get_lb_target_grps

	# instances
	get_instances
	get_interfaces
	get_eip

	# vpc
	get_sg
	#get_subnets
	#get_nat_gw
	#get_route_tables
	#get_igw
	#get_endpoints

	save_results
}

while getopts "hv:V" option; do
	case $option in
	h)
		usage
		exit 0
		;;
	v)
		VPC=${OPTARG}
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

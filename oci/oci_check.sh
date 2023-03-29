#!/bin/bash

#set -eo # pipefail
#IFS=$'\n\t'

# ------------------------------------------------------------------
# Author: Franklin D <devsecfranklin@duck.com>
#
#     Shell script to gather details about Oracle Cloud configuration.
#
# Repository:
#
#     https://github.com/devsecfranklin/cloud-scripts
#
# Example:
#
#     Run the script twice on two different VCN.
#
#     ./oci_check.sh -v ti-ai-network-host
#     ./oci_check.sh ti-ai-outside
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
RAW_OUTPUT="results/oci_check_raw_output_${MY_DATE}.txt"
COMPARTMENT="none"

function usage() {
	# Display Help
	echo -e "\n${LGREEN}Oracle config check script."
	echo
	echo "Syntax: oci_check.sh [-h|-c|-V]"
	echo "options:"
	echo "h     Print this Help."
	echo -e "${YELLOW}c     Specify a compartment OCID.${LGREEN}"
	echo -e "V     Print software version and exit.\n${NC}"
}

function my_version() {
	echo "oci_check.sh - version 0.1 - fdiaz@paloaltonetworks.com"
}

function get_all_vcn() {
	echo -e "${LCYAN}\n# --- Collect Oracle VCN Details ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_vcn_${MY_DATE}.txt"
	oci network vcn list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_drg() {
	echo -e "${LCYAN}\n# --- Collect Oracle DRG Details ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_drg_${MY_DATE}.txt"
	oci network drg list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
	cat  | grep \""id\"" | cut -f4 -d"\""
}

function get_drg_attach() {
	echo -e "${LCYAN}\n# --- Collect Oracle DRG Attach Details ---------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_drg_attach_${MY_DATE}.txt"
	oci network drg-attachment list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_subnets() {
	echo -e "${LCYAN}\n# --- Collect Oracle Subnet Details -------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_subnets_${MY_DATE}.txt"
	oci network subnet list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_load_balancers() {
	echo -e "${LCYAN}\n# --- Collect Oracle Load Balancer Details ------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_lb_${MY_DATE}.txt"
	oci nlb network-load-balancer list --all --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_instances() {
	echo -e "${LCYAN}\n# --- Collect Oracle Instance Details -----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_instances_${MY_DATE}.txt"
	oci compute instance list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_security_lists() {
	echo -e "${LCYAN}\n# --- Collect Oracle Security List Details ------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_security_lists_${MY_DATE}.txt"	
	oci network security-list list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_route_tables() {
	echo -e "${LCYAN}\n# --- Collect Oracle Route Table Details --------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_route_tables_${MY_DATE}.txt"	
	oci network route-table list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_local_peering_gw() {
	echo -e "${LCYAN}\n# --- Collect Oracle Local Peering Gateway Details -----------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_local_peering_gw_${MY_DATE}.txt"	
	oci network local-peering-gateway list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_net_sec_grp() {
	echo -e "${LCYAN}\n# --- Collect Oracle Network Security Groups -----------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	OUTPUT="results/oci_net_sec_grps_${MY_DATE}.txt"	
	oci network nsg list --compartment-id ${COMPARTMENT} | tee -a ${OUTPUT} ${RAW_OUTPUT}
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
	if [ ! -d "results" ]; then mkdir results; fi

	printf "# --- oci_check.sh -------------------------------------------------\n" | tee -a ${RAW_OUTPUT}
	my_version | tee -a ${RAW_OUTPUT}

	get_all_vcn
	get_drg
	get_drg_attach
	get_subnets
	get_load_balancers
	get_instances
	get_security_lists
	get_route_tables
	get_local_peering_gw
	get_net_sec_grp
	save_results
}

while getopts "hc:V" option; do
	case $option in
	h)
		usage
		exit 0
		;;
	c)
		COMPARTMENT=${OPTARG}
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

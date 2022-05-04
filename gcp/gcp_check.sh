#!/bin/bash

#set -euo # pipefail
#IFS=$'\n\t'

# ------------------------------------------------------------------
# Author: Franklin Diaz <fdiaz@paloaltonetowrks.com>
#
#     Shell script to gather details about GCP configuration. 
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
#     ./gcp_check.sh -v ti-ai-network-host
#     ./gcp_check.sh -v ti-ai-outside
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
GCP_PROJECT=$(gcloud config get-value project)

# --- Some globals to hold results ---------------------------------
declare -a SUBNETS # global to hold and pass results
declare -a ROUTING_MODE
declare -a FW_RULES
declare -a INSTANCE_GROUPS

function usage() {
	# Display Help
	echo -e "\n${LGREEN}GCP config check script."
	echo
	echo "Syntax: gcp_check.sh [-h|-v|-V]"
	echo "options:"
	echo "h     Print this Help."
	echo -e "${YELLOW}v     Specify a Network Name (VPC).${LGREEN}"
	echo -e "V     Print software version and exit.\n${NC}"
	echo
}

function my_version() {
	echo -e "${LGREEN}gcp_check.sh - version 0.1 - fdiaz@paloaltonetwoks.com${NC}"
}

function delete_output_file() {
	if [ -f "${RAW_OUTPUT}" ]; then
		echo -e "${LCYAN}removing stale file: ${RAW_OUTPUT}${NC}\n"
		rm "${RAW_OUTPUT}"
	fi
}

# Shared VPC allows one project to share its VPC networks with one or more projects. Shared VPC is useful
# in situations where you want one set of administrators to control the networks, traffic forwarding,
# and security into and out of an application project, and a second set of administrators to control the
# application project resources. (Similar to RG in Azure, not as easy to manage?)
function get_all_vpc() {
	OUTPUT="results/gcp_all_vpc_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Collect VPC Names --------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute networks list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# https://docs.bridgecrew.io/docs/bc_gcp_networking_7
# The default network has a pre-configured network configuration and automatically generates
# the following insecure firewall rules:

# default-allow-internal: Allows ingress connections for all protocols and ports among instances in the network.
# default-allow-ssh: Allows ingress connections on TCP port 22(SSH) from any source to any instance in the network.
# default-allow-rdp: Allows ingress connections on TCP port 3389(RDP) from any source to any instance in the network.
# default-allow-icmp: Allows ingress ICMP traffic from any source to any instance in the network.
function get_default_network() {
	OUTPUT="results/gcp_default_network_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Check Default Networks ---------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute networks describe default --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_subnets() {
	OUTPUT="results/gcp_subnets_${VPC}_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Network Details ----------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute networks describe ${VPC} --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
	# gather the subnet names
	#mapfile -t < <(cat ${OUTPUT} | grep subnetworks | cut -d'/' -f11)
	#MAPFILE=("${MAPFILE[@]:1}") # pop first item because I am lazy
	#SUBNETS="${MAPFILE[@]}"
	#mapfile -t < <(cat ${OUTPUT} | grep "routingMode:" | cut -d":" -f2)
	#ROUTING_MODE="${MAPFILE[@]}"
}

# By default, the VPC networks have two implied rules: one that denies all inbound traffic
# and one that permits all outbound traffic. You cannot remove these default rules.
# To change the default behavior for inbound traffic, you create rules that permit traffic, and
# for outbound traffic, you create rules that deny traffic.
#
# GCP applies firewall rules based on their priority. Priority is part of the rule definition, where the lower
# the value, the higher the priority.
#
# GCP sends HTTP health checks from the IP ranges 209.85.152.0/22, 209.85.204.0/22, and 35.191.0.0/16
function get_firewall_rules() {
	OUTPUT="results/gcp_firewall_rules_${VPC}_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Firewall Rules -----------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute firewall-rules list --filter="network:${VPC}" --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
	#mapfile -t < <(cat ${OUTPUT} | grep zs-vpc | grep -v selfLink: | grep -v "name:")
	#FW_RULES="${MAPFILE[@]}"
}

# By default, all instances connected to the VPC network communicate directly, even when they are part of different subnets.
# You can use custom static routes in place of the default route that defines the path out of the VPC network
# or for subnets that are not part of the VPC.
#
# GCP prefers higher priority routes, and if more than one route has the highest priority, GCP load shares traffic between the routes.
function get_routes() {
	OUTPUT="results/gcp_routes_${VPC}_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Route Details ------------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute routes list --filter="network:${VPC}" --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# This is part of the internal network load balancer configuration
function get_instance_groups {
	OUTPUT="results/gcp_instance_groups_${VPC}_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Instance Groups ----------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute instance-groups list --filter="network:${VPC}" --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
	#mapfile -t < <(cat ${OUTPUT} | grep ${VPC})
	#INSTANCE_GROUPS="${MAPFILE[@]}"
}

# This is part of the internal network load balancer configuration
function get_health_checks {
	OUTPUT="results/gcp_health_checks_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Health Checks ------------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute http-health-checks list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# This is part of the internal network load balancer configuration
function get_backend() {
	# A regional backend service that monitors the usage and health of backends.
	OUTPUT="results/gcp_backend_services_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Backend Services ---------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute backend-services list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_url_maps() {
	OUTPUT="results/gcp_url_maps_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP URL Maps -----------------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute url-maps list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# https://cloud.google.com/load-balancing/docs/internal
# Collect some more ILB details
function get_internal_lb() {
	printf "\n# --- GCP Target HTTP Proxies ------------------------------------\n" | tee -a ${RAW_OUTPUT}
	OUTPUT="results/gcp_target_proxies_list_${MY_DATE}.json"
	delete_output_file
	gcloud compute target-http-proxies list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}

	printf "\n# --- GCP Target HTTPS Proxies -----------------------------------\n" | tee -a ${RAW_OUTPUT}
	OUTPUT="results/gcp_https_proxies_${MY_DATE}.json"
	delete_output_file
	gcloud compute target-https-proxies list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}

	printf "\n# --- GCP Security Policies -----------------------------------\n" | tee -a ${RAW_OUTPUT}
	OUTPUT="results/gcp_security_policies_${MY_DATE}.json"
	delete_output_file
	gcloud compute security-policies list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function get_ssl_certs() {
	OUTPUT="results/gcp_ssl_certificates_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP SSL Certificates ---------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute ssl-certificates list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# This is part of the internal network load balancer configuration
function get_fwd_rules() {
	OUTPUT="results/gcp_forwarding_rules_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP Forwarding Rules --------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute forwarding-rules list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# VPC Network Peering allows connectivity across two VPC networks regardless of whether they belong
# to the same project or the same organization. The traffic stays within the Google Cloud Platform global
# network and doesn’t traverse the public internet.
#
# VPC network peers exchange all VPC subnet routes by default, and there is no capability to filter these
# routes. You can also exchange custom routes, such as static and dynamic routes, if you have configured
# the peering setup to import or export them. VPC network peers learn routing information dynamically
#from their peered networks.
function get_peerings() {
	OUTPUT="results/gcp_peerings_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP VPC Peerings ------------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute networks peerings list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

# A Cloud VPN gateway coupled with a Cloud Router enables static or dynamic IP routing between GCP and
# the on-premises network. For increased connection resiliency, Cloud VPN supports configurations with
# multiple tunnels to a single location for deployments with resilient on-premises VPN devices. Active/
# active configuration is also possible if you deploy multiple Cloud VPN gateways.
function get_vpn_gw() {
	OUTPUT="results/gcp_vpn_gw_${MY_DATE}.json"
	delete_output_file
	printf "\n# --- GCP VPC Peerings ------------------------------------------\n" | tee -a ${RAW_OUTPUT}
	gcloud compute vpn-gateways list --format=json | tee -a ${OUTPUT} ${RAW_OUTPUT}
}

function save_results() {
	echo -e "\n${LCYAN}# --- Saving Results ----------------------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	TARFILE="results/results_${MY_DATE}.tar"
	tar cvf ${TARFILE} results/*
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

# --- The main() function ----------------------------------------
function main() {
	if [ ! -d "results" ]; then
		mkdir results
	else
		delete_output_file
	fi
	echo -e "${LCYAN}# --- gcp_check.sh -------------------------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	my_version | tee -a ${RAW_OUTPUT}

	echo "Current GCP Project is ${GCP_PROJECT}" | tee -a ${RAW_OUTPUT}

	get_all_vpc

	# the numbers in the steps below match the picture "ilb-l7-numbered-components.png"

	# 1. we need A VPC network with at least two subnets
	get_subnets

	# 2. A firewall rule that permits proxy-only subnet traffic flows in your network.
	# This means adding one rule that allows TCP port 80, 443, and 8080 traffic from 10.129.0.0/23
	# (the range of the proxy-only subnet in this example).
	# Another firewall rule for the health check probes.
	get_firewall_rules

	# 3. Backend instances. (VM Series FW in this case)

	# 4. Instance Groups
	# Managed or unmanaged instance groups for Compute Engine VM deployments
	get_instance_groups

	# 5. A regional health check that reports the readiness of your backends.
	get_health_checks

	# 6. A regional backend service that monitors the usage and health of backends.
	get_backend

	# 7. A regional URL map that parses the URL of a request and forwards requests to specific
	# backend services based on the host and path of the request URL.
	get_url_maps

	# 8. A regional target HTTP or HTTPS proxy, which receives a request from the user and forwards
	# it to the URL map. For HTTPS, configure a regional SSL certificate resource. The target proxy
	# uses the SSL certificate to decrypt SSL traffic if you configure HTTPS load balancing. The
	# target proxy can forward traffic to your instances by using HTTP or HTTPS.
	#
	# GCP sends HTTP health checks from the IP ranges 209.85.152.0/22, 209.85.204.0/22, and 35.191.0.0/16
	get_internal_lb

	get_ssl_certs

	# 9. A forwarding rule, which has the internal IP address of your load balancer, to forward each
	# incoming request to the target proxy.
	#
	# The internal IP address associated with the forwarding rule can come from any subnet (in the
	# same network and region) with its --purpose flag set to PRIVATE. Note that:
	#
	# The IP address can (but does not need to) come from the same subnet as the backend
	# instance groups.
	# The IP address must not come from a reserved proxy-only subnet that has its --purpose
	# flag set to REGIONAL_MANAGED_PROXY.
	#
	# For the forwarding rule's IP address, use the backend-subnet. If you try to use the proxy-only subnet, forwarding rule creation fails.
	get_fwd_rules

	# Networking
	get_routes
	get_default_network
	get_peerings

	# Compute Instances

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
		RAW_OUTPUT="results/gcp_check_raw_output_${VPC}_${MY_DATE}.txt"
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

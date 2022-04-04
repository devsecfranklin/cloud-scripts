#!/bin/bash

set -eo # pipefail
IFS=$'\n\t'

# ------------------------------------------------------------------
# Author: Franklin Diaz <fdiaz@paloaltonetowrks.com>
#
#     Shell script to gather details about Azure configuration.
#
# Repository:
#
#     https://github.com/devsecfranklin/cloud-scripts
#
# Example:
#
#     brew install bash
#     /usr/local/bin/bash az_check.sh -g bmika-transit-rg
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
SUBSCRIPTION=""
LOCATION=""

declare -a VNETS
declare -A SUBNETS # (key: subnet_name value: VNet)
declare -a ROUTE_TABLES
declare -A ROUTES # (key: Route value: Route Table)
declare -a SECURITY_GROUPS

function usage() {
	# Display Help
	echo -e "\n${YELLOW}Azure config check script."
	echo
	echo "Syntax: az_check.sh [-h|-v|-V]"
	echo "options:"
	echo "-h     Print this Help."
	echo -e "${YELLOW}v     Specify a Network Name (VNet).${LGREEN}"
	echo -e "-V     Print software version and exit.\n${NC}"
}

function my_version() {
	echo -e "${LGREEN}az_check.sh - version 0.1 - fdiaz@paloaltonetwoks.com${NC}"
}

function delete_output_file() {
	if [ -f "${OUTPUT}" ]; then
		echo -e "${LCYAN}removing stale file: ${OUTPUT}${NC}\n"
		rm "${OUTPUT}"
	fi
}

# Resource groups are logical containers that define who can manage and control resources.
# All resources (virtual machines, virtual networks, load balancers, etc.) belong to a resource group.
# Resource groups provide easy implementation of RBAC.
# A common technique is to group resources based on function (infrastructure, application).
# Separating application resources from the infrastructure resources that allow them to communicate
# with each other is possible because resource groups do not control communication between resources.

function get_rg() {
	OUTPUT="results/resource_group_${RESOURCE_GROUP}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Network Details --------------------------\n${NC}" | tee "${RAW_OUTPUT}"
	az group show -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# A virtual network (VNet) is a logically segmented network within Azure that allows connected resources
# to communicate with each other. You define a VNet by one or more public or private IP address ranges
# that you can then divide into subnets (/29 or larger). VNet IP address space, both public and private, is
# reachable only within the VNet or through services connected to the VNet, such as a VPN. Because VNets
# are isolated from each other, you can overlap IP network definition across VNets. When you want direct
# communication of resources in separate VNets, the VNets can be connected whether they are in the same
# Azure location or not, as long as there is no overlap in the IP network definition.

function get_vnets() {
	OUTPUT="results/vnets_${RESOURCE_GROUP}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Vnet Details -----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network vnet list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"

	# now use the same output file to determine Vnet peerings.
	# You achieve full, seamless IP reachability across VNets after you establish the peer connection.
	# All network traffic using VNet peering remains within the Azure backbone.
	#
	# 1. VNet peering — You have deployed the connected VNets within the same Azure region (example: West US).
	# 2. Global VNet peering — You have deployed the connected VNets across multiple Azure regions
	# (example: West US and East US). Some Azure networking capabilities are restricted when using Global VNet peering.

}

# 1. For the management subnet, the route table should discard all traffic destined to the private and
#    public network ranges by routing the traffic to the next hop of none.
# 2. For public subnets, the route table should direct all traffic destined to private network range to
#    the firewalls public internal IP address. Discard traffic destined to the management network range
#    by using the next hop of none.
# 3. The subnet attached to the firewalls private interface should have a user-defined route table that
#    directs traffic destined to the Internet and public networks to the firewalls private IP address.
#    Discard traffic destined to the management network range by using the next hop of none.
# 4. For private subnets, the route table should direct all traffic (destined to the Internet, to the
#    private network range, and the public network range) to the firewalls private internal IP address.
#    Discard traffic destined to the management network range by using the next hop of none.

function get_subnets() {
	OUTPUT="results/subnets_${RESOURCE_GROUP}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Subnet Details ---------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network vnet subnet list -g ${RESOURCE_GROUP} --vnet-name ${1} -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"

	# determine which is the mgmt subnet somehow. Prompt use to select perhaps?

	# determine public subnets

	# determine private subnets
}

# User-defined routes (UDRs) modify the default traffic-forwarding behavior of Azure networking.
# The destination for a route can be a different subnet in the VNet, a different subnet in another
# VNet (with an existing peer connection), anywhere on the internet, or a private network connected to the
# VNet. The next hop for the route can be any resource in the VNet or in a peered VNet in the same region.
# You primarily use a UDR to direct traffic to a resource, such as a load balancer or a firewall, within the
# VNet or in a peered VNet. It can also discard (or blackhole) traffic or send it across a VPN connection. UDR
# can affect traffic within a subnet, including host-to-host traffic within a subnet if the applied UDR is
# active for the subnet prefix.

# The use of UDR summary routes can have unexpected consequences. If you
# apply a UDR summary route to a subnet that falls within the summary but does
# not have a more specific UDR

function get_route_tables() {
	OUTPUT="results/route_table_${RESOURCE_GROUP}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Route Tables -----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network route-table list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# Network security groups (NSGs) filter traffic into and out of subnets and virtual machine network
# interfaces. An NSG can be associated to the network interface of a virtual machine or to a subnet. The limit
# is one association for each interface and one association for each subnet. For ease of configuration when
# you apply the same policies to more than one resource, you can associate network security groups with
# multiple subnets and virtual machine network interfaces. An NSG associated to t

# A prioritized list of rules defines the policies of a network security group. There are separate policies
# for inbound and outbound. Rules are defined and matched by the traffic source, destination, port, and
# protocol. In addition to IP addressing, you can set the source and destination of a rule by using Azure tags
# or application security groups.

# Network security groups are pre-configured with default security rules that:
# • Allow all traffic within the VNet.
# • Allow outbound traffic to the internet.
# • Allow inbound traffic that is originating from Azure’s load-balancer probe (168.63.129.16/32).
# • Deny all other traffic.

function get_nsg() {
	OUTPUT="results/network_security_groups_${RESOURCE_GROUP}_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Network Security Groups -----------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network nsg list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# The Azure virtual network gateway (VNG) provides connectivity between an Azure virtual network and your
# on-premises networks and data centers. Site-to-site connectivity through a VNG can either be through
# IPSec VPN (also known as a VPN gateway) or a dedicated private connection (also known as an ExpressRoute
# gateway). When you deploy a virtual network gateway as a VPN gateway, it supports the configuration of
# IPSec VPN tunnels to one or more of your locations across the internet. When deployed as an ExpressRoute
# gateway, the VNG provides connectivity to on-premises locations through a dedicated private circuit
# facilitated by a connection provider.

function get_vpn_gw() {
	OUTPUT="results/vpn_gw_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure VPN Gateways ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network vpn-gateway list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# Express Routes

function get_app_gw() {
	OUTPUT="results/app_gw_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Application Gateways --------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network application-gateway list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_network_int() {
	OUTPUT="results/network_interfaces_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Network Interfaces ----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network nic list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_local_network_gw() {
	OUTPUT="results/local_network_gateways_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Local Network Gateways -------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network local-gateway list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"

}

function get_public_ips() {
	OUTPUT="results/public_ip_addresses_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Public IP Addresses -----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network public-ip list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# Load balancing distributes traffic to a set of resources based on the traffic’s DNS, Layer 7, or Layer 4
# information. Azure offers the following types of load balancers:

# • Azure Traffic Manager
# Azure Traffic Manager uses DNS to distribute traffic across multiple data centers. Traffic Manager
# integrates into DNS requests through DNS CNAME records that alias the application to Traffic Manager.

# • Azure Application Gateway
# Azure Application Gateway uses HTTP/HTTPS information to distribute traffic across resources within a
# data center. Application gateways have a single public IP address but can host up to 20 websites, each with
# a back-end pool. Primarily, Application Gateway relies on HTTP host headers to differentiate between
# websites. When you enable SSL offload on Application Gateway, it can also use server name indication to
# distinguish between websites. When SSL offload is enabled, you can choose to pass cleartext traffic to the
# back-end pool or re-encrypt the traffic before passing it to the back-end pool.
# Both the inbound and the return traffic must flow through Application Gateway.
# Because Application Gateway uses system routes to direct traffic, you must deploy it in a dedicated subnet.
# If it shares a subnet with other resources, traffic from virtual machines in the subnet will not route to
# Application Gateway.

# • Azure Load Balancer
# Azure Load Balancer distributes flows that arrive on the load balancer’s front end to back-end pool
# instances and allows you to scale your applications and provide high availability for services.

function get_lbs() {
	OUTPUT="results/network_load_balancers_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Load Balancers ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az network lb list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_vms() {
	OUTPUT="results/virtual_machines_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Virtual Machines --------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az vm list -g "${RESOURCE_GROUP}" -d -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_log_an_ws() {
	OUTPUT="results/log_analytics_workspaces_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Azure Log Analytics Workspaces ------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
}

function get_policies() {
	OUTPUT="results/network_policies_${MY_DATE}.json"
	delete_output_file
	echo -e "${LCYAN}\n# --- Collect Network Policies --------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	az policy state summarize -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
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
	echo -e "${LCYAN}# --- az_check.sh -------------------------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
	my_version | tee -a ${RAW_OUTPUT}
	get_rg    # get the resource group
	get_vnets # get the vnets from the RG
	#get_subnets included in the get vnet output, might be easier to parse JSON if separate
	get_route_tables
	get_nsg
	get_app_gw
	get_local_network_gw
	get_public_ips
	get_lbs
	get_vms
	get_network_int
	get_log_an_ws # log analytics workspaces

	save_results
}

if [ $# -lt 1 ]; then
	usage
	exit 1
fi

while getopts "hr:V" option; do
	case $option in
	h)
		usage
		exit 0
		;;
	r)
		RESOURCE_GROUP=${OPTARG}
		RAW_OUTPUT="results/az_check_raw_output_${RESOURCE_GROUP}_${MY_DATE}.txt"
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

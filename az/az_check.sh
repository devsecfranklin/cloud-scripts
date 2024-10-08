#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 DE:AD:10:C5 <franklin@dead10c5.org>
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -eo pipefail
IFS=$'\n\t'

# ------------------------------------------------------------------
#
#     Shell script to gather details about Azure configuration.
#
# Repository:
#
#     https://github.com/devsecfranklin/cloud-scripts
#
# Example:
#
#     Run the script twice on two different Resource Groups.
#
#     az_check.sh -g bmika-transit-rg
#     az_check.sh -g lab-franklin-rg
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
SUBSCRIPTION=""
LOCATION=""

declare -a VNETS
declare -A SUBNETS # (key: subnet_name value: VNet)
declare -a ROUTE_TABLES
declare -A ROUTES # (key: Route value: Route Table)
declare -a SECURITY_GROUPS

function usage() {
  # Display Help
  echo -e "\n${LGREEN}Azure config check script."
  echo
  echo "Syntax: az_check.sh [-h|-r|-V]"
  echo "options:"
  echo "-h     Print this Help."
  echo -e "${YELLOW}-r     Specify a Resource Group (RG).${LGREEN}"
  echo -e "-V     Print software version and exit.\n${NC}"
}

function my_version() {
  echo -e "${LGREEN}az_check.sh - version 0.2 - franklin@dead10c5.org${NC}"
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

# Resource groups are logical containers that define who can manage and control resources.
# All resources (virtual machines, virtual networks, load balancers, etc.) belong to a resource group.
# Resource groups provide easy implementation of Role Based Access Control (RBAC).
#
# A common technique is to group resources based on function (infrastructure, application).
# Separating application resources from the infrastructure resources that allow them to communicate
# with each other is possible because resource groups do not control communication between resources.

function get_rg() {
  OUTPUT="results/az_resource_group_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Resource Group ---------------------------\n${NC}" | tee "${RAW_OUTPUT}"
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
  OUTPUT="results/az_vnets_${RESOURCE_GROUP}_${MY_DATE}.json"
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
  OUTPUT="results/az_subnets_${RESOURCE_GROUP}_${MY_DATE}.json"
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
  OUTPUT="results/az_route_table_${RESOURCE_GROUP}_${MY_DATE}.json"
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
  OUTPUT="results/az_network_security_groups_${RESOURCE_GROUP}_${MY_DATE}.json"
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
  OUTPUT="results/az_vpn_gw_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure VPN Gateways ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network vpn-gateway list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# Express Routes

function get_app_gw() {
  OUTPUT="results/az_app_gw_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Application Gateways --------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network application-gateway list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# if there are firewalls, you can collect the NAT rules from them.
function get_fw_nat_rules() {
  az extension add --upgrade -n azure-firewall | tee -a "${OUTPUT}" "${RAW_OUTPUT}" # install the needed extensions

  OUTPUT="results/az_nat_rules_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure NAT Rules -------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network firewall list -g NYMTA-RG

  OUTPUT="results/az_nat_rules_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure NAT Rules -------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network firewall nat-rule list -g NYMTA-RG -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_network_int() {
  # gather the network interfaces
  OUTPUT="results/az_network_interfaces_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Network Interfaces ----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network nic list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"

  # Create a list of the network Interfaces and cycle through to get effective Network Security Groups
  MY_INTERFACES=$(cat ${OUTPUT} | grep name | grep -v null | grep -v primary | cut -f 4 -d'"')

  # This is very helpful in troubleshooting, will fail if instance is not powered on
  OUTPUT="results/az_network_interface_effective_nsg_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Network Interface Effective NSG ----------\n${NC}" | tee -a "${RAW_OUTPUT}"
  for INT in ${MY_INTERFACES}; do
    az network nic list-effective-nsg -g "${RESOURCE_GROUP}" -n ${INT} -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
  done

  OUTPUT="results/az_network_interface_effective_rt_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Network Interface Effective Routes -------\n${NC}" | tee -a "${RAW_OUTPUT}"
  for INT in ${MY_INTERFACES}; do
    az network nic show-effective-route-table -g "${RESOURCE_GROUP}" -n ${INT} -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
  done
}

function get_local_network_gw() {
  OUTPUT="results/az_local_network_gateways_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Local Network Gateways -------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network local-gateway list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_public_ips() {
  OUTPUT="results/az_public_ip_addresses_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Public IP Addresses -----------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network public-ip list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_lbs() {
  OUTPUT="results/az_network_load_balancers_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Load Balancers ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network lb list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_vms() {
  OUTPUT="results/az_virtual_machines_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Virtual Machines --------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az vm list -g "${RESOURCE_GROUP}" -d -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_log_an_ws() {
  OUTPUT="results/az_log_analytics_workspaces_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Azure Log Analytics Workspaces ------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az monitor log-analytics workspace list -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function get_policies() {
  OUTPUT="results/az_network_policies_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Collect Network Policies --------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az policy state summarize -g "${RESOURCE_GROUP}" -o json | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function show_topology() {
  OUTPUT="results/az_show_topology_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Show Topology ------------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az network watcher show-topology -g "${RESOURCE_GROUP}" | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# Create an array to hold the list of workspace names for use in other functions
function show_synapse_workspaces() {
  OUTPUT="results/az_show_synapse_workspaces_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Show Synapse WS ----------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az synapse workspace list -g "${RESOURCE_GROUP}" | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

# https://learn.microsoft.com/en-us/cli/azure/synapse/data-flow?view=azure-cli-latest#az-synapse-data-flow-list()
function show_synapse_flows() {
  OUTPUT="results/az_show_synapse_flows_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Show Synapse Flows -------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az synapse data-flow list --workspace-name xxx | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function show_synapse_fw() {
  OUTPUT="results/az_show_synapse_firewall_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Show Synapse FW ----------------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az synapse workspace firewall-rule list -g "${RESOURCE_GROUP}" --workspace-name xxx | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
}

function show_synapse_sql_pool() {
  OUTPUT="results/az_show_synapse_sql_pool_${RESOURCE_GROUP}_${MY_DATE}.json"
  delete_output_file
  echo -e "${LCYAN}\n# --- Show Synapse SQL Pool ----------------------------\n${NC}" | tee -a "${RAW_OUTPUT}"
  az synapse sql pool list -g "${RESOURCE_GROUP}" --workspace-name xxx | tee -a "${OUTPUT}" "${RAW_OUTPUT}"
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
  get_fw_nat_rules
  get_local_network_gw
  get_public_ips
  get_lbs
  get_vms
  get_network_int
  # next one is complaining "(--resource-group --name | --ids) are required"
  #get_log_an_ws # log analytics workspaces
  show_topology

  # Synapse
  show_synapse_workspaces
  show_synapse_flows
  show_synapse_fw
  show_synapse_sql_pool

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

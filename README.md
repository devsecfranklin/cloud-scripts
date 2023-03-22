# cloud-scripts

[![Bandit Python Security Check](https://github.com/devsecfranklin/cloud-tools/actions/workflows/bandit.yml/badge.svg)](https://github.com/devsecfranklin/cloud-tools/actions/workflows/bandit.yml)

These scripts are for data gathering on public cloud infrastructure and configuration.

The easiest way to use this is to clone it into a cloud shell and run from there.

```sh
git clone https://github.com/devsecfranklin/cloud-tools.git
cd cloud-tools
```

## Azure

Download the script to your cloud shell in Azure.

```sh
wget -O az_check.sh https://raw.githubusercontent.com/devsecfranklin/cloud-scripts/main/az/az_check.sh
chmod 755 az_check.sh
```

Execute the script once for each Resource Group, such as `./az_check.sh -r <RG-Name>`.

```sh
./az_check.sh -r bmika-app3
```

Upload the compressed TAR file as directed.

## Google Cloud

Download the script to your cloud shell in GCP.

```sh
wget -O gcp_check.sh https://raw.githubusercontent.com/devsecfranklin/cloud-scripts/main/gcp/gcp_check.sh
chmod 755 gcp_check.sh
```

Execute the script once for each VPC (such as mgmt, trust, and untrust).

```sh
./gcp_check.sh -v ps-devsecops-mgmt
./gcp_check.sh -v ps-devsecops-trust
./gcp_check.sh -v ps-devsecops-untrust
```

Same as previous example, but in a single line:

```sh
for vpc in ps-devsecops-mgmt ps-devsecops-trust ps-devsecops-untrust; do \
    ./gcp_check.sh -v ${vpc}; done
```

Upload the compressed TAR file as directed.

## AWS

Download the script to your cloud shell in AWS.

```sh
wget -O aws_check.sh https://raw.githubusercontent.com/devsecfranklin/cloud-scripts/main/aws/aws_check.sh
chmod 755 aws_check.sh
```

Execute the script once for each VPC.

```sh
./aws_check.sh -v ps-devsecops-mgmt
./aws_check.sh -v ps-devsecops-trust
./aws_check.sh -v ps-devsecops-untrust
```

Same as previous example, but in a single line:

```sh
for vpc in ps-devsecops-mgmt ps-devsecops-trust ps-devsecops-untrust; do \
    ./aws_check.sh -v ${vpc}; done
```

## OCI

Download the script to your cloud shell in AWS.

```sh
wget -O oci_check.sh https://raw.githubusercontent.com/devsecfranklin/cloud-scripts/main/oci/oci_check.sh
chmod 755 oci_check.sh
```

Execute the script once for each Compartment.

Example:

```sh
./oci_check.sh -c ocid1.compartment.oc1..aaaaaaaa123412341234asdfasdf
```

## Results

A small set of test and JSON output is generated from the execution of the
scripts. Upload the compressed TAR file as directed.

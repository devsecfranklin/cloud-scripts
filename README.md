# cloud-scripts

These scripts are for data gathering on public cloud infrastructure and configuration.

The easiest way to use this is to clone it into a cloud shell and run from there.

```sh
git clone https://github.com/devsecfranklin/cloud-tools.git
cd cloud-tools
```

## Azure

Execute the script once for each Resource Group, such as `./az_check.sh -r <RG-Name>`.

Example:

```sh
cd az
./az_check.sh -r bmika-app3
```

Upload the compressed TAR file as directed.

## Google Cloud

Execute the script once for each VPC (such as mgmt, trust, and untrust).

Example: 

```sh
cd gcp
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

Execute the script once for each VPC.

Example:

```sh
cd aws
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

Execute the script once for each Compartment.

Example:

```sh
./oci_check.sh -c ocid1.compartment.oc1..aaaaaaaa123412341234asdfasdf
```

## Results

A small set of test and JSON output is generated from the execution of the
scripts. Upload the compressed TAR file as directed.

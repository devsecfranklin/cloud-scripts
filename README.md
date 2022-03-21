# cloud-scripts

The easiest way to use this is to clone it into a cloud shell and run from there.

```sh
git clone https://github.com/devsecfranklin/cloud-tools.git
cd cloud-tools
```

OPTIONAL: Make the virtual environment to install CLI tool for Azure and Oracle.

```sh
make python # create the virtual environment
. _build/bin/activate # activate the virtual environment
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

Upload the compressed TAR file as directed.

## AWS

Execute the script once for each VPC (such as mgmt, trust, and untrust).

Example: 

```sh
cd aws
./aws_check.sh -v ps-devsecops-mgmt
./aws_check.sh -v ps-devsecops-trust
./aws_check.sh -v ps-devsecops-untrust
```

Upload the compressed TAR file as directed.

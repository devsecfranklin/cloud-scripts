# Azure

Execute the script once for each VNet.

Example: 

```sh
./az_check.sh -v ps-devsecops-mgmt
./az_check.sh -v ps-devsecops-trust
./az_check.sh -v ps-devsecops-untrust
```

Upload the compressed TAR file as directed.

## run on Mac/Intel

```sh
brew upgrade && brew install bash # need latest bash for "mapfile"
/usr/local/bin/bash az_check.sh -g bmika-transit-rg
```

## container

Build container:
`docker build --progress=plain -t franklin:az-check .`

Shell in container: 
`docker run -it --entrypoint "" franklin:az-check /bin/ash`

## Diagrams

https://github.com/PrateekKumarSingh/AzViz

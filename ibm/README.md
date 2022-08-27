# IBM Cloud

## IBM Cloud CLI Setup

- install the [IBM CLoud CLI tools from this link](https://github.com/IBM-Cloud/
ibm-cloud-cli-release/releases/)

```sh
set -U fish_user_paths $fish_user_paths /usr/local/ibmcloud/bin
ibmcloud update
ibmcloud plugin list
ibmcloud login -a https://cloud.ibm.com -u passcode -p xxx
ibmcloud plugin install vpc-infrastructure
```

## SSL VPN Setup

- [SSL VPN MotionPro clients](https://support.arraynetworks.net/prx/001/http/sup
portportal.arraynetworks.net/downloads/downloads.html)

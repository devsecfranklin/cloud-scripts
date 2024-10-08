# deploy_fw_gcp

Deploy a Palo FW to Google Cloud

1. Prepare the AUTH key from the Panorama.
2. Edit the YAML file. You can also create a new YAML file if you update the variable in the tool.
3. Run the tool. You will see output as below.

* NOTE: You cannot use the new type SSH keys, `id_ed25519.pub` for example does not work with Palo FW yet. Be sure the public SSH key is correct or you will have to tear it down and start over.
* NOTE: You must be sure the names of the STACK and DEVICE GROUP are correct, and exist on the target Panorama.

```sh
Generate auth key from Panorama CLI like so: request bootstrap vm-auth-key generate lifetime 8760
Enter your auth key:
asdf
Deploying firewall: fw8
Created [https://www.googleapis.com/compute/v1/projects/project/zones/us-central1-a/instances/lab-franklin-gcp-eight].
NAME                    ZONE           MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP                             EXTERNAL_IP                  STATUS
lab-franklin-gcp-eight  us-central1-a  n2-standard-4               10.2.20.29,92.18.0.6,10.2.2.1  35.202.2.227,34.2.21.1  RUNNING
(_test) sa_116805149644468504027@lab-franklin-airlock1:~/workspace/lab-franklin/test$
```

## Original YAML file

* This is saved here for historical purposes.
* Be sure to remove the comments before you use this.

```yaml
fw1:
  FW_NAME: "lab-franklin-gcp-two"
  UNTRUST_SUBNET: "lab-franklin-untrust"
  MGMT_SUBNET: "ps-devsecops-mgmt"
  TRUST_SUBNET: "lab-franklin-trust"
  FW_ZONE: "us-central1-a"
  DISK:
    SIZE: 60GB
    TYPE: "pd-ssd"
  INSTANCE:
    PROJECT: "paloaltonetworksgcp-public" # do not change this value
    TYPE: "n2-standard-4"
  IMAGE: "vmseries-flex-byol-1023"        # search for images in the preceding project
  TAGS: "lab-franklin,allow-icmp,http-server,https-server" # edit these, comma separate?
  PANORAMA1: "192.168.0.3"
  PANORAMA2: "192.168.0.4"
  TEMPLATE: "STK-Google" # this is the STACK
  DEVICEGROUP: "DG-google-lab"
  DNS: "8.8.4.4"
  AUTHKEY: "2:9KD16LjLR_OSGlJKUAU0Mq3uSVu1k0K1pfLkNCZ9zLCkPl-Oe7m64WzQtXLswbcGVMyorgc_5CO3mO5w8FKx8g" # from panorama CLI: `request bootstrap vm-auth-key generate lifetime 8760`
  KEY: "admin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCu+5vKjTtTWZwlDlm7AlmQdWKujHq7cWnoeJZa/sUGNj+rg8d+SfJZCF+cSuOEFxqJ6wVbX5WSAvB0MNETtncVsC6NvKNSGFsc8vIrIas5cQtyk8frp6SA9aJ/M90p2ekYwPVhqshGCLiRZ1enbm+8uvpGZkWW/g7eQV8HbxFnFCsdf9JZzHcnXWOD8tkRO9r/uuIX31BmVxEG2YE8IPC3Xq18hGglLsi0vOGdBicfOGGc/DRsw6wxXSjXF66nJAxmKZgg4lWzNIe8MkEJthI9cWPsTWcJC3XPpRuKQY6crofZa+atwkymhYJ/MUIJW4172cWLpbA1+4dvSFKSUpyo/Qs+0Zpft8vVvceaDhOsNCpzKk/qINZ3Z+Q/B4I9Ribw83K3FwfAlr6t35Z4j7cCw3VrlJtyVHrwUnVwkCNuw2zcWISfXSnCCFyVgxiJltnqk6CBOUfk6P3qIXqvQqQqp3cB1SiimVtSN5bzITiNnAdySnOUYJIsmMxkPH0Qua8cOQNNs2Ns9zAjgilTZtzG0siJtWmHJrg8+3jMG5mwzOvIgT3DadAx5ao1/+8ak4gBfoqSrLSJXPwW8Myl/I3/uxVkbxb4+jjJwnxKsbGS5LnfVGSvqEFXgtGYfNz79emdIWf3Tbh6Lv9+3Rrt9maCPg3/i5QtWBpaflI2RxurbQ== fdiaz@paloaltonetworks.com"
  ```

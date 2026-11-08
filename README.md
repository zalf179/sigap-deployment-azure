# SIGAP Azure Deployment

Terraform configuration for provisioning an Ubuntu VM on Azure and preparing it to host the SIGAP application.

## What it creates

- An Azure resource group, virtual network, subnet, and network security group.
- A static public IP and one Ubuntu 24.04 LTS virtual machine.
- An attached managed data disk mounted at `/data`; Docker is configured to store its data there.
- A cloud-init setup that installs Docker and Git and clones the application repository to `/opt/sigap`.

The cloud-init setup does **not** start the application. The application’s `.env` must be configured on the VM before following its own instructions to run it.

## Prerequisites

- Terraform 1.5 or newer.
- An Azure subscription and Azure CLI login (`az login`).
- An SSH key pair; the public key must be available at the configured path.
- Your current public IP in CIDR notation, for example `203.0.113.5/32`.

## Configure

Create a local `terraform.tfvars` file (do not commit subscription details or other environment-specific values):

```hcl
subscription_id    = "<azure-subscription-id>"
my_ip              = "<your-public-ip>/32"
location           = "eastasia"
prefix             = "sigap"
vm_size            = "Standard_B2s"
admin_username      = "azureuser"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
repo_url            = "https://github.com/zalf179/sigap.git"
data_disk_size_gb   = 32
```

`subscription_id` and `my_ip` are required. Other values have defaults in `variables.tf`. Adjust the VM size and region to match your workload and Azure quota. The configured network rules allow SSH and port 8080 only from `my_ip`; ports 80 and 443 are open to all IPv4 addresses.

## Provision

From this directory, initialize Terraform and review the proposed changes before applying:

```sh
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform prints the VM’s `public_ip`, an `ssh_command`, and an `app_url` (port 8080). Cloud-init can take several minutes after VM creation to finish installing Docker and cloning the repository.

## Start the application

Once setup has completed, connect to the VM:

```sh
terraform output -raw ssh_command
```

On the VM, configure the application environment according to the application repository’s instructions, then start its services from `/opt/sigap`. For example, if the repository provides a Docker Compose configuration, use its documented `docker compose` command. The Terraform cloud-init script intentionally leaves the app stopped until its environment is configured.

The application URL output is `http://<public-ip>:8080`. Ensure the app is configured to listen on that port before expecting it to respond.

## Tear down

To remove the resources managed by this configuration:

```sh
terraform destroy
```

This also deletes the VM and its managed data disk. Back up any data you need before destroying the deployment.

## Terraform state

Terraform state can contain infrastructure details and should be treated as sensitive. Keep `terraform.tfstate`, `terraform.tfstate.backup`, and local variable files out of version control; use an appropriately secured remote backend for shared or production deployments.

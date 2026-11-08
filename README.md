# SIGAP Azure Deployment

Terraform configuration that provisions an Ubuntu VM on Azure and prepares it to run [SIGAP](https://github.com/zalf179/sigap), a web app made of a React frontend, an Express API, a FastAPI + TensorFlow classifier, and a MySQL database, all orchestrated with Docker Compose.

Write-up of the full process, including the problems I hit: [Deploying My Web App in Azure VM](https://medium.com/@zalfd/deploying-my-web-app-in-azure-vm-957ffdfbcdaa)

## Architecture

```
Internet
   |
[ NSG ]   22 and 8080 from my IP only; 80/443 open (reserved for a future reverse proxy)
   |
[ Static public IP ] -- [ Ubuntu 24.04 VM ]
                          |-- frontend (nginx)   :8080
                          |-- backend (Express)  :5000
                          |-- ai (FastAPI)       internal
                          |-- mysql              internal
                          '-- /data  <- managed data disk (Docker data-root)
```

## What it creates

- Resource group, virtual network, subnet, and network security group
- Static public IP and one Ubuntu 24.04 LTS virtual machine (SSH key authentication only)
- A managed data disk mounted at `/data`, with Docker configured to store its data there
- A cloud-init setup that installs Docker and Git and clones the application to `/opt/sigap`

Cloud-init does **not** start the application. The app needs a `.env` file with real secrets, which should not live in a repository or a provisioning script.

## Prerequisites

- Terraform 1.5 or newer
- An Azure subscription and the Azure CLI (`az login`)
- An SSH key pair (the public key path is configurable)
- Your public IP in CIDR notation, for example `203.0.113.5/32`

## Configure

Copy the example file and fill in your values. `terraform.tfvars` is git-ignored; never commit it.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars.example`:

```hcl
subscription_id     = "YOUR-SUBSCRIPTION-ID"
my_ip               = "203.0.113.5/32"
location            = "eastasia"
prefix              = "sigap"
vm_size             = "Standard_D2as_v4"   # 2 vCPU, 8 GiB RAM
admin_username      = "azureuser"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
repo_url            = "https://github.com/zalf179/sigap.git"
data_disk_size_gb   = 32
```

Only `subscription_id` and `my_ip` are required; everything else has a default in `variables.tf`.

## Provision

```powershell
az login
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform prints `public_ip`, `ssh_command`, and `app_url`. Cloud-init needs a few minutes after the VM is created to install Docker and clone the repository. To follow its progress on the VM:

```bash
tail -f /var/log/cloud-init-output.log
```

## Start the application

Connect to the VM:

```powershell
terraform output -raw ssh_command
```

Then, on the VM:

```bash
cd /opt/sigap
cp .env.docker.example .env
nano .env                        # replace every example secret
docker compose up -d --build
docker compose ps
```

Building the images, including TensorFlow, took roughly 200 seconds on a 2 vCPU / 8 GiB VM.

**Before exposing the app to anyone else:** the application seeds default admin and staff accounts (see the application repository's README). Change or remove those credentials first.

## Verify

- `docker compose ps` should show `mysql`, `ai`, and `backend` as healthy. The `db-init` container is expected to exit after seeding the database; it only runs once.
- On the VM: `curl http://localhost:5000/api/health`
- From your own machine (the allowed IP): open the `app_url` output, which is `http://<public-ip>:8080`.

## Troubleshooting

**`SkuNotAvailable` when creating the VM**

```
SkuNotAvailable: ... Standard_B2s is currently not available in location 'eastasia'
```

This is a *capacity* restriction, not a quota problem: the VM size is not being offered in that region at that time, even if your quota allows it. You can confirm by checking the quota with `az vm list-usage --location <region> -o table`. Then see which sizes are restricted for your subscription with:

```powershell
az vm list-skus --location <region> --size Standard_D2 --all -o table
```

Pick a size whose `Restrictions` column is empty and override it in `terraform.tfvars`. Running `terraform apply` again continues from where it failed. If no size works, change `location`; destroy first, because a region cannot be changed in place.

**SSH or the app stops responding after a while**

Your ISP may have changed your public IP. Update `my_ip` in `terraform.tfvars` and run `terraform apply` again.

## Security notes

- SSH and port 8080 are limited to `my_ip` by the NSG. Ports 80 and 443 are open to all IPv4 addresses but nothing listens on them yet; they are reserved for a reverse proxy with HTTPS.
- The app is served over plain HTTP on a raw IP. A real deployment needs a domain and HTTPS.
- Docker Compose publishes the API port (5000) on all interfaces; the NSG is what keeps it unreachable from the internet. Keep that rule in place.
- Secrets live in `.env` on the VM only. A managed setup should use Azure Key Vault.
- Terraform state can contain sensitive values. Keep `terraform.tfstate*`, `terraform.tfvars`, and `.terraform/` out of version control, and use a secured remote backend for shared or production use. `.terraform.lock.hcl` is meant to be committed.

## Cost and tear down

The VM, data disk, and static public IP bill for as long as they exist. This project is meant for learning: apply, test, then destroy. Check Azure Cost Management and set a budget alert on your subscription.

```powershell
terraform destroy
```

This deletes the VM **and** its data disk. Back up anything you need first (for example with `mysqldump`). Afterwards, confirm in the portal or with `az group list -o table` that the resource group is gone.

## Roadmap

- Monitoring and alerts (Azure Monitor, Uptime Kuma on `/api/health`)
- CI/CD with GitHub Actions: build, push, and deploy on every push to `main`
- Database backups to Blob Storage with a tested restore
- Domain and HTTPS
- Failure drills with written postmortems
- Phase 2: Azure Container Apps, managed MySQL, a container registry, and Key Vault

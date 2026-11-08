variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "eastasia"
}

variable "prefix" {
  type    = string
  default = "sigap"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s" # 4 GB RAM, TensorFlow butuh ruang
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "my_ip" {
  type        = string
  description = "IP publik lu dalam format CIDR, contoh 203.0.113.5/32"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/zalf179/sigap.git"
}

variable "data_disk_size_gb" {
  type    = number
  default = 32
}
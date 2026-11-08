output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "app_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}:8080"
}
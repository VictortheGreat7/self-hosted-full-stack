# This file contains defines some output requests to the Time API Azure Kubernetes Infrastructure.

output "aks_resource_group" {
  value = azurerm_resource_group.time_api_rg.name
}

output "natgtw_ip" {
  value = azurerm_public_ip.time_api_public_ip
}

output "ssh_command" {
  value = "ssh -i ssh_keys/id_rsa azureuser@${data.azurerm_public_ip.gha_dynamic_ip.ip_address}"
}

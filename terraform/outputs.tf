output "aks_resource_group" {
  value = azurerm_resource_group.kronos_rg.name
}

output "natgtw_ip" {
  value = azurerm_public_ip.kronos_public_ip
}

output "ssh_command" {
  value = "ssh -i ssh_keys/id_rsa azureuser@${data.azurerm_public_ip.gha_dynamic_ip.ip_address}"
}

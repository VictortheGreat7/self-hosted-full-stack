# This file contains the main Terraform configuration for creating an Azure Kubernetes Service (AKS) cluster for the Time API application.

resource "random_pet" "kronos" {
}

resource "azurerm_resource_group" "kronos_rg" {
  name     = "rg-${random_pet.kronos.id}-kronos"
  location = var.region
}

resource "azurerm_linux_virtual_machine" "gha_vm" {
  name                = "gha-${azurerm_resource_group.kronos_rg.name}-vm"
  resource_group_name = azurerm_resource_group.kronos_rg.name
  location            = azurerm_resource_group.kronos_rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.gha_nic.id,
  ]

   admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh_keys/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "gha-os-disk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "ubuntu-pro"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
    github_runner_token = var.github_runner_token
  }))

  lifecycle {
    ignore_changes  = [
      custom_data
    ]
  }
}

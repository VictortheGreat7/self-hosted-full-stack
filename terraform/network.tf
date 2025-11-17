# This file contains the network resources for the Time API Azure Kubernetes cluster.

resource "azurerm_virtual_network" "time_api_vnet" {
  name                = "vnet-${azurerm_resource_group.time_api_rg.name}"
  address_space       = ["10.240.0.0/16"]
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name
}

resource "azurerm_subnet" "gha_subnet" {
  name                 = "gha-${azurerm_resource_group.time_api_rg.name}-subnet"
  resource_group_name  = azurerm_resource_group.time_api_rg.name
  virtual_network_name = azurerm_virtual_network.time_api_vnet.name
  address_prefixes     = ["10.240.0.0/24"]
}

resource "azurerm_public_ip" "gha_public_ip" {
  name                = "gha-${azurerm_resource_group.time_api_rg.name}-publicip"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name
  allocation_method   = "Dynamic"
  sku                = "Basic"
}

resource "azurerm_network_interface" "gha_nic" {
  name                = "gha-${azurerm_resource_group.time_api_rg.name}-nic"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.gha_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gha_public_ip.id
  }
}

resource "azurerm_network_security_group" "gha_nsg" {
  name                = "gha-${azurerm_resource_group.time_api_rg.name}-nsg"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-vnet-inbound"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.gha_nic.id
  network_security_group_id = azurerm_network_security_group.gha_nsg.id
}

data "azurerm_public_ip" "gha_dynamic_ip" {
  name                = azurerm_public_ip.gha_public_ip.name
  resource_group_name = azurerm_resource_group.time_api_rg.name

  depends_on = [azurerm_linux_virtual_machine.gha_vm]
}

resource "azurerm_subnet" "time_api_subnet" {
  name                 = "subnet-${azurerm_resource_group.time_api_rg.name}"
  resource_group_name  = azurerm_resource_group.time_api_rg.name
  virtual_network_name = azurerm_virtual_network.time_api_vnet.name
  address_prefixes     = ["10.240.4.0/22"]
}

resource "azurerm_network_security_group" "time_api_nsg" {
  name                = "nsg-${azurerm_resource_group.time_api_rg.name}"
  resource_group_name = azurerm_resource_group.time_api_rg.name
  location            = azurerm_resource_group.time_api_rg.location

  security_rule {
    name                       = "allow-https-access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http-access"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-vnet-inbound"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "time_api_nsg_subnet_association" {
  subnet_id                 = azurerm_subnet.time_api_subnet.id
  network_security_group_id = azurerm_network_security_group.time_api_nsg.id
}

resource "azurerm_nat_gateway" "time_api_nat_gateway" {
  name                    = "natgw-${azurerm_resource_group.time_api_rg.name}"
  location                = azurerm_resource_group.time_api_rg.location
  resource_group_name     = azurerm_resource_group.time_api_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = {
    Environment = "test"
  }
}

resource "azurerm_public_ip" "time_api_public_ip" {
  name                = "public-ip-${azurerm_resource_group.time_api_rg.name}"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_subnet_nat_gateway_association" "time_api_natgw_subnet_association" {
  nat_gateway_id = azurerm_nat_gateway.time_api_nat_gateway.id
  subnet_id      = azurerm_subnet.time_api_subnet.id
}

resource "azurerm_nat_gateway_public_ip_association" "time_api_natgw_public_ip_association" {
  nat_gateway_id       = azurerm_nat_gateway.time_api_nat_gateway.id
  public_ip_address_id = azurerm_public_ip.time_api_public_ip.id
}

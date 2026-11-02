locals {
  tags = {
    projet = "cloud-security-mirror"
  }
  vnet_cidr    = "10.10.0.0/16"
  public_cidr  = "10.10.1.0/24"
  private_cidr = "10.10.2.0/24"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-secure-mirror-iac"
  location            = azurerm_resource_group.iac.location
  resource_group_name = azurerm_resource_group.iac.name
  address_space       = [local.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "public" {
  name                            = "snet-public"
  resource_group_name             = azurerm_resource_group.iac.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [local.public_cidr]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "private" {
  name                            = "snet-private"
  resource_group_name             = azurerm_resource_group.iac.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [local.private_cidr]
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "public" {
  name                = "nsg-public-iac"
  location            = azurerm_resource_group.iac.location
  resource_group_name = azurerm_resource_group.iac.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-HTTPS-Internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-VNet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private" {
  name                = "nsg-private-iac"
  location            = azurerm_resource_group.iac.location
  resource_group_name = azurerm_resource_group.iac.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-App-To-DB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = local.public_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-VNet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}
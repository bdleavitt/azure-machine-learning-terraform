# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Virtual Network definition

resource "azurerm_virtual_network" "aml_vnet" {
  name                = "${var.prefix}-vnet-${random_string.postfix.result}"
  address_space       = [var.aml_vnet_address_space]
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
}

#TODO: connect to the NSGs
resource "azurerm_subnet" "aml_subnet" {
  name                 = "aml"
  resource_group_name  = azurerm_resource_group.aml_rg.name
  virtual_network_name = azurerm_virtual_network.aml_vnet.name
  address_prefixes     = [var.aml_subnet]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_subnet" "compute_subnet" {
  name                 = "compute"
  resource_group_name  = azurerm_resource_group.aml_rg.name
  virtual_network_name = azurerm_virtual_network.aml_vnet.name
  address_prefixes     = [var.compute_subnet]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage"]
  enforce_private_link_service_network_policies = false
  enforce_private_link_endpoint_network_policies = false
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.aml_rg.name
  virtual_network_name = azurerm_virtual_network.aml_vnet.name
  address_prefixes     = [var.aks_subnet]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.aml_rg.name
  virtual_network_name = azurerm_virtual_network.aml_vnet.name
  address_prefixes     = [var.bastion_subnet]
}




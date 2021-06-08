# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Azure Container Registry (using VNET svc. endpoints)

# OR... deploy Container Registry (using Private Endpoints)
resource "azurerm_container_registry" "aml_acr_pe" {
  name                     = "${var.prefix}acr${random_string.postfix.result}"
  resource_group_name      = azurerm_resource_group.aml_rg.name
  location                 = azurerm_resource_group.aml_rg.location
  sku                      = "Premium" # network rules require premium tier
  admin_enabled            = true
  network_rule_set {
    default_action = "Deny" 
  }
}

# DNS Zones
resource "azurerm_private_dns_zone" "cr_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

# Linking of DNS zones to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "cr_zone_link" {
  name                  = "${random_string.postfix.result}_link_cr"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.cr_zone.name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}

# Private Endpoint configuration
resource "azurerm_private_endpoint" "cr_pe" {
  name                = "${var.prefix}-cr-pe-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = azurerm_subnet.aml_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-cr-psc-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_container_registry.aml_acr_pe.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-cr"
    private_dns_zone_ids = [azurerm_private_dns_zone.cr_zone.id]
  }
}
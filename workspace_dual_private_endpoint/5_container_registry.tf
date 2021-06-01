# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Azure Container Registry (using VNET svc. endpoints)

# Deploy Container Registry with Service endpoints
resource "azurerm_container_registry" "aml_acr" {
  count               = var.use_private_endpoints_for_workspace_resources ? 0 : 1 # if use_private_endpoints is false, then deploy this
  name                     = "${var.prefix}acr${random_string.postfix.result}"
  resource_group_name      = azurerm_resource_group.aml_rg.name
  location                 = azurerm_resource_group.aml_rg.location
  sku                      = "Premium" # network rules require premium tier
  admin_enabled            = true
  network_rule_set {
    default_action = "Deny" 
    virtual_network { 
      action = "Allow"
      subnet_id = azurerm_subnet.aml_subnet.id
    }
    virtual_network { 
      action = "Allow"
      subnet_id = azurerm_subnet.compute_subnet.id
    }
    virtual_network { 
      action = "Allow"
      subnet_id = azurerm_subnet.aks_subnet.id
    }
    virtual_network { 
      action = "Allow"
      subnet_id = var.client_network_subnet_id
    }
  }
}

# OR... deploy Container Registry (using Private Endpoints)
resource "azurerm_container_registry" "aml_acr_pe" {
  count                     = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
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
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

# Linking of DNS zones to Workspace Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "cr_zone_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_link_cr"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.cr_zone[0].name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}
# Linking of DNS zones to Client Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "cr_zone_client_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_clientlink_cr"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.cr_zone[0].name
  virtual_network_id    = var.client_network_vnet_id
}

# Workspace VNET Private Endpoint configuration
resource "azurerm_private_endpoint" "cr_pe" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-cr-pe-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = azurerm_subnet.aml_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-cr-psc-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_container_registry.aml_acr_pe[0].id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-cr"
    private_dns_zone_ids = [azurerm_private_dns_zone.cr_zone[0].id]
  }
}
# Client VNET Private Endpoint configuration
resource "azurerm_private_endpoint" "cr_client_vnet_pe" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-cr-pe-client-vnet-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = var.client_network_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-cr-psc-client-vnet-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_container_registry.aml_acr_pe[0].id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-cr-client-vnet"
    private_dns_zone_ids = [var.client_network_dns_zone_id_acr]
  }
}
# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Key Vault with VNET binding
resource "azurerm_key_vault" "aml_kv" {
  count               = var.use_private_endpoints_for_workspace_resources ? 0 : 1 # if use_private_endpoints is false, then deploy this
  name                = "${var.prefix}-kv-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = true

  network_acls {
    default_action = "Deny"
    ip_rules       = []
    virtual_network_subnet_ids = [azurerm_subnet.aml_subnet.id, azurerm_subnet.compute_subnet.id, azurerm_subnet.aks_subnet.id, var.client_network_subnet_id]
    bypass         = "AzureServices"
  }
}

# Key Vault with Private Endpoint binding
resource "azurerm_key_vault" "aml_kv_pe" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-kv-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  purge_protection_enabled = true

  network_acls {
    default_action = "Deny"
    ip_rules       = []
    bypass         = "AzureServices"
  }
}

# DNS Zones
resource "azurerm_private_dns_zone" "kv_zone" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

# Linking of DNS zones to Workspace Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "kv_zone_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_link_kv"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone[0].name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}

# Linking of DNS zones to Client Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "kv_zone_client_vnet_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_client_vnet_link_kv"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone[0].name
  virtual_network_id    = var.client_network_vnet_id
}

# Private Endpoint configuration for Workspace VNET

resource "azurerm_private_endpoint" "kv_pe" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-kv-pe-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = azurerm_subnet.aml_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-kv-psc-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_key_vault.aml_kv_pe[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_zone[0].id]
  }
}

# Private Endpoint configuration for Workspace VNET
resource "azurerm_private_endpoint" "kv_client_vnet_pe" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-kv-pe-client-vnet-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = var.client_network_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-kv-psc-client-vnet-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_key_vault.aml_kv_pe[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-client-vnet-kv"
    private_dns_zone_ids = [var.client_network_dns_zone_id_kv]
  }
}
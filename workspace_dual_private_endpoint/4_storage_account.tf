# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Storage Account with VNET binding and Private Endpoint for Blob and File

resource "azurerm_storage_account" "aml_sa" {
  name                     = "${var.prefix}sa${random_string.postfix.result}"
  location                 = azurerm_resource_group.aml_rg.location
  resource_group_name      = azurerm_resource_group.aml_rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Virtual Network & Firewall configuration

resource "azurerm_storage_account_network_rules" "firewall_rules" {
  count               = var.use_private_endpoints_for_workspace_resources ? 0 : 1 # if use_private_endpoints is false, then deploy this
  resource_group_name  = azurerm_resource_group.aml_rg.name
  storage_account_name = azurerm_storage_account.aml_sa.name

  default_action             = "Deny"
  ip_rules                   = []
  virtual_network_subnet_ids = [azurerm_subnet.aml_subnet.id, azurerm_subnet.compute_subnet.id, azurerm_subnet.aks_subnet.id, var.client_network_subnet_id] # add service endpoint for workspace subnets and provided client network subnet
  bypass                     = ["AzureServices"]

  # Set network policies after Workspace has been created (will create File Share Datastore properly)
  depends_on = [azurerm_machine_learning_workspace.aml_ws]
}

resource "azurerm_storage_account_network_rules" "firewall_rules_pe" {
  count                = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  resource_group_name  = azurerm_resource_group.aml_rg.name
  storage_account_name = azurerm_storage_account.aml_sa.name

  default_action             = "Deny"
  bypass                     = ["AzureServices"]

  # Set network policies after Workspace has been created (will create File Share Datastore properly)
  depends_on = [azurerm_machine_learning_workspace.aml_ws]
}

# DNS Zones
resource "azurerm_private_dns_zone" "sa_zone_blob" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

resource "azurerm_private_dns_zone" "sa_zone_file" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

# Linking of DNS zones to Workspace Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "sa_zone_blob_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_link_blob"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sa_zone_blob[0].name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "sa_zone_file_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_link_file"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sa_zone_file[0].name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}

# Linking of DNS zones to Provided Client Network
/* 
## If DNS zones already exist in the target VNET, don't try to create them again
resource "azurerm_private_dns_zone_virtual_network_link" "sa_zone_blob_client_vnet_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_link_client_vnet_blob"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sa_zone_blob[0].name
  virtual_network_id    = var.client_network_vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "sa_zone_file_client_vnet_link" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                  = "${random_string.postfix.result}_link_client_vnet_file"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sa_zone_file[0].name
  virtual_network_id    = var.client_network_vnet_id
}
*/

# Private Endpoint configuration - workspace VNET
resource "azurerm_private_endpoint" "sa_pe_blob" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-sa-pe-blob-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = azurerm_subnet.aml_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-sa-psc-blob-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_storage_account.aml_sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.sa_zone_blob[0].id]
  }
}

resource "azurerm_private_endpoint" "sa_pe_file" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-sa-pe-file-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = azurerm_subnet.aml_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-sa-psc-file-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_storage_account.aml_sa.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-file"
    private_dns_zone_ids = [azurerm_private_dns_zone.sa_zone_file[0].id]
  }
}

# Private Endpoint configuration - client VNET
resource "azurerm_private_endpoint" "sa_pe_client_vnet_blob" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-sa-pe-client-vnet-blob-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = var.client_network_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-sa-psc-blob-client-vnet-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_storage_account.aml_sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-client-blob"
    private_dns_zone_ids = [var.client_network_dns_zone_id_storage_blob] ## existing DNS zone id in client VNET
  }
}

resource "azurerm_private_endpoint" "sa_pe_client_vnet_file" {
  count               = var.use_private_endpoints_for_workspace_resources ? 1 : 0 # if use_private_endpoints is true, then deploy this
  name                = "${var.prefix}-sa-pe-client-vnet-file-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = var.client_network_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-sa-psc-file-client-vnet-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_storage_account.aml_sa.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-client-file"
    private_dns_zone_ids = [var.client_network_dns_zone_id_storage_file] ## existing DNS zone id in client VNET
  }
}
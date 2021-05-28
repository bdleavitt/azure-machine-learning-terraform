# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Azure Machine Learning Workspace with Private Link

# Pass correct resource to AML workspace depending on whether PEs are being used. 
locals {
  key_vault_id          = "${var.use_private_endpoints_for_workspace_resources == false ? azurerm_key_vault.aml_kv[0].id : azurerm_key_vault.aml_kv_pe[0].id}"
  container_registry_id = "${var.use_private_endpoints_for_workspace_resources == false ? azurerm_container_registry.aml_acr[0].id : azurerm_container_registry.aml_acr_pe[0].id}"
}

resource "azurerm_machine_learning_workspace" "aml_ws" {
  name                    = "${var.prefix}-ws-${random_string.postfix.result}"
  friendly_name           = var.workspace_display_name
  location                = azurerm_resource_group.aml_rg.location
  resource_group_name     = azurerm_resource_group.aml_rg.name
  application_insights_id = azurerm_application_insights.aml_ai.id
  key_vault_id            = local.key_vault_id
  container_registry_id   = local.container_registry_id
  storage_account_id      = azurerm_storage_account.aml_sa.id

  identity {
    type = "SystemAssigned"
  }
}

# Create Compute Resources in AML
resource "null_resource" "compute_resources" {
  ## Create Compute Cluster
  provisioner "local-exec" {
    command="az ml computetarget create amlcompute --max-nodes 1 --min-nodes 0 --name cpu-cluster --vm-size Standard_DS3_v2 --idle-seconds-before-scaledown 600 --assign-identity [system] --vnet-name ${azurerm_subnet.compute_subnet.virtual_network_name} --subnet-name ${azurerm_subnet.compute_subnet.name} --vnet-resourcegroup-name ${azurerm_subnet.compute_subnet.resource_group_name} --resource-group ${azurerm_machine_learning_workspace.aml_ws.resource_group_name} --workspace-name ${azurerm_machine_learning_workspace.aml_ws.name}"
  }

  ## Create Compute Instance
  provisioner "local-exec" {
    command="az ml computetarget create computeinstance --name ci-${random_string.postfix.result}-test --vm-size Standard_DS3_v2 --vnet-name ${azurerm_subnet.compute_subnet.virtual_network_name} --subnet-name ${azurerm_subnet.compute_subnet.name} --vnet-resourcegroup-name ${azurerm_subnet.compute_subnet.resource_group_name} --resource-group ${azurerm_machine_learning_workspace.aml_ws.resource_group_name} --workspace-name ${azurerm_machine_learning_workspace.aml_ws.name}"
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [azurerm_machine_learning_workspace.aml_ws]
}

# Configure the Workspace Image Build target
resource "null_resource" "configure_workspace" {
  provisioner "local-exec" {
    command = "az ml workspace update --image-build-compute cpu-cluster --resource-group ${azurerm_machine_learning_workspace.aml_ws.resource_group_name} --workspace-name ${azurerm_machine_learning_workspace.aml_ws.name}"
  }
  depends_on = [null_resource.compute_resources]
}

# DNS Zones
resource "azurerm_private_dns_zone" "ws_zone_api" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

resource "azurerm_private_dns_zone" "ws_zone_notebooks" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = azurerm_resource_group.aml_rg.name
}

# Linking of DNS zones to Virtual Network

resource "azurerm_private_dns_zone_virtual_network_link" "ws_zone_api_link" {
  name                  = "${random_string.postfix.result}_link_api"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.ws_zone_api.name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "ws_zone_notebooks_link" {
  name                  = "${random_string.postfix.result}_link_notebooks"
  resource_group_name   = azurerm_resource_group.aml_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.ws_zone_notebooks.name
  virtual_network_id    = azurerm_virtual_network.aml_vnet.id
}

# Private Endpoint configuration

resource "azurerm_private_endpoint" "ws_pe" {
  name                = "${var.prefix}-ws-pe-${random_string.postfix.result}"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  subnet_id           = azurerm_subnet.aml_subnet.id

  private_service_connection {
    name                           = "${var.prefix}-ws-psc-${random_string.postfix.result}"
    private_connection_resource_id = azurerm_machine_learning_workspace.aml_ws.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-ws"
    private_dns_zone_ids = [azurerm_private_dns_zone.ws_zone_api.id, azurerm_private_dns_zone.ws_zone_notebooks.id]
  }

  # Add Private Link after we configured the workspace and attached AKS
  depends_on = [null_resource.compute_resources, azurerm_kubernetes_cluster.aml_aks]
}

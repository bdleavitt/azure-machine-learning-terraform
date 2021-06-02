# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

resource "azurerm_public_ip" "bastion_ip" {
  count               = var.deploy_bastion ? 1 : 0
  name                = "${var.prefix}-public-ip-bastion"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "jumphost_bastion" {
  count               = var.deploy_jumphost ? 1 : 0
  name                = "${var.prefix}-bastion-host"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name = azurerm_resource_group.aml_rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip[count.index].id
  }
}
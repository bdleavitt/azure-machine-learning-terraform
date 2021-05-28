#TODO: attach NSG to the subnets
resource "azurerm_network_security_group" "amlnsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.aml_rg.location
  resource_group_name  = azurerm_resource_group.aml_rg.name

  security_rule {
    name                       = "AzureBatch"
    priority                   = 1040
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "29876-29877"
    destination_port_range     = "*"
    source_address_prefix      = "BatchNodeManagement"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AzureML"
    priority                   = 1050
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "44224"
    destination_port_range     = "*"
    source_address_prefix      = "AzureMachineLearning"
    destination_address_prefix = "*"
  }
}
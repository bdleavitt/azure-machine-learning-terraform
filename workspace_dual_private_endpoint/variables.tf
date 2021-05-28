# Copyright (c) 2021 Microsoft
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

variable "resource_group" {
  default = "aml-terraform-demo"
}

variable "workspace_display_name" {
  default = "aml-terraform-demo"
}

variable "location" {
  default = "East US 2"
}

variable "aml_vnet_address_space" {
  default = "10.99.0.0/16"
}

variable "aml_subnet" {
  default = "10.99.1.0/24"
}

variable "compute_subnet" {
  default = "10.99.2.0/24"
}

variable "aks_subnet" {
  default = "10.99.3.0/24"
}

variable "bastion_subnet" {
  default = "10.99.10.0/27"
}

variable "deploy_aks" {
  default = false
}

variable "use_private_endpoints_for_workspace_resources" {
  default = false
}

variable "jumphost_username" {
  default = "azureuser"
}

variable "jumphost_password" {
  default = "ThisIsNotVerySecure!"
}

variable "prefix" {
  type = string
  default = "aml"
}

resource "random_string" "postfix" {
  length = 6
  special = false
  upper = false
}

# Client Network VNET Subnet ID

variable "client_network_vnet_id" {
  type = string
}

variable "client_network_subnet_id" {
  type = string
}

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "devwatch" {
  name     = var.resource_group_name
  location = "canadacentral"
}

resource "azurerm_virtual_network" "devwatch" {
    name                = "devwatch-net"
    address_space       = ["10.0.0.0/16"]
    location            = "canadacentral"
    resource_group_name = azurerm_resource_group.devwatch.name
}

resource "azurerm_subnet" "devwatch" {
  name = "devwatch-subnet"
  resource_group_name = azurerm_resource_group.devwatch.name
  virtual_network_name = azurerm_virtual_network.devwatch.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "devwatch" {
  name = "devwatch-nic"
  location = azurerm_resource_group.devwatch.location
  resource_group_name = azurerm_resource_group.devwatch.name

  ip_configuration {
    name = "devwatch-subnet"
    subnet_id = azurerm_subnet.devwatch.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "devwatch" {
  name = "devwatch-vm"
  resource_group_name = azurerm_resource_group.devwatch.name
  location = azurerm_resource_group.devwatch.location
  size = "Standard_B1s"
  admin_username = "devwatch"
  network_interface_ids = [ azurerm_network_interface.devwatch.id ]

  admin_ssh_key {
    username = "devwatch"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer = "CentOS"
    sku = "7.5"
    version = "latest"
  }
}

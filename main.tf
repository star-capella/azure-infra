# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.99"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "workportal" {
  name     = var.resource_group_name
  location = "canadacentral"
}

resource "azurerm_virtual_network" "workportal" {
    name                = "workportal-net"
    address_space       = ["10.0.0.0/16"]
    location            = "canadacentral"
    resource_group_name = azurerm_resource_group.workportal.name
}

resource "azurerm_subnet" "workportal" {
  name = "workportal-subnet"
  resource_group_name = azurerm_resource_group.workportal.name
  virtual_network_name = azurerm_virtual_network.workportal.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "workportal" {
  name = "publicIP"
  location = "canadacentral"
  resource_group_name = azurerm_resource_group.workportal.name
  allocation_method = "Static"
}

data "azurerm_public_ip" "the_public_ip" {
  name = azurerm_public_ip.workportal.name
  resource_group_name = azurerm_public_ip.workportal.resource_group_name
}

# CLI: az vm image terms accept --urn "almalinux":"almalinux":"8_5":"latest"
# or 
# terraform import azurerm_marketplace_agreement.workportal <agreement-string>
resource "azurerm_marketplace_agreement" "workportal" {
  publisher = "almalinux"
  offer = "almalinux"
  plan = "8_5"
}

resource "azurerm_network_security_group" "workportal" {
  name = "networkSecurityGroup"
  location = "canadacentral"
  resource_group_name = azurerm_resource_group.workportal.name

  security_rule {
    name = "SSH"
    priority = 1001
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "workportal" {
  name = "workportal-nic"
  location = azurerm_resource_group.workportal.location
  resource_group_name = azurerm_resource_group.workportal.name

  ip_configuration {
    name = "workportal-subnet"
    subnet_id = azurerm_subnet.workportal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.workportal.id

  }
}

output "ip_address" {
  value = azurerm_public_ip.workportal.ip_address
}

resource "azurerm_linux_virtual_machine" "workportal" {
  name = "workportal-vm"
  resource_group_name = azurerm_resource_group.workportal.name
  location = azurerm_resource_group.workportal.location
  size = "Standard_B1ms"
  admin_username = "tcurtis"
  network_interface_ids = [ azurerm_network_interface.workportal.id ]

  admin_ssh_key {
    username = "tcurtis"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "almalinux"
    offer = "almalinux"
    sku = "8_5"
    version = "latest"
  }

  plan {
    name = "8_5"
    product = "almalinux"
    publisher = "almalinux"
  }

  provisioner "remote-exec" {
    inline = ["sudo dnf -y install python3-libs"]

    connection {
      host = "${azurerm_public_ip.workportal.ip_address}"
      type        = "ssh"
      private_key = file("~/.ssh/id_rsa")
      user        = "tcurtis"
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${azurerm_public_ip.workportal.ip_address},' .../workportal-server/rhel-playbook.yml"
  }
}

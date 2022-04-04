terraform {
    required_version = ">= 0.13"

    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
    }  
}
provider "azurerm" {
  features{}
}

resource "azurerm_resource_group" "rg-aulainfra" {
  name = "aulainfraterraform"
  location = "brazilsouth"
}

resource "azurerm_virtual_network" "vnet-aulainfra" {
  name                = "vnet"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "exercicio1"
  }
}

resource "azurerm_subnet" "subnet-aulainfra" {
  name                 = "snet"
  resource_group_name  = azurerm_resource_group.rg-aulainfra.name
  virtual_network_name = azurerm_virtual_network.vnet-aulainfra.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "publicip-aulainfra" {
  name                = "myPublicIP"
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  location            = azurerm_resource_group.rg-aulainfra.location
  allocation_method   = "Static"

  tags = {
    environment = "exercicio1"
  }
}

resource "azurerm_network_security_group" "sg-aulainfra" {
  name                = "MySecurityGroup1"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


  tags = {
    environment = "exercicio1"
  }
}

resource "azurerm_network_interface" "interface-aulainfra" {
  name                = "MyInterface"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.subnet-aulainfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.publicip-aulainfra.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsgAssociation-aulainfra" {
  network_interface_id      = azurerm_network_interface.interface-aulainfra.id
  network_security_group_id = azurerm_network_security_group.sg-aulainfra.id
}

resource "azurerm_storage_account" "storage-aulainfra" {
  name                     = "saaulainfra"
  resource_group_name      = azurerm_resource_group.rg-aulainfra.name
  location                 = azurerm_resource_group.rg-aulainfra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "exercicio1"
  }
}

resource "azurerm_virtual_machine" "vm-aulainfra" {
  name                = "myvmaulainfra"
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  location            = azurerm_resource_group.rg-aulainfra.location
  vm_size             = "Standard_E2bs_v5"
  network_interface_ids = [azurerm_network_interface.interface-aulainfra.id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = var.user
    admin_password = var.pwd_user
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "staging"
  }
}

data "azurerm_public_ip" "ip-aula"{
    name = azurerm_public_ip.publicip-aulainfra.name
    resource_group_name = azurerm_resource_group.rg-aulainfra.name
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula.ip_address
    user = var.user
    password = var.pwd_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-aulainfra
  ]
}

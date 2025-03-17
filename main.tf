provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "dev_rg" {
  name     = "DevRG"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "dev_vnet" {
  name                = "DevVNet"
  resource_group_name = azurerm_resource_group.dev_rg.name
  location            = azurerm_resource_group.dev_rg.location
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "dev_subnet" {
  name                 = "DevSubnet"
  resource_group_name  = azurerm_resource_group.dev_rg.name
  virtual_network_name = azurerm_virtual_network.dev_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "dev_pip" {
  name                = "DevJenkins-PIP"
  resource_group_name = azurerm_resource_group.dev_rg.name
  location            = azurerm_resource_group.dev_rg.location
  allocation_method   = "Dynamic"
}

# Network Security Group (NSG) to Allow SSH and Jenkins
resource "azurerm_network_security_group" "dev_nsg" {
  name                = "DevJenkins-NSG"
  resource_group_name = azurerm_resource_group.dev_rg.name
  location            = azurerm_resource_group.dev_rg.location

  security_rule {
    name                       = "AllowSSH"
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
    name                       = "AllowJenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "dev_nic" {
  name                = "DevJenkins-NIC"
  location            = azurerm_resource_group.dev_rg.location
  resource_group_name = azurerm_resource_group.dev_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev_subnet.id
    public_ip_address_id          = azurerm_public_ip.dev_pip.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine with Jenkins Installation
resource "azurerm_linux_virtual_machine" "dev_vm" {
  name                = "Dev-Jenkins"
  resource_group_name = azurerm_resource_group.dev_rg.name
  location            = azurerm_resource_group.dev_rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "jenkinsadmin"
  admin_password      = "devops@12345"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.dev_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Cloud-init script to install Jenkins
  custom_data = base64encode(<<EOF
#!/bin/bash
sudo apt update -y
sudo apt install openjdk-17-jre -y
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update -y
sudo apt install jenkins -y
sudo systemctl enable jenkins
sudo systemctl start jenkins
EOF
  )
}

# Wait for 80 minutes before destroying resources
resource "time_sleep" "wait_time" {
  create_duration = "80m"
}

Auto-shutdown after 80 minutes (Optional)
 resource "null_resource" "auto_shutdown" {
   depends_on = [time_sleep.wait_time]

   provisioner "local-exec" {
     command = "az vm delete --name Dev-Jenkins --resource-group DevRG --yes"
   }
 }
# edit 6

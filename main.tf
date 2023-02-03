terraform {
  backend azurerm {
    resource_group_name = "terraform-ansible-rg"
    storage_account_name = "tfsaccount"
    container_name = "tfscontainer"
    key = "terraform.tfstate"  
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# RESOURCE GROUP
resource "azurerm_resource_group" "rg" {
  name     = "Team2-Terraform-RG"
  location = "Southeast Asia"
  tags = {
    environment = "Test Terraform Demo"
  }
}

#Getting admin password from key vault
data "azurerm_key_vault" "kv01" {
  name                = "tfkv-01"
  resource_group_name = "terraform-ansible-rg"
}

data "azurerm_key_vault" "kv02" {
  name                = "tfkv-01"
  resource_group_name = "terraform-ansible-rg"
}

data "azurerm_key_vault_secret" "kv01" {
  name         = "admin-password"
  key_vault_id = data.azurerm_key_vault.kv01.id
}

data "azurerm_key_vault_secret" "kv02" {
  name         = "username"
  key_vault_id = data.azurerm_key_vault.kv02.id
}

# AVAILABILITY SET
resource "azurerm_availability_set" "availability_set" {
  name                         = "tf_lbavset"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# PUBLIC IP FOR THE LOAD BALANCER
resource "azurerm_public_ip" "public_ip_of_LB" {
  name                = "tf_PublicIPForLB"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# PUBLIC IP FOR 2 VIRTUAL MACINES
resource "azurerm_public_ip" "public_ip_of_VM" {
  name                = "pip_LinuxVM${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  count               = 2
}

# VNET
resource "azurerm_virtual_network" "vnet" {
  name                = "tfVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# SUBNET
resource "azurerm_subnet" "subnet" {
  name                 = "tfSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# LOAD BALANCER
resource "azurerm_lb" "load_balancer" {
  name                = "tf_loadBalancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = azurerm_public_ip.public_ip_of_LB.id
  }
}

# BACKEND ADRESS POOL
resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "tf_BackEndAddressPool"
}

# NAT RULE 
resource "azurerm_lb_nat_rule" "lb_nat_rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.load_balancer.id
  name                           = "HTTPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "publicIPAddress"
}

# LB PROBE
resource "azurerm_lb_probe" "lb_health_probe" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.load_balancer.id
  name                = "tf_health_probe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

# LB RULE
resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.load_balancer.id
  name                           = "tf_LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_pool.id
  probe_id                       = azurerm_lb_probe.lb_health_probe.id
}

# NIC
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "tfNIC${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "tfNicConfiguration${count.index + 1}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_of_VM[count.index].id
    # load_balancer_backend_address_pool_ids = azurerm_lb_backend_address_pool.lb_backend_pool.id
    # load_balancer_inbound_nat_rules_ids = ["${element(azurerm_lb_nat_rule.tcp.*.id,count.index)}"]
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_backend_pool_assoc" {
  count                   = 2
  network_interface_id    = element(azurerm_network_interface.nic.*.id, count.index)
  ip_configuration_name   = "tfNicConfiguration${count.index + 1}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "tfNetworkSecurityGroup"
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.rg.name

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

  tags = {
    environment = "Test Terraform Demo"
  }
}

# Network security rule for http
resource "azurerm_network_security_rule" "network_security_rule" {
  name                        = "httpRule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "association" {
  count                     = 2
  network_interface_id      = element(azurerm_network_interface.nic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# VIRTUAL MACHINES 
resource "azurerm_virtual_machine" "linuxvm" {
  count                 = 2
  name                  = "tf_LinuxVM${count.index}"
  location              = azurerm_resource_group.rg.location
  availability_set_id   = azurerm_availability_set.availability_set.id
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "tfUbuntuVM${count.index}"
    admin_username = data.azurerm_key_vault_secret.kv02.value
    admin_password = data.azurerm_key_vault_secret.kv01.value
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "Test Terraform Demo"
  }
  depends_on = [azurerm_network_interface.nic]
}
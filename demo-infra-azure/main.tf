/*
  SUSCRIPTION taller
*/

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.17"
    }
  }
}

provider "azurerm" {
  features {
  }
}

/* Creando Resource Group  */

resource "azurerm_resource_group" "spoke" {

  name     = "rg-taller-dev-eastus"
  location = "eastus"
  tags = {
    Enviroment = "DEV"
    Capa       = "ResourceGroup"
    Type       = "Spoke"
  }
}

/* Creando VNET  */
resource "azurerm_virtual_network" "spoke" {

  name                = "vnet-taller-dev"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = ["10.112.0.0/17"]

  tags = {
    Enviroment = "DEV"
    Capa       = "Network"
    Type       = "Spoke"
  }
}

/* Creando SVNET  */

resource "azurerm_subnet" "spoke_aks" {
  name                 = "svnet-01-taller-private-dev"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.112.0.0/19"]
}

/* Creando Storage Account CDN  */
resource "azurerm_storage_account" "spoke" {
  name                     = "satallerdev"
  resource_group_name      = azurerm_resource_group.spoke.name
  location                 = azurerm_resource_group.spoke.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  static_website {
    index_document = "index.html"
  }

  tags = {
    Environment = "DEV"
    Capa        = "Storage"
    Type        = "Spoke"
  }
}

resource "azurerm_cdn_profile" "spoke" {
  name                = "cdn-profile-01-hub-dev"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  sku                 = "Standard_Microsoft"

  tags = {
    Environment = "DEV"
    Capa        = "CDN"
  }
}

# CDN Endpoint
resource "azurerm_cdn_endpoint" "spoke" {
  name                = "cdn-endpoint-01-hub-dev"
  profile_name        = azurerm_cdn_profile.spoke.name #azurerm_cdn_profile.static-web-demo-cdnprofile.name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  origin_host_header  = azurerm_storage_account.spoke.primary_web_host # azurerm_storage_account.static-web-demo-storage.primary_web_host

  origin {
    name      = "staticwebdemo"
    host_name = azurerm_storage_account.spoke.primary_web_host
  }
}

/* Creando ACR  */
resource "azurerm_container_registry" "spoke" {
  name                = "acrtallerdev"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  sku                 = "Standard"
  tags = {
    Environment = "DEV"
    Capa        = "Container"
    Type        = "Spoke"
  }
}

/* Creando AKS  */
resource "azurerm_kubernetes_cluster" "aks1" {
  name                = "aks-01-taller-dev-eastus"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  dns_prefix          = "aks1portaltaller"
  network_profile {
    network_plugin = "azure"
    #  outbound_type = "userDefinedRouting"
  }
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  default_node_pool {
    name = "agentpool"

    vm_size             = "standard_a2_v2"
    enable_auto_scaling = true
    max_count           = 3
    min_count           = 1
    #zones = [ 1,2,3 ]  
    vnet_subnet_id = azurerm_subnet.spoke_aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "DEV"
    Capa        = "Container"
    App         = "Business"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "aks1" {
  name                  = "agentpoolapp"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks1.id
  vm_size               = "standard_a2_v2"
  enable_auto_scaling   = true
  max_count             = 3
  min_count             = 1

  #zones = [ 1,2,3 ]

  tags = {
    Environment = "DEV"
    Capa        = "Node"
  }
  vnet_subnet_id = azurerm_subnet.spoke_aks.id
}

resource "azurerm_role_assignment" "spoke_aks1" {
  principal_id                     = azurerm_kubernetes_cluster.aks1.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.spoke.id
  skip_service_principal_aad_check = true
}
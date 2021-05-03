provider "azurerm" { #specify the provider
    version = "2.56.0" #specify version
    features {} #specify features
}

data "azurerm_client_config" "current" {} #used for keyvault

resource "azurerm_resource_group" "grouphrg" { #create resource group, grouphrg is not the name of the resource group, but rather a tag
    name = "grouph-minitwit" #name of the RG
    location = "West Europe" #netherlands vs North Europe which is Ireland
}

# resource "azurerm_kubernetes_cluster" "aks" {
#     name = "mvc-minitwit_aks"
#     resource_group_name = azurerm_resource_group.grouphrg.name
#     location = azurerm_resource_group.grouphrg.location
#     dns_prefix = "mvcminitwitaks"

#     default_node_pool {
#         name = "default"
#         node_count = 1
#         vm_size = "Standard_D2_v2"
#     }

#     identity {
#         type = "SystemAssigned"
#     }

#     addon_profile {
#     aci_connector_linux {
#       enabled = false
#     }

#     azure_policy {
#       enabled = false
#     }

#     http_application_routing {
#       enabled = false
#     }

#     oms_agent {
#       enabled = false
#     }
#   }
# }

#TO DO TO INITIALLY CREATE RG GROUP IF IT DOESNT EXIST: 
# 1) write terraform init in cmd line, which creates .terraform folder

# 2) write terraform plan, it goes to azure and sees if it has that RG

# 3) if it doesnt work, login in to azure with az login

# 4) write terraform apply - it creates the resource group

#HOW TO CREATE RESOURCES WITHIN RG, WITH ACR:
resource "azurerm_container_registry" "acr" {
    name                        = "mvcminitwitACR"
    resource_group_name         = azurerm_resource_group.grouphrg.name
    location                    = azurerm_resource_group.grouphrg.location
    sku                         = "Basic"
    admin_enabled               = true
}

resource "azurerm_container_registry_webhook" "webhook" {
  name                = "NeutralsMinitwit"
  resource_group_name = azurerm_resource_group.grouphrg.name
  registry_name       = azurerm_container_registry.acr.name
  location            = azurerm_resource_group.grouphrg.location

  service_uri = var.webhook_serviceuri #from container settings on web app
  status      = "enabled"
  scope       = "neutralsminitwit:*"
  actions     = ["push"]
  custom_headers = {
    "Content-Type" = "application/json"
  }
}

resource "azurerm_app_service_plan" "service_plan" {
    name                        = "mvc-minitwit-asp"
    location                    = "West Europe"
    resource_group_name         = azurerm_resource_group.grouphrg.name
    kind                        = "Linux"
    reserved                    = true
    sku {
        tier = "Basic"
        size = "B1"
    }
}

resource "azurerm_app_service" "app-service" {
    name                        = "mvc-minitwit"
    location                    = azurerm_resource_group.grouphrg.location
    resource_group_name         = azurerm_resource_group.grouphrg.name
    app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    app_settings = {
        DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
        DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
        DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
    }

    site_config {
        linux_fx_version = "DOCKER|mvc-minitwit-acr.azurecr.io/neutralsminitwit:*"
        always_on        = "true"
    }

    identity {
        type = "SystemAssigned"
    }

    connection_string {
    name  = "MvcDbContext"
    type  = "SQLServer"
    value = var.server_conn  #NOT SECURED!!! connects to db in neutralsRG
  }
}

resource "azurerm_storage_account" "storage" {
  name                     = "mvcminitwitstorage"
  resource_group_name      = azurerm_resource_group.grouphrg.name
  location                 = azurerm_resource_group.grouphrg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storagecontainer" {
  name                  = "terraformstate"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_sql_server" "azsqlserver" {
    name                        = "mvc-minitwit-server"
    resource_group_name         = azurerm_resource_group.grouphrg.name
    #app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    location                    = azurerm_resource_group.grouphrg.location
    version                     = "12.0"
    administrator_login               = var.server_username
    administrator_login_password      = var.server_password 

    extended_auditing_policy {
        storage_endpoint                        = azurerm_storage_account.storage.primary_blob_endpoint
        storage_account_access_key              = azurerm_storage_account.storage.primary_access_key
        storage_account_access_key_is_secondary = true
    }

    tags = {
        environment = "production"
    }
}

resource "azurerm_sql_database" "sqldb" {
  name                = "mvc-minitwit-db"
  resource_group_name = azurerm_resource_group.grouphrg.name
  location            = "West Europe"
  server_name         = azurerm_sql_server.azsqlserver.name

  extended_auditing_policy {
    storage_endpoint                        = azurerm_storage_account.storage.primary_blob_endpoint
    storage_account_access_key              = azurerm_storage_account.storage.primary_access_key
    storage_account_access_key_is_secondary = true
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_app_service" "web_app_container-graf" {
    name                        = "mvc-minitwit-graf"
    location                    = azurerm_resource_group.grouphrg.location
    resource_group_name         = azurerm_resource_group.grouphrg.name
    app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    
    site_config {
        linux_fx_version = "COMPOSE|${filebase64("./mvc-minitwit/docker-compose.yml")}"
        always_on        = "true"
    }
}

resource "azurerm_app_service" "web_app_container-seq" {
    name                        = "mvc-minitwit-seq"
    location                    = azurerm_resource_group.grouphrg.location
    resource_group_name         = azurerm_resource_group.grouphrg.name
    app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    
    site_config {
        linux_fx_version = "COMPOSE|${filebase64("./mvc-minitwit/Seq/docker-compose.yml")}"
        always_on        = "true"
    }
}

data "terraform_remote_state" "trs" {
  backend = "azurerm"
  config = {
    resource_group_name   = azurerm_resource_group.grouphrg.name
    storage_account_name  = azurerm_storage_account.storage.name
    container_name        = azurerm_storage_container.storagecontainer.name
    key                   = "tf.tfstate"
    access_key    = var.storage_accesskey
  }
}

## Outputs
output "app_service_name" {
  value = "${azurerm_app_service.app-service.name}"
}
output "app_service_default_hostname" {
  value = "https://${azurerm_app_service.app-service.default_site_hostname}"
}
output "db_connect_string" {
  description = "MySQL database connection string"
  value       = "Server=tcp:mvc-minitwit-server.database.windows.net,1433;Initial Catalog=mvc-minitwit-db;Persist Security Info=False;User ID=${var.server_username};Password=${var.server_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}

output "server_username" {
  description = "Server Username"
  value       = var.server_username
}

output "server_password" {
  description = "Server Password"
  value       = var.server_password
}

output "webhook_serviceuri" {
  description = "Webhook Service Uri"
  value       = var.webhook_serviceuri
}

output "storage_accesskey" {
  description = "Storage Acceskey"
  value       = var.storage_accesskey
}

# output "id" {
#   value = azurerm_kubernetes_cluster.aks.id
# }

# output "client_key" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.client_key
# }

# output "client_certificate" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
# }

# output "cluster_ca_certificate" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
# }

# output "host" {
#   value = azurerm_kubernetes_cluster.aks.kube_config.0.host
# }
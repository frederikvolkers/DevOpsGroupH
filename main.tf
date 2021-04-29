provider "azurerm" { #specify the provider
    version = "2.56.0" #specify version
    features {} #specify features
}

data "terraform_remote_state" "foo" {
  backend = "azurerm"
  config = {
    resource_group_name   = "tfmainrg"
    storage_account_name  = "storageacctftest"
    container_name        = "terraformstate"
    key                   = "tf.tfstate"
    access_key    = "nk+qDk3qFRTFuU84uZJaL9t2+dBGEM8Ii6YWSn5USc337vXYKb//DNapw4ZN+eJnNjl/RbIbdK1rop4iYCvfiQ=="
  }
}

terraform {
  backend "azurerm" {
    resource_group_name   = "tfmainrg"
    storage_account_name  = "storageacctftest"
    container_name        = "terraformstate"
    key                   = "tf.tfstate"
  }
}

resource "azurerm_resource_group" "tf_test" { #create resource group, tf_test is not the name of the resource group, but rather a tag
    name = "tfmainrg" #name of the RG
    location = "West Europe" #netherlands vs North Europe which is Ireland
}

resource "azurerm_kubernetes_cluster" "aks" {
    name = "mvc-minitwit_aks"
    resource_group_name = azurerm_resource_group.tf_test.name
    location = azurerm_resource_group.tf_test.location
    dns_prefix = "mvcminitwitaks"

    default_node_pool {
        name = "default"
        node_count = 1
        vm_size = "Standard_D2_v2"
    }

    identity {
        type = "SystemAssigned"
    }

    addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    oms_agent {
      enabled = false
    }
  }
}

#init #the link between terra and provider
#plan #plan for the developer, what we want to do, does not execute it. If all the resource groups already exist, then skip the plan step. It is only to initiliaze a resource group.  
#apply #applying the plan. 
#destroy

#TO DO TO INITIALLY CREATE RG GROUP IF IT DOESNT EXIST: 
# 1) write terraform init in cmd line, which creates .terraform folder

# 2) write terraform plan, it goes to azure and sees if it has that RG

# 3) if it doesnt work, login in to azure with az login

# 4) write terraform apply - it creates the resource group

#HOW TO CREATE RESOURCES WITHIN RG, WITH ACR:
resource "azurerm_container_registry" "acr" {
    name                        = "tfTestFRVOacr"
    resource_group_name         = azurerm_resource_group.tf_test.name
    location                    = azurerm_resource_group.tf_test.location
    sku                         = "Basic"
    admin_enabled               = true
}

# resource "azurerm_container_registry_webhook" "webhook" {
#   name                = "NeutralsMinitwit"
#   resource_group_name = azurerm_resource_group.tf_test.name
#   registry_name       = azurerm_container_registry.acr.name
#   location            = azurerm_resource_group.tf_test.location

#   service_uri = "https://$neutrals-minitwit:l3c8r2vEm2HJj3WQaNmhSCgSEzsYTnksaBWPkmBJg6hdCk1SCdZPvQ5aCz81@neutrals-minitwit.scm.azurewebsites.net/docker/hook" #not safe!
#   status      = "enabled"
#   scope       = "neutralsminitwit:117"
#   actions     = ["push"]
#   custom_headers = {
#     "Content-Type" = "application/json"
#   }
# }

resource "azurerm_app_service_plan" "service_plan" {
    name                        = "ASP-mvc-minitwit"
    location                    = "West Europe"
    resource_group_name         = azurerm_resource_group.tf_test.name
    kind                        = "Linux"
    reserved                    = true
    sku {
        tier = "Basic"
        size = "B1"
    }
}

resource "azurerm_app_service" "app-service" {
    name                        = "mvc-minitwit"
    location                    = azurerm_resource_group.tf_test.location
    resource_group_name         = azurerm_resource_group.tf_test.name
    app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    app_settings = {
        DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
        DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.acr.admin_username
        DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.acr.admin_password
    }

    site_config {
        linux_fx_version = "DOCKER|tftestfrvoacr.azurecr.io/neutralsminitwit:119"
        always_on        = "true"
    }

    identity {
        type = "SystemAssigned"
    }

    connection_string {
    name  = "MvcDbContext"
    type  = "SQLServer"
    value = "Server=tcp:minitwit-neutrals.database.windows.net,1433;Initial Catalog=minitwitDb;Persist Security Info=False;User ID=neutrals;Password=Cfias5Vm5eHYu56;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" #NOT SECURED!!! connects to db in neutralsRG
  }
}

resource "azurerm_storage_account" "storage" {
  name                     = "storageacctftest"
  resource_group_name      = azurerm_resource_group.tf_test.name
  #app_service_plan_id      = azurerm_app_service_plan.service_plan.id
  location                 = azurerm_resource_group.tf_test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}



resource "azurerm_sql_server" "azsqlserver" {
    name                        = "mvcminitwitserver"
    resource_group_name         = azurerm_resource_group.tf_test.name
    #app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    location                    = azurerm_resource_group.tf_test.location
    version                     = "12.0"
    administrator_login         = "frvo5098mvcminitwit"
    administrator_login_password      = "Mvc50985098" #FIX THIS, e.g. Keyvault! 

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
  name                = "minitwitDb-2021-4-28-12-16-v2"
  resource_group_name = azurerm_resource_group.tf_test.name
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
    location                    = azurerm_resource_group.tf_test.location
    resource_group_name         = azurerm_resource_group.tf_test.name
    app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    
    site_config {
        linux_fx_version = "COMPOSE|${filebase64("./mvc-minitwit/docker-compose.yml")}"
        always_on        = "true"
    }
}

resource "azurerm_app_service" "web_app_container-seq" {
    name                        = "mvc-minitwit-seq"
    location                    = azurerm_resource_group.tf_test.location
    resource_group_name         = azurerm_resource_group.tf_test.name
    app_service_plan_id         = azurerm_app_service_plan.service_plan.id
    
    site_config {
        linux_fx_version = "COMPOSE|${filebase64("./mvc-minitwit/Seq/docker-compose.yml")}"
        always_on        = "true"
    }
}


# resource "null_resource" "graf-compose"{
#     provisioner "local-exec"{
#         command =<<EOT 
#             az webapp config set \
#             --resource-group ${azurermm_resource_group.tf_test.name} \
#             --name ${azurerm_app_service.web_app_container-graf.name} \
#             --linux-
#             EOT
#     }
# }

# module "web_app_container-graf" {
#   source                      = "innovationnorway/web-app-container/azurerm"
#   name                        = "mvc-minitwit-grafana"
#   plan                        = azurerm_app_service_plan.service_plan
#   resource_group_name         = azurerm_resource_group.tf_test.name
#   container_type              = "compose" #can also use "kube" for kubernetes
#   container_config = file("docker-compose.yml")
# }

# module "web_app_container-seq" {
#   source                      = "innovationnorway/web-app-container/azurerm"
#   name                        = "mvc-minitwit-seq"
#   plan                        = azurerm_app_service_plan.service_plan
#   resource_group_name         = azurerm_resource_group.tf_test.name
#   container_type              = "compose" #can also use "kube" for kubernetes
#   container_config = file("Seq/docker-compose.yml")
# }

## Outputs
output "app_service_name" {
  value = "${azurerm_app_service.app-service.name}"
}
output "app_service_default_hostname" {
  value = "https://${azurerm_app_service.app-service.default_site_hostname}"
}

output "id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "client_key" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.client_key
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
}

output "cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
}

output "host" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.host
}


#HOW TO CREATE RESOURCES WITHIN RG, DOCKERHUB: 
# resource "azurerm_container_group" "tfcg_test" { #create the container of image
#     name                    = "mvc-minitwit"
#     location                = azurerm_resource_group.tf_test.location #you can just refer to other resource, to use.
#     resource_group_name     = azurerm_resource_group.tf_test.name

#     #settings that would choose within azure portal:
#     ip_address_type         = "public"
#     dns_name_label          = "mvc-minitwit-test"
#     os_type                 = "linux"

#     container {
#         name                = "mvc-minitwit"
#         image               = "jokeren9/neutralsminitwit:96" #dockerhub repos, change to acr
#             cpu                 = "1"
#             memory              = "1"

#             ports {
#                 port            = 80
#                 protocol        = "TCP"
#             }
#     }

    
    
# }
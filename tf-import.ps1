terraform import azurerm_resource_group.tf_test /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg

terraform import azurerm_kubernetes_cluster.aks /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourcegroups/tfmainrg/providers/Microsoft.ContainerService/managedClusters/mvc-minitwit_aks

terraform import azurerm_container_registry.acr /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.ContainerRegistry/registries/tfTestFRVOacr

terraform import azurerm_app_service_plan.service_plan /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Web/serverfarms/ASP-mvc-minitwit

terraform import azurerm_storage_account.storage /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Storage/storageAccounts/storageacctftest

terraform import azurerm_app_service.app-service /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Web/sites/mvc-minitwit

terraform import azurerm_sql_server.azsqlserver /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Sql/servers/mvcminitwitserver

terraform import azurerm_app_service.web_app_container-graf /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Web/sites/mvc-minitwit-graf

terraform import azurerm_app_service.web_app_container-seq /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Web/sites/mvc-minitwit-seq

terraform import azurerm_sql_database.sqldb /subscriptions/5fe8fe9e-ec72-4c24-8d51-122c0378b2ba/resourceGroups/tfmainrg/providers/Microsoft.Sql/servers/mvcminitwitserver/databases/minitwitDb-2021-4-28-12-16-v2
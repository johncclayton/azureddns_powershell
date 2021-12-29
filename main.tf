terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "AzDNS"
  location = "${var.location}"
}

resource "azurerm_storage_account" "storage" {
    name = "${random_string.storage_name.result}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    location = "${var.location}"
    account_tier = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "deployments" {
    name = "function-releases"
    storage_account_name = "${azurerm_storage_account.storage.name}"
    container_access_type = "private"
}

resource "azurerm_storage_blob" "appcode" {
    name = "functionapp.zip"
    storage_account_name = "${azurerm_storage_account.storage.name}"
    storage_container_name = "${azurerm_storage_container.deployments.name}"
    type = "block"
    source = "${var.functionapp}"
}

data "azurerm_storage_account_sas" "sas" {
    connection_string = "${azurerm_storage_account.storage.primary_connection_string}"
    https_only = true
    start = "2021-12-31"
    expiry = "2022-12-31"
    resource_types {
        object = true
        container = false
        service = false
    }
    services {
        blob = true
        queue = false
        table = false
        file = false
    }
    permissions {
        read = true
        write = false
        delete = false
        list = false
        add = false
        create = false
        update = false
        process = false
    }
}

resource "azurerm_app_service_plan" "asp" {
  name                = "${var.prefix}-plan"
  location            = "${var.location}"
  resource_group_name = azurerm_resource_group.rg.name

  kind = "FunctionApp"

  sku {
    tier = "FunctionApp"
    size = "Y1"
  }
}

resource "azurerm_function_app" "functions" {
    name = "${var.prefix}-${var.environment}"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    app_service_plan_id = "${azurerm_app_service_plan.asp.id}"
    storage_connection_string = "${azurerm_storage_account.storage.primary_connection_string}"
    version = "~2"

    app_settings = {
        https_only = true
        FUNCTIONS_WORKER_RUNTIME = "powershell"
        FUNCTIONS_EXTENSION_VERSION = "~4"
        FUNCTION_APP_EDIT_MODE = "readonly"
        APPINSIGHTS_INSTRUMENTATION_KEY = "nothing"
        HASH = "${base64encode(filesha256("${var.functionapp}"))}"
        WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=adns;AccountKey=<accountkeyfromportal>==;EndpointSuffix=core.windows.net"
        WEBSITE_RUN_FROM_PACKAGE = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.deployments.name}/${azurerm_storage_blob.appcode.name}${data.azurerm_storage_account_sas.sas.sas}"
    }
}
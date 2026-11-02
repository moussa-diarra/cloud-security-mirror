terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
provider "azuread" {}

variable "location" {
  type    = string
  default = "germanywestcentral"
}

resource "azurerm_resource_group" "iac" {
  name     = "rg-secure-mirror-iac"
  location = var.location
  tags = {
    projet = "cloud-security-mirror"
  }
}
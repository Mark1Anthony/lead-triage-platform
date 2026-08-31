terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state, because more than one operator and CI itself run against this
  # configuration. The storage account is created once by scripts/bootstrap.sh
  # and is not managed here - a configuration cannot hold its own backend.
  # See docs/adr/0003-remote-state.md.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      # Refuse to delete a resource group that still contains something
      # Terraform does not know about.
      prevent_deletion_if_contains_resources = true
    }
  }
}

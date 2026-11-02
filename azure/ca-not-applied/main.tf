terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azuread" {}

variable "emergency_user_object_id" {
  type        = string
  description = "Object ID du compte d'urgence, exclu de la politique"
}

# Template ID du rôle Administrateur général (vu dans tes journaux d'audit)
locals {
  global_admin_role = "62e90394-69f5-4237-9190-012177145e10"
}

resource "azuread_conditional_access_policy" "ca01_mfa_admins" {
  display_name = "IAC-CA01-MFA-Admins"
  state        = "disabled" # jamais "enabled" dans ce dossier

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_roles = [local.global_admin_role]
      excluded_users = [var.emergency_user_object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
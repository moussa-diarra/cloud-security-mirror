data "azurerm_log_analytics_workspace" "existing" {
  name                = "law-secure-mirror-dev"
  resource_group_name = "rg-secure-mirror-dev"
}

resource "azurerm_sentinel_alert_rule_scheduled" "failed_signins" {
  name                       = "iac-echecs-connexion-repetes"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.existing.id
  display_name               = "IAC - Echecs de connexion repetes"
  severity                   = "Medium"
  enabled                    = false
  query_frequency            = "PT5M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["CredentialAccess"]
  techniques                 = ["T1110"]

  query = <<-QUERY
    SigninLogs
    | where ResultType != "0"
    | summarize Echecs = count(), IPs = make_set(IPAddress) by UserPrincipalName
    | where Echecs >= 5
  QUERY

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "FullName"
      column_name = "UserPrincipalName"
    }
  }

  incident {
    create_incident_enabled = true
    grouping {
      enabled = false
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "nsg_changed" {
  name                       = "iac-nsg-regle-modifiee"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.existing.id
  display_name               = "IAC - Regle NSG modifiee"
  severity                   = "Medium"
  enabled                    = false
  query_frequency            = "PT5M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["DefenseEvasion"]
  techniques                 = ["T1562"]

  query = <<-QUERY
    AzureActivity
    | where OperationNameValue has_any (
        "NETWORKSECURITYGROUPS/SECURITYRULES/WRITE",
        "NETWORKSECURITYGROUPS/SECURITYRULES/DELETE",
        "NETWORKSECURITYGROUPS/WRITE",
        "NETWORKSECURITYGROUPS/DELETE")
    | where ActivityStatusValue in ("Success", "Succeeded")
    | project TimeGenerated, Caller, CallerIpAddress, OperationNameValue, ResourceGroup, _ResourceId
  QUERY

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "FullName"
      column_name = "Caller"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIpAddress"
    }
  }

  incident {
    create_incident_enabled = true
    grouping {
      enabled = false
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "roles_groups_changed" {
  name                       = "iac-roles-groupes-modifies"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.existing.id
  display_name               = "IAC - Roles ou groupes modifies"
  severity                   = "Medium"
  enabled                    = false
  query_frequency            = "PT5M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["PrivilegeEscalation"]
  techniques                 = ["T1098"]

  query = <<-QUERY
    AuditLogs
    | where Result == "success"
    | where OperationName has_any ("Add member to group", "Add member to role", "eligible member")
    | extend Cible = tostring(TargetResources[0].userPrincipalName)
    | project TimeGenerated, OperationName, InitiatedBy, Cible, TargetResources
  QUERY

  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "FullName"
      column_name = "Cible"
    }
  }

  incident {
    create_incident_enabled = true
    grouping {
      enabled = false
    }
  }
}
resource "azuread_group" "readers" {
  display_name     = "grp-iac-readers"
  security_enabled = true
}

resource "azuread_group" "netadmins" {
  display_name     = "grp-iac-netadmins"
  security_enabled = true
}

resource "azurerm_role_assignment" "readers" {
  scope                = azurerm_resource_group.iac.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.readers.object_id
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "netadmins" {
  scope                = azurerm_resource_group.iac.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_group.netadmins.object_id
  principal_type       = "Group"
}
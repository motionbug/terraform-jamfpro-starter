terraform {
  required_version = ">= 1.14.1"
  required_providers {
    jamfplatform = {
      source  = "Jamf-Concepts/jamfplatform"
      version = ">= 0.2.0"
    }
    jamfpro = {
      source  = "deploymenttheory/jamfpro"
      version = "0.30.0"
    }
  }
}

data "jamfpro_group" "computer_smart_group_models" {
  for_each         = var.computer_smart_group_model_ids
  group_jamfpro_id = each.value
  group_type       = "COMPUTER"
}

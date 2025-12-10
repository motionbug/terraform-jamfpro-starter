terraform {
  required_version = ">= 1.14.1"
  required_providers {
    jamfpro = {
      source  = "deploymenttheory/jamfpro"
      version = "0.30.0"
    }
    itunessearchapi = {
      source  = "neilmartin83/itunessearchapi"
      version = "1.9.1"
    }
  }
}

locals {
  vpp_adam_ids = [
    for content in var.volume_purchasing_location_data.content :
    content.adam_id
  ]
}

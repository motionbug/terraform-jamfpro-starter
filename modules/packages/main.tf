terraform {
  required_version = ">= 1.14.1"
  required_providers {
    jamfpro = {
      source  = "deploymenttheory/jamfpro"
      version = "0.30.0"
    }
  }
}

locals {
  package_names = [
    "nudge-essentials-2.0.12.81807.pkg",
    "Support.3.0.pkg",
    "Setup.Manager-1.4-629.pkg"
  ]
}

resource "jamfpro_package" "default" {
  for_each              = toset(local.package_names)
  package_name          = each.value
  package_file_source   = "${path.module}/support-files/${each.value}"
  category_id           = var.category_ids["Applications (Managed by Terraform)"]
  info                  = "Managed by Terraform"
  priority              = 10
  reboot_required       = false
  fill_user_template    = false
  os_install            = false
  suppress_updates      = false
  suppress_from_dock    = false
  suppress_eula         = false
  suppress_registration = false
}

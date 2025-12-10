
resource "jamfpro_smart_computer_group" "support_is_installed" {
  name = "Support App Is Installed (Managed by Terraform)"
  criteria {
    name        = "Application Bundle ID"
    priority    = 0
    search_type = "is"
    value       = "nl.root3.support"
  }
  criteria {
    and_or      = "and"
    name        = "Application Version"
    priority    = 1
    search_type = "is"
    value       = "3.0"
  }
}

resource "jamfpro_policy" "install_support" {
  name            = "Install Support App (Managed by Terraform)"
  enabled         = true
  trigger_checkin = true
  frequency       = "Ongoing"
  category_id     = var.category_ids["Applications (Managed by Terraform)"]
  scope {
    all_computers = false
    computer_group_ids = [
      var.computer_smart_group_model_ids["Desktops"],
      var.computer_smart_group_model_ids["Laptops"],
    ]
    exclusions {
      computer_group_ids = [jamfpro_smart_computer_group.nudge_is_installed.id]
    }
  }
  payloads {
    packages {
      distribution_point = "default"
      package {
        id     = var.package_ids["Support.3.0.pkg"]
        action = "Install"
      }
    }
    maintenance {
      recon = true
    }
  }
}

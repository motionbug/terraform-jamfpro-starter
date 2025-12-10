# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Commands

### Terraform Operations
```bash
# Initialize Terraform (required after cloning or changing providers)
terraform init

# View execution plan
terraform plan

# Apply changes with rate-limiting for Jamf Pro API
terraform apply -parallelism=1

# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Enable debug logging
export TF_LOG=DEBUG
terraform apply -parallelism=1
```

### Testing and Validation
```bash
# Run GitHub Actions checks locally
terraform fmt -check -recursive
terraform validate
tflint --recursive
```

## Architecture Overview

### Module Structure
This project uses a **flat module architecture** with dependencies flowing from foundation to application-level resources:

```
settings (foundation - categories, ADE tokens, VPP tokens)
   ↓
computer-smart-groups + mobile-device-smart-groups (targeting/scoping)
   ↓
computer-profiles + mobile-device-profiles + packages (configuration)
   ↓
policies + app-installers + mobile-device-apps (deployment)
   ↓
compliance-benchmarks + blueprints (security)
```

### Module Communication
Modules communicate via **outputs passed as variables**:
- `settings` module exports `category_ids`, `automated_device_enrollment_id`, `volume_purchasing_location_data`
- `computer-smart-groups` exports `model_ids`, `os_version_ids`, `architecture_type_ids`
- `packages` exports `package_ids`
- Downstream modules (policies, profiles) consume these outputs via variables

### Conditional Resource Creation
Several modules use conditional creation based on token availability:
- **computer-prestages** and **mobile-device-prestages**: Only created when `automated_device_enrollment_token` is provided
- **mobile-device-apps**: VPP functionality only available when `volume_purchasing_service_token` is provided

Pattern used:
```hcl
module "computer_prestages" {
  count  = var.automated_device_enrollment_token != null ? 1 : 0
  source = "./modules/computer-prestages"
  # ...
}
```

## Important Patterns

### Rate Limiting Requirements
**Always use `-parallelism=1` when running `terraform apply`.**

Jamf Pro and Jamf Platform APIs have strict rate limiting. Running operations in parallel will result in failed deployments. This is enforced in HCP Terraform via the `TF_CLI_ARGS_apply` environment variable.

### Token Handling
Multi-line tokens (ADE `.p7m` and VPP `.vpptoken` files) require heredoc syntax in local `terraform.tfvars`:

```hcl
automated_device_enrollment_token = <<EOF
paste-token-content-here
EOF
```

Use `cat /path/to/token | pbcopy` to copy token contents to clipboard.

### Safe Output Patterns
Modules use safe output patterns to handle conditional resources:

```hcl
# settings/outputs.tf
output "automated_device_enrollment_id" {
  value = length(jamfpro_device_enrollments.default) > 0 ? jamfpro_device_enrollments.default[0].id : null
}
```

This prevents errors when resources don't exist (e.g., when tokens aren't provided).

### Template Rendering
Configuration profiles use `templatefile()` to inject variables:

```hcl
# Example from mobile-device-profiles/wi-fi.tf
templatefile("path/to/template.tpl", { 
  ssid = local.wifi_ssid,
  password = local.wifi_password 
})
```

## Adding New Resources

### Adding a Policy
1. Create file in `modules/policies/` (e.g., `install-app.tf`)
2. Reference existing IDs via variables:
   ```hcl
   resource "jamfpro_policy" "install_app" {
     name        = "Install App (Managed by Terraform)"
     category_id = var.category_ids["Applications (Managed by Terraform)"]
     
     scope {
       computer_group_ids = [
         var.computer_smart_group_model_ids["Laptops"]
       ]
     }
   }
   ```
3. Run `terraform plan` and `terraform apply -parallelism=1`

### Adding a Smart Group
1. Create file in `modules/computer-smart-groups/` (e.g., `custom-group.tf`)
2. Define the smart group:
   ```hcl
   resource "jamfpro_smart_computer_group" "custom" {
     name = "Custom Group (Managed by Terraform)"
     criteria {
       name        = "Operating System Version"
       priority    = 0
       search_type = "like"
       value       = "15."
     }
   }
   ```
3. Export ID in `modules/computer-smart-groups/outputs.tf`:
   ```hcl
   output "model_ids" {
     value = merge(
       { for k, g in jamfpro_smart_computer_group.model : k => g.id },
       { custom = jamfpro_smart_computer_group.custom.id }
     )
   }
   ```
4. Use in other modules via `var.computer_smart_group_model_ids["custom"]`

### Adding DRY Resources (App Installers, Mobile Apps)
Some modules use `for_each` with local lists for standardized resources:

```hcl
# modules/app-installers/microsoft-office.tf
locals {
  microsoft_apps = ["Word", "Excel", "PowerPoint"]
}

resource "jamfpro_app_installer" "microsoft" {
  for_each = toset(local.microsoft_apps)
  name     = "Microsoft ${each.value}"
  # ...
}
```

## Naming Conventions

### Files and Folders
- Use **lowercase with hyphens**: `computer-smart-groups/`, `local-admin-password-solution.tf`
- One resource per file when appropriate
- Descriptive names: `automated-device-enrollment.tf` (not `ade.tf`)

### Resource Names (in code)
- Use **underscores** for Terraform identifiers:
  ```hcl
  resource "jamfpro_policy" "install_microsoft_teams" {
    name = "Install Microsoft Teams (Managed by Terraform)"
  }
  ```

### Display Names (in Jamf Pro)
- Human-readable with proper capitalization
- Include `(Managed by Terraform)` suffix to identify IaC-managed resources

### Variables and Outputs
- Use underscores, lowercase, descriptive names
- Avoid abbreviations unless widely understood (e.g., `vpp` is acceptable)

## Git Workflow (Multi-Environment)

When using the HCP Terraform workflow with dev/staging/production environments:

### Branch Strategy
- `dev` → development/sandbox testing
- `staging` → pre-production validation
- `main` → production

### Promotion Flow
1. Make changes in `dev` branch
2. After testing, create PR: `dev` → `staging`
3. After staging validation, create PR: `staging` → `main`

**Branch Protection**: The `.github/workflows/branch-promotion-check.yml` workflow enforces:
- PRs to `staging` must come from `dev`
- PRs to `main` must come from `staging`

### Keeping Environments Synchronized
After production deployment, sync lower environments:
```bash
git checkout dev
git merge main
git push origin dev

git checkout staging
git merge main
git push origin staging
```

## Provider Versions

- **jamfpro**: `0.30.0` (deploymenttheory/jamfpro)
- **jamfplatform**: `>= 0.2.0` (Jamf-Concepts/jamfplatform)
- **Terraform**: `>= 1.14.1`

If not using Jamf Platform features (Blueprints, Compliance Benchmarks):
1. Comment out `jamfplatform` provider block in `provider.tf`
2. Comment out `blueprints` and `compliance_benchmarks` modules in `main.tf`

## Module-Specific Notes

### packages Module
- Package files are uploaded from `support-files/` directory
- Use `for_each` with local list of filenames

### mobile-device-apps Module  
- Automatically fetches app metadata from App Store
- Downloads app icons for Self Service
- Requires VPP token for licensed apps

### settings Module
- Contains token validation logic for ADE and VPP tokens
- Exports foundational IDs used by all other modules
- Includes 2-minute delay after VPP location creation to allow license sync

## Security Notes

- `terraform.tfvars` is gitignored (contains sensitive credentials)
- Never commit API credentials or tokens to version control
- Mark all sensitive variables as `sensitive = true` in HCP Terraform
- Use separate API credentials per environment (dev/staging/production)

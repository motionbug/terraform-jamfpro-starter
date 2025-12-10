terraform {
  required_version = ">= 1.14.1"
  required_providers {
    jamfpro = {
      source  = "deploymenttheory/jamfpro"
      version = "0.30.0"
    }
  }
}

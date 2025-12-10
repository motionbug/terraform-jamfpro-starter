terraform {
  required_version = ">= 1.14.1"
  required_providers {
    jamfpro = {
      source  = "deploymenttheory/jamfpro"
      version = "0.30.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13.1"
    }
  }
}

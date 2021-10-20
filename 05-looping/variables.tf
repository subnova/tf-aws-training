variable "owner" {
  description = "The initials of the person provisioning the infrastructure"
  type        = string

  validation {
     condition     = can(regex("^[a-z]{2,3}$", var.owner))
     error_message = "The owner value must consist of 2-3 lower-case ascii characters."
  }
}

variable "vpc_cidr" {
  description = "The CIDR block to use for the VPC. Must be at least a /20."
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}.\\d{1,3}.\\d{1,3}.\\d{1,3}/\\d{1,2}$", var.vpc_cidr))
    error_message = "Must be a valid CIDR."
  }
}

variable "region" {
  description = "The AWS region to provision the resources in"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-\\w+-\\d$", var.region))
    error_message = "The AWS region is not legal."
  }
}

variable "include_db" {
  description = "Whether or not to provision database subnets"
  type        = bool
}

variable "az_count" {
  description = "The number of AZ's to provision: between 1 and 3"
  type        = number

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "The AZ count must be between 1 and 3."
  }
}
variable "owner" {
  description = "The initials of the person provisioning the infrastructure"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2,3}$", var.owner))
    error_message = "The owner value must consist of 2-3 lower-case ascii characters."
  }
}
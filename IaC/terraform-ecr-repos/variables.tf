
# No defaults on purpose - anyone reusing this repo sets their own values
# in terraform.tfvars (gitignored) instead of inheriting ours.
variable "owner" {
  type        = string
  description = "Owner tag applied to every resource (team or handle responsible for it)."
}

variable "repository" {
  type        = string
  description = "Repo tag applied to every resource - where this infra is defined (owner/repo)."
}


variable "repository_prefix" {
  type        = string
  description = "Prefix for the ECR repository names, e.g. '<prefix>-frontend' / '<prefix>-backend'."
  default     = "calc-app"
}

variable "max_image_count" {
  type        = number
  description = "Number of most-recent images to retain per repository before older ones expire."
  default     = 10
}

variable "force_delete" {
  type        = bool
  description = "Allow `terraform destroy` to delete these repositories even if they still contain images. Safe here since this module lives in its own persistent state, applied/destroyed independently of the ephemeral cluster stack."
  default     = true
}

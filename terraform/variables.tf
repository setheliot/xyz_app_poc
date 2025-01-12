# Define environment stage name
variable "env_name" {
  description = "Environment name - used in naming. stage, prod or use a custom name"
  type        = string
}

# Terraform workspace to use
variable "workspace" {
  description = "Terraform workspace - usually matches a GitHub branch name"
  type        = string
}

# Define a variable for the image.
variable "app_image" {
  description = "App Image"
  type        = string
  default     = "ghcr.io/setheliot/xyz-demo-app:latest"
}

# Use LBC - can set this to false for legacy behavior
variable "use_lbc" {
  description = "When true, uses LBC to create ALB. When false a legacy NLB is created"
  type        = bool
  default     = true
}
# Define environment stage name
variable "env_name" {
  description = "unknown"
  type        = string
}

# Define a variable for the image.
variable "app_image" {
  description = "App Image"
  type        = string
  default = "setheliot/xyz-demo-app:latest"
}
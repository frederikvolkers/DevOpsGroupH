variable "server_username" {
  description = "Server administrator login"
  type        = string
  sensitive   = true
}

variable "server_password" {
  description = "Server administrator password"
  type        = string
  sensitive   = true
}

variable "webhook_serviceuri" {
  description = "Webhook serviceuri"
  type        = string
  sensitive   = true
}

variable "server_conn" {
  description = "Server Connection String"
  type        = string
  sensitive   = true
}

variable "storage_accesskey" {
  description = "Storage Access Key"
  type        = string
  sensitive   = true
}
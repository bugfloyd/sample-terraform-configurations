variable "db_user" {
  description = "Database master user"
  type = string
  default = "postgres"
}

variable "private_subnet_id_az1" {
  description = "ID of the private subnet in AZ1"
  type        = string
}

variable "private_subnet_id_az2" {
  description = "ID of the private subnet in AZ2"
  type        = string
}

variable "vpc_id" {
  description = "ID of theVPC"
  type        = string
}

variable "app_lambda_security_group" {
  description = "Security group of the application instance"
  type        = string
}

variable "app_lambda_execution_role_name" {
  description = "Name of the execution IAM role of application instance"
  type        = string
}
variable "aws_region" {
  description = "AWS region for the monitoring host"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type (Free Tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into the host (no open default)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password (never commit a value)"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "aws_region" {
  type = string
}

variable "vpc_block" {
  type        = string
  description = "The VPC CIDR range"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

variable "secondary_cidrs" {
  type        = list(string)
  description = "List of Additional CIDRs To Associate with VPC"
  default     = []

  validation {
    condition     = length(var.secondary_cidrs) < 5
    error_message = "An AWS VPC can have a maximum of 5 total CIDRs associated."
  }
}

variable "env" {
  type = string
}

variable "team" {
  type = string
}

variable "product" {
  type    = string
  default = "databricks"
}
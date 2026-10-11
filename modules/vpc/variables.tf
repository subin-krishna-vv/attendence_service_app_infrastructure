variable "name_prefix" {
  description = "Prefix for resource Name tags: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be lowercase alphanumeric with hyphens."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Must be a /16 that does not overlap any other environment or region (see README CIDR plan)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16") && cidrhost(var.vpc_cidr, 0) == split("/", var.vpc_cidr)[0]
    error_message = "vpc_cidr must be a valid network address with a /16 prefix, e.g. 10.10.0.0/16."
  }
}

variable "enable_nat_gateway" {
  description = "Create the regional NAT gateway and the private subnets' default route through it."
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Create the S3 gateway endpoint on the private route table."
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Create the DynamoDB gateway endpoint on the private route table."
  type        = bool
  default     = true
}

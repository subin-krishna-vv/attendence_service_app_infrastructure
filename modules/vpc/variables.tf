variable "name_prefix" {
  description = "Prefix for resource Name tags: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Must be a /16 that does not overlap any other environment or region (see README CIDR plan)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16") && cidrhost(var.vpc_cidr, 0) == split("/", var.vpc_cidr)[0]
    error_message = "vpc_cidr must be a /16 network address."
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

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ in AZ name order (first goes in AZ a)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ in AZ name order (first goes in AZ a)."
  type        = list(string)
}

variable "enable_dns_support" {
  description = "Enable the Amazon-provided DNS resolver in the VPC (needed for gateway endpoints and private DNS)."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Give instances and ENIs public/private DNS hostnames."
  type        = bool
  default     = true
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign public IPv4 addresses to ENIs launched in the subnets. Keep false: the ALB and NAT do not need it."
  type        = bool
  default     = false
}

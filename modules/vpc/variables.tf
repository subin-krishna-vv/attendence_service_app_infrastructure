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

variable "az_count" {
  description = "Number of Availability Zones (first N standard AZs by name); one public and one private subnet per AZ."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6 && floor(var.az_count) == var.az_count
    error_message = "az_count must be a whole number between 2 and 6."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet (4 on a /16 gives /20 subnets)."
  type        = number
  default     = 4

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 12 && floor(var.subnet_newbits) == var.subnet_newbits
    error_message = "subnet_newbits must be a whole number between 1 and 12."
  }
}

variable "public_subnet_offset" {
  description = "cidrsubnet index of the first public subnet; public subnets take az_count consecutive indexes from here."
  type        = number
  default     = 0

  validation {
    condition     = var.public_subnet_offset >= 0 && floor(var.public_subnet_offset) == var.public_subnet_offset
    error_message = "public_subnet_offset must be a non-negative whole number."
  }
}

variable "private_subnet_offset" {
  description = "cidrsubnet index of the first private subnet; private subnets take az_count consecutive indexes from here."
  type        = number
  default     = 8

  validation {
    condition     = var.private_subnet_offset >= 0 && floor(var.private_subnet_offset) == var.private_subnet_offset
    error_message = "private_subnet_offset must be a non-negative whole number."
  }

  validation {
    condition     = var.private_subnet_offset >= var.public_subnet_offset + var.az_count || var.public_subnet_offset >= var.private_subnet_offset + var.az_count
    error_message = "Public and private subnet index ranges must not overlap."
  }

  validation {
    condition     = max(var.public_subnet_offset, var.private_subnet_offset) + var.az_count <= pow(2, var.subnet_newbits)
    error_message = "Subnet indexes exceed the VPC CIDR: offset + az_count must be <= 2^subnet_newbits."
  }
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

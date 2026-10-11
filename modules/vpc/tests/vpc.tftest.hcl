mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1d", "us-east-1a", "us-east-1f", "us-east-1c", "us-east-1b", "us-east-1e"]
    }
  }
}

variables {
  name_prefix = "attendance-service-dev-use1"
  vpc_cidr    = "10.10.0.0/16"
}

run "uses_first_three_azs_by_name" {
  command = plan

  assert {
    condition     = output.azs == tolist(["us-east-1a", "us-east-1b", "us-east-1c"])
    error_message = "Must use the first 3 Availability Zones sorted by name."
  }
}

run "public_subnets_are_first_three_slash_20s" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "Expected exactly 3 public subnets."
  }

  assert {
    condition = (
      aws_subnet.public["us-east-1a"].cidr_block == "10.10.0.0/20" &&
      aws_subnet.public["us-east-1b"].cidr_block == "10.10.16.0/20" &&
      aws_subnet.public["us-east-1c"].cidr_block == "10.10.32.0/20"
    )
    error_message = "Public subnets must be 10.10.0.0/20, 10.10.16.0/20, 10.10.32.0/20 in AZ a, b, c."
  }
}

run "private_subnets_start_at_upper_half" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected exactly 3 private subnets."
  }

  assert {
    condition = (
      aws_subnet.private["us-east-1a"].cidr_block == "10.10.128.0/20" &&
      aws_subnet.private["us-east-1b"].cidr_block == "10.10.144.0/20" &&
      aws_subnet.private["us-east-1c"].cidr_block == "10.10.160.0/20"
    )
    error_message = "Private subnets must be 10.10.128.0/20, 10.10.144.0/20, 10.10.160.0/20 in AZ a, b, c."
  }
}

run "same_offsets_in_second_region" {
  command = plan

  variables {
    name_prefix = "attendance-service-dev-use2"
    vpc_cidr    = "10.11.0.0/16"
  }

  assert {
    condition     = aws_subnet.public["us-east-1a"].cidr_block == "10.11.0.0/20" && aws_subnet.private["us-east-1a"].cidr_block == "10.11.128.0/20"
    error_message = "Subnet offsets must be the same in every /16."
  }
}

run "no_subnet_assigns_public_ips" {
  command = plan

  assert {
    condition = alltrue(concat(
      [for s in aws_subnet.public : s.map_public_ip_on_launch == false],
      [for s in aws_subnet.private : s.map_public_ip_on_launch == false],
    ))
    error_message = "No subnet may auto-assign public IPs."
  }
}

run "public_route_to_internet_gateway" {
  command = plan

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route table must have a default route."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 3 && length(aws_route_table_association.private) == 3
    error_message = "Every subnet must be associated with its tier's route table."
  }
}

run "regional_nat_gateway_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Expected exactly one NAT gateway."
  }

  assert {
    condition     = aws_nat_gateway.this[0].availability_mode == "regional" && aws_nat_gateway.this[0].connectivity_type == "public"
    error_message = "NAT gateway must be a public regional NAT gateway."
  }

  assert {
    condition     = length(aws_route.private_nat) == 1 && aws_route.private_nat[0].destination_cidr_block == "0.0.0.0/0"
    error_message = "Private route table must have a default route through the NAT gateway."
  }
}

run "nat_gateway_off" {
  command = plan

  variables {
    enable_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_route.private_nat) == 0
    error_message = "No NAT gateway or private default route when enable_nat_gateway is false."
  }

  assert {
    condition     = output.nat_gateway_id == null
    error_message = "nat_gateway_id must be null when the NAT gateway is disabled."
  }
}

run "default_security_group_has_no_rules" {
  command = plan

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "The default security group must have no rules."
  }
}

run "rejects_non_slash_16" {
  command = plan

  variables {
    vpc_cidr = "10.10.0.0/20"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_host_address_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.10.5.0/16"
  }

  expect_failures = [var.vpc_cidr]
}

run "fails_with_fewer_azs_than_az_count" {
  command = plan

  override_data {
    target = data.aws_availability_zones.this
    values = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  expect_failures = [aws_vpc.this]
}

run "gateway_endpoints_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 1 && aws_vpc_endpoint.s3[0].service_name == "com.amazonaws.us-east-1.s3"
    error_message = "Expected one S3 endpoint for the current region."
  }

  assert {
    condition     = length(aws_vpc_endpoint.dynamodb) == 1 && aws_vpc_endpoint.dynamodb[0].service_name == "com.amazonaws.us-east-1.dynamodb"
    error_message = "Expected one DynamoDB endpoint for the current region."
  }

  assert {
    condition     = aws_vpc_endpoint.s3[0].vpc_endpoint_type == "Gateway" && aws_vpc_endpoint.dynamodb[0].vpc_endpoint_type == "Gateway"
    error_message = "S3 and DynamoDB endpoints must be gateway endpoints."
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3[0].route_table_ids) == 1 && length(aws_vpc_endpoint.dynamodb[0].route_table_ids) == 1
    error_message = "Gateway endpoints must be attached to the private route table only."
  }
}

run "s3_endpoint_off" {
  command = plan

  variables {
    enable_s3_endpoint = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 0 && output.s3_endpoint_id == null
    error_message = "No S3 endpoint when enable_s3_endpoint is false."
  }

  assert {
    condition     = length(aws_vpc_endpoint.dynamodb) == 1
    error_message = "Disabling S3 must not affect the DynamoDB endpoint."
  }
}

run "dynamodb_endpoint_off" {
  command = plan

  variables {
    enable_dynamodb_endpoint = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.dynamodb) == 0 && output.dynamodb_endpoint_id == null
    error_message = "No DynamoDB endpoint when enable_dynamodb_endpoint is false."
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 1
    error_message = "Disabling DynamoDB must not affect the S3 endpoint."
  }
}

run "overrides_az_count_and_layout" {
  command = plan

  variables {
    az_count              = 2
    subnet_newbits        = 8
    public_subnet_offset  = 0
    private_subnet_offset = 100
  }

  assert {
    condition     = output.azs == tolist(["us-east-1a", "us-east-1b"])
    error_message = "az_count must control how many AZs are used."
  }

  assert {
    condition = (
      aws_subnet.public["us-east-1b"].cidr_block == "10.10.1.0/24" &&
      aws_subnet.private["us-east-1a"].cidr_block == "10.10.100.0/24"
    )
    error_message = "subnet_newbits and offsets must control subnet CIDRs."
  }
}

run "rejects_overlapping_subnet_ranges" {
  command = plan

  variables {
    public_subnet_offset  = 0
    private_subnet_offset = 2
  }

  expect_failures = [var.private_subnet_offset]
}

run "rejects_subnets_beyond_vpc" {
  command = plan

  variables {
    private_subnet_offset = 14
  }

  expect_failures = [var.private_subnet_offset]
}

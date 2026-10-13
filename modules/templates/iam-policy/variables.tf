variable "name" {
  description = "Full policy name, e.g. attendance-service-dev-use1-dax-dynamodb."
  type        = string
}

variable "description" {
  description = "What the policy grants and why."
  type        = string
}

variable "policy_json" {
  description = "IAM policy document as JSON (e.g. from data.aws_iam_policy_document.*.json or jsonencode)."
  type        = string
}

variable "path" {
  description = "IAM path for the policy."
  type        = string
  default     = "/"
}

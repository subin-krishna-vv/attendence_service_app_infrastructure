mock_provider "aws" {}

variables {
  name        = "attendance-service-dev-use1-test"
  description = "Test policy"
  policy_json = <<-EOT
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "dynamodb:GetItem",
          "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/example"
        }
      ]
    }
  EOT
}

run "creates_policy_from_document" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.name == "attendance-service-dev-use1-test"
    error_message = "Policy name must be passed through unchanged."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.this.policy).Statement[0].Action == "dynamodb:GetItem"
    error_message = "Policy document must be passed through unchanged."
  }
}

run "rejects_invalid_json" {
  command = plan

  variables {
    policy_json = "not json"
  }

  expect_failures = [var.policy_json]
}

run "rejects_empty_description" {
  command = plan

  variables {
    description = " "
  }

  expect_failures = [var.description]
}

run "overrides_path" {
  command = plan

  variables {
    path = "/attendance-service/"
  }

  assert {
    condition     = aws_iam_policy.this.path == "/attendance-service/"
    error_message = "path must follow the variable."
  }
}

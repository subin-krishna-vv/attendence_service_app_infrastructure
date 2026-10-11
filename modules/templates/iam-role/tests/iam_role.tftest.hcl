mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  name             = "attendance-service-dev-use1-ecs-task"
  description      = "Test role"
  trusted_services = ["ecs-tasks.amazonaws.com"]
}

run "trust_policy_allows_only_listed_service_from_own_account" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Service == ["ecs-tasks.amazonaws.com"]
    error_message = "Trust policy must allow exactly the listed service principals."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "Trust policy must only allow sts:AssumeRole."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "123456789012"
    error_message = "Trust policy must restrict aws:SourceAccount to the caller's account by default."
  }
}

run "source_account_condition_off" {
  command = plan

  variables {
    enable_source_account_condition = false
  }

  assert {
    condition     = !contains(keys(jsondecode(aws_iam_role.this.assume_role_policy).Statement[0]), "Condition")
    error_message = "Trust policy must have no Condition when the toggle is off."
  }
}

run "no_attachments_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No policies may be attached unless policy_arns is set."
  }
}

run "one_attachment_per_policy" {
  command = plan

  variables {
    policy_arns = {
      logs     = "arn:aws:iam::123456789012:policy/logs"
      dynamodb = "arn:aws:iam::123456789012:policy/dynamodb"
    }
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 2
    error_message = "Expected one attachment per entry in policy_arns."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.this["dynamodb"].policy_arn == "arn:aws:iam::123456789012:policy/dynamodb"
    error_message = "Attachment must use the policy ARN for its key."
  }
}

run "rejects_empty_trusted_services" {
  command = plan

  variables {
    trusted_services = []
  }

  expect_failures = [var.trusted_services]
}

run "rejects_non_service_principal" {
  command = plan

  variables {
    trusted_services = ["arn:aws:iam::123456789012:root"]
  }

  expect_failures = [var.trusted_services]
}

run "defaults_path_and_session_duration" {
  command = plan

  assert {
    condition     = aws_iam_role.this.path == "/" && aws_iam_role.this.max_session_duration == 3600
    error_message = "Defaults must be path / and a 3600 s session."
  }
}

run "overrides_path_and_session_duration" {
  command = plan

  variables {
    path                 = "/attendance-service/"
    max_session_duration = 7200
  }

  assert {
    condition     = aws_iam_role.this.path == "/attendance-service/" && aws_iam_role.this.max_session_duration == 7200
    error_message = "path and max_session_duration must follow the variables."
  }
}

run "rejects_invalid_path" {
  command = plan

  variables {
    path = "attendance-service"
  }

  expect_failures = [var.path]
}

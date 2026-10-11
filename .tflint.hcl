# Shared tflint config. Run from any stack or module directory:
#   tflint --init --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
#   tflint --config="$(git rev-parse --show-toplevel)/.tflint.hcl"

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# envs/dev/global

Global (non-regional) resources for the **dev** environment. Apply this stack **before** the regional stacks.

| Module | Creates |
| --- | --- |
| `dns_zone` (`modules/route53-zone`) | Public hosted zone `dev.attendance.<base_domain>` |

The DynamoDB global table will be added here later.

## State

S3 backend `attendance-service-dev-tfstate-abc`, key `global/terraform.tfstate`, native locking. Run [bootstrap/dev](../../../bootstrap/dev/README.md) first.

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `base_domain` | — (required) | e.g. `example.com` |
| `project` / `env` / `owner` | `attendance-service` / `dev` / `devops-team` | Tags and naming |
| `region` | `us-east-1` | Provider region |

Set `base_domain` in a local `terraform.tfvars`, which is gitignored. Copy it from `terraform.tfvars.example`.

## Usage

```sh
export AWS_PROFILE=<your-profile>
cd envs/dev/global
cp terraform.tfvars.example terraform.tfvars   # then set base_domain
terraform init
terraform plan
terraform apply
terraform output name_servers
```

## Manual step: delegate the subdomain

At the DNS provider for `<base_domain>`, create an **NS record** for `dev.attendance` whose values are the 4 name servers from `terraform output name_servers`. Until this is done:

- `dig NS dev.attendance.<base_domain>` will not return the Route 53 name servers;
- ACM certificates for the regional stacks will stay in *Pending validation*.

## Outputs

| Name | Description |
| --- | --- |
| `zone_id` | Hosted zone ID, used by the regional stacks (ACM validation) |
| `zone_name` | `dev.attendance.<base_domain>` |
| `name_servers` | NS values for the delegation |

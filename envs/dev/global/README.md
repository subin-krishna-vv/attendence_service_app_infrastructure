# envs/dev/global

Global (non-regional) resources for the **dev** environment. Apply this stack **before** the regional stacks.

| Module | Creates |
| --- | --- |
| `dns_zone` (`modules/route53-zone`) | Public hosted zone `dev.attendance.<base_domain>` |

The DynamoDB global table will be added here later.

## State

S3 backend `attendance-service-dev-tfstate-abc`, key `global/terraform.tfstate`, native locking. Run [bootstrap/dev](../../../bootstrap/dev/README.md) first.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project` | string | `"attendance-service"` | Project name, used for the `project` tag. |
| `env` | string | `"dev"` | Environment name, used in the domain name and the `env` tag. |
| `owner` | string | `"devops-team"` | Owning team, used for the `owner` tag. |
| `region` | string | `"us-east-1"` | Provider region for global resources. |
| `base_domain` | string | `null` | Base domain the service lives under, e.g. example.com. The env zone is <env>.<service_subdomain>.<base_domain>. Required when enable_dns_zone is true. |
| `enable_dns_zone` | bool | `true` | Create the env's public hosted zone. When false, the regional stacks must set enable_certificate = false and global-dns must set enable_dns_records = false. |
| `service_subdomain` | string | `"attendance"` | Subdomain label of the service under base_domain. The env zone is <env>.<service_subdomain>.<base_domain>. |
| `zone_comment` | string | `null` | Hosted zone comment; null uses the module default. |
| `zone_force_destroy` | bool | `false` | Delete all records when the zone is destroyed. Keep false. |

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

## Toggle

`enable_dns_zone` (default `true`). When it's `false`, no hosted zone is created, `base_domain` becomes optional and the outputs are `null`. The regional stacks then need `enable_certificate = false`, and `global-dns` needs `enable_dns_records = false`, because both depend on the zone.

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

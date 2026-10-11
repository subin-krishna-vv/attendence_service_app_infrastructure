# route53-zone

Creates one **public Route 53 hosted zone**. Each environment gets its own zone for its subdomain (e.g. `dev.attendance.<base_domain>`), which is delegated from the base domain's DNS provider with NS records.

## Resources

- `aws_route53_zone.this`: public zone, `force_destroy = false`

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `domain_name` | string | — | Lowercase FQDN without a trailing dot |

## Outputs

| Name | Description |
| --- | --- |
| `zone_id` | Hosted zone ID |
| `name` | Zone domain name |
| `name_servers` | The 4 name servers to add as NS records at the parent domain |

## Toggles

None.

## Example

```hcl
module "dns_zone" {
  source      = "../../../modules/route53-zone"
  domain_name = "dev.attendance.example.com"
}
```

## Design notes

- **Per-environment subdomain zones.** Your existing DNS for the base domain is untouched; only an NS delegation for the subdomain is added there. Each environment's zone lives in that environment's state.
- **`force_destroy = false`.** Terraform won't delete a zone that still holds records it doesn't manage.
- **No DNSSEC (CKV2_AWS_38).** It would need a KMS key in us-east-1 and a DS record at the parent DNS provider.
- **No query logging (CKV2_AWS_39).** It would need a CloudWatch log group in us-east-1.
- Cost: $0.50/month per hosted zone, plus $0.40 per million standard queries. Nothing is billed hourly.

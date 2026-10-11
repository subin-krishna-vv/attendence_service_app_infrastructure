# acm-certificate

Creates a **DNS-validated public ACM certificate** for an environment's domain, plus its wildcard, in the provider's region. Each regional stack calls it once, because an ALB can only use a certificate from its own region.

## Resources

| Resource | Purpose |
| --- | --- |
| `data.aws_route53_zone.this` | Looks up the existing public zone by name |
| `aws_acm_certificate.this` | `domain_name` + `*.domain_name` SAN, DNS validation, RSA 2048, `create_before_destroy` |
| `aws_route53_record.validation` | One validation CNAME per certificate name, TTL 60, `allow_overwrite = true` |
| `aws_acm_certificate_validation.this` | Waits until ACM issues the certificate |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `domain_name` | string | — | e.g. `dev.attendance.example.com`; must be `zone_name` or inside it |
| `zone_name` | string | — | Existing public hosted zone, e.g. `dev.attendance.example.com` |
| `enable_wildcard` | bool | `true` | Add `*.<domain_name>` as a SAN |

## Outputs

| Name | Description |
| --- | --- |
| `certificate_arn` | ARN of the **validated** certificate, used by the ALB HTTPS listener |
| `domain_name` | Primary domain name |
| `zone_id` | Hosted zone ID, reused for the latency alias records |

## Toggles

| Toggle | Default | Effect when `false` |
| --- | --- | --- |
| `enable_wildcard` | `true` | The certificate covers only `domain_name` |

## Example

```hcl
module "certificate" {
  source      = "../../../modules/acm-certificate"
  domain_name = "dev.attendance.${var.base_domain}"
  zone_name   = "dev.attendance.${var.base_domain}"
}
```

## Design notes

- **One validation record, written by several resources.** The apex and the wildcard validate with the *same* CNAME, and so does the other region's certificate for the same names. `allow_overwrite = true` lets each resource manage that shared record without conflicting (this is the AWS provider's documented pattern).
  - **Caveat:** destroying one region's certificate deletes that shared CNAME, which the other region's certificate also uses for renewal. Re-applying the remaining region re-creates it.
- **Zone lookup by name.** Regional stacks pass the zone name; they don't read the global stack's state or need a copied zone ID. The zone must exist first, so apply `envs/<env>/global` before the regional stacks.
- **Apply waits for validation.** If the NS delegation for the zone isn't in place, `aws_acm_certificate_validation` waits until it times out (75 minutes by default).
- **Renewal is automatic.** ACM renews DNS-validated certificates as long as the validation CNAME stays in the zone.
- `create_before_destroy` lets a replacement certificate (for example after changing SANs) be issued and attached before the old one is deleted.
- Cost: public ACM certificates are free.

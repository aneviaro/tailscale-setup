# Tailscale Setup Review

Review date: 2026-06-10

This document is safe for a public repository. Live tailnet identifiers, device names, personal email addresses, and Tailscale IPs are intentionally omitted. Use ignored local exports under `exports/current/` for detailed operational review.

## Current State Summary

- Tailnet policy was exported locally and should remain in ignored local files unless sanitized.
- The live tailnet includes a small mixed fleet of user devices and tagged infrastructure.
- A dedicated tagged DNS node is configured as the global resolver.
- No subnet routes were advertised or enabled at review time.
- Several authorized devices appeared stale or past their key expiry timestamp.
- MagicDNS, HTTPS certificates, network flow logging, device approval, posture identity collection, and externally managed ACLs were disabled at review time.

## Findings

### High: All devices can use any exit node

The live policy included a broad rule allowing `*` to reach `autogroup:internet:*`. This overrides any narrower intended exit-node rule. Restrict exit-node access to a dedicated tag such as `tag:exit-client` or a specific group.

### High: Stale DNS exception was overly broad

The live policy included a temporary grant from a broad device tag to the DNS tag with `ip: ["*"]`. Replace this with explicit DNS-only access on port `53` plus separate admin access if needed.

### Medium: Tailscale SSH allowed root on self devices

The live SSH policy allowed members to SSH into their own devices as `root`. Prefer `autogroup:nonroot` for self-device access and reserve root for explicit admin-to-infrastructure rules.

### Medium: Policy had no tests

Add `tests` and `sshTests` before making Terraform the source of truth. Tests should prove expected allows and denies for:

- client-to-client access
- DNS access on port 53 only
- server service ports
- exit-node access only for the intended tag or group
- root SSH only for admins

### Medium: Device tags were coarse

A broad personal-device tag covered laptops, phones, and service hosts. Split tags by role:

- `tag:client`
- `tag:server`
- `tag:storage`
- `tag:dns`
- `tag:exit-client`
- `tag:work`

### Low: Tailnet settings are useful but not hardened

Recommended changes after import and a clean no-op plan:

- enable `acls_externally_managed_on`
- set `acls_external_link` to the private repository or policy workflow
- enable `https_enabled`
- enable `network_flow_logging_on`
- consider enabling `devices_approval_on`
- consider a shorter key duration for user devices
- keep key expiry disabled only for stable tagged infrastructure

### Low: MagicDNS was disabled

This is valid if a dedicated DNS server intentionally handles naming. Otherwise, enabling MagicDNS improves ergonomics and reduces raw IP dependence.

## Proposed ACL Direction

The tracked template in `terraform/policy.hujson` is sanitized and grants-first:

- clients can reach clients
- all devices can reach DNS on port 53 only
- members can reach routine service ports
- exit-node access is opt-in by tag
- admins have explicit infrastructure access
- root SSH is limited to admins
- tests cover important allow and deny paths

For live management, set `policy_file = "../exports/current/acl.hujson"` or another ignored local policy path in `terraform/terraform.tfvars`.

## IaC Coverage

Already scaffolded:

- full policy file: `tailscale_acl.policy`
- tailnet settings: `tailscale_tailnet_settings.this`
- MagicDNS: `tailscale_dns_preferences.this`
- global DNS: `tailscale_dns_nameservers.global`
- DNS search paths: `tailscale_dns_search_paths.this`
- split DNS: `tailscale_dns_split_nameservers.by_domain`
- device tags: `tailscale_device_tags.by_name`
- subnet routes: `tailscale_device_subnet_routes.by_name`
- webhooks: `tailscale_webhook.this`

Not covered:

- OAuth client creation and secret handling
- local node runtime commands such as `tailscale up --advertise-routes`
- alerting destination implementation outside Tailscale

## Adoption Sequence

1. Keep live exports and real tfvars ignored.
2. Import current resources into state.
3. Run a no-op plan against the ignored current policy and local tfvars.
4. Add tests while preserving current behavior.
5. Apply hardening changes in separate reviewed commits.
6. Enable externally managed ACLs after Terraform is stable.

## References

- Tailscale policy file syntax: https://tailscale.com/docs/reference/syntax/policy-file
- Tailscale grants: https://tailscale.com/docs/reference/syntax/grants
- Tailscale Terraform provider: https://github.com/tailscale/terraform-provider-tailscale


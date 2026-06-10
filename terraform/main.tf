resource "tailscale_acl" "policy" {
  acl = file(var.policy_file)

  overwrite_existing_content = var.overwrite_existing_policy
  reset_acl_on_destroy       = false
}

resource "tailscale_tailnet_settings" "this" {
  acls_externally_managed_on                  = var.acls_externally_managed_on
  acls_external_link                          = var.acls_external_link
  devices_approval_on                         = var.devices_approval_on
  devices_auto_updates_on                     = var.devices_auto_updates_on
  devices_key_duration_days                   = var.devices_key_duration_days
  https_enabled                               = var.https_enabled
  network_flow_logging_on                     = var.network_flow_logging_on
  posture_identity_collection_on              = var.posture_identity_collection_on
  regional_routing_on                         = var.regional_routing_on
  users_approval_on                           = var.users_approval_on
  users_role_allowed_to_join_external_tailnet = var.users_role_allowed_to_join_external_tailnet
}

resource "tailscale_dns_preferences" "this" {
  magic_dns = var.magic_dns
}

resource "tailscale_dns_nameservers" "global" {
  count = length(var.global_nameservers) > 0 ? 1 : 0

  nameservers = var.global_nameservers
}

resource "tailscale_dns_search_paths" "this" {
  count = length(var.search_paths) > 0 ? 1 : 0

  search_paths = var.search_paths
}

resource "tailscale_dns_split_nameservers" "by_domain" {
  for_each = var.split_nameservers

  domain      = each.key
  nameservers = each.value
}

data "tailscale_device" "tagged" {
  for_each = var.device_tags

  name = each.key
}

resource "tailscale_device_tags" "by_name" {
  for_each = var.device_tags

  device_id = data.tailscale_device.tagged[each.key].node_id
  tags      = each.value
}

data "tailscale_device" "subnet_router" {
  for_each = var.device_subnet_routes

  name = each.key
}

resource "tailscale_device_subnet_routes" "by_name" {
  for_each = var.device_subnet_routes

  device_id = data.tailscale_device.subnet_router[each.key].node_id
  routes    = each.value
}

resource "tailscale_webhook" "this" {
  for_each = var.webhooks

  endpoint_url  = each.value.endpoint_url
  provider_type = each.value.provider_type
  subscriptions = each.value.subscriptions
}

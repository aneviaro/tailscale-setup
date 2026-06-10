variable "overwrite_existing_policy" {
  description = "Set true only for the first controlled apply if the live policy was not imported."
  type        = bool
  default     = false
}

variable "policy_file" {
  description = "Path to the Tailscale policy file. Use an ignored local export for live tailnets."
  type        = string
  default     = "policy.hujson"
}

variable "acls_externally_managed_on" {
  description = "Prevents admin-console policy edits once Terraform owns the policy."
  type        = bool
  default     = false
}

variable "acls_external_link" {
  description = "URL to this repository or policy management workflow."
  type        = string
  default     = null
}

variable "devices_approval_on" {
  type    = bool
  default = true
}

variable "devices_auto_updates_on" {
  type    = bool
  default = true
}

variable "devices_key_duration_days" {
  type    = number
  default = 90
}

variable "https_enabled" {
  type    = bool
  default = true
}

variable "network_flow_logging_on" {
  type    = bool
  default = true
}

variable "posture_identity_collection_on" {
  type    = bool
  default = false
}

variable "regional_routing_on" {
  type    = bool
  default = false
}

variable "users_approval_on" {
  type    = bool
  default = false
}

variable "users_role_allowed_to_join_external_tailnet" {
  type    = string
  default = "member"
}

variable "magic_dns" {
  type    = bool
  default = true
}

variable "global_nameservers" {
  description = "Global DNS resolvers. Leave empty to avoid managing this setting."
  type        = list(string)
  default     = []
}

variable "search_paths" {
  type    = list(string)
  default = []
}

variable "split_nameservers" {
  description = "Map of DNS suffix to resolvers, for example { \"corp.example.com\" = [\"100.64.0.10\"] }."
  type        = map(set(string))
  default     = {}
}

variable "device_tags" {
  description = "Map of device FQDN/name to tags."
  type        = map(set(string))
  default     = {}
}

variable "device_subnet_routes" {
  description = "Map of device FQDN/name to enabled routes. Nodes must advertise these routes locally first."
  type        = map(set(string))
  default     = {}
}

variable "webhooks" {
  description = "Webhook destinations keyed by name."
  type = map(object({
    endpoint_url  = string
    provider_type = string
    subscriptions = set(string)
  }))
  default = {}
}

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

ROOT_DIR := $(abspath .)
TF_DIR := $(ROOT_DIR)/terraform
OUT_DIR := $(ROOT_DIR)/exports/current
ENV_FILE := $(ROOT_DIR)/.env.local

.PHONY: help export-current summarize-current write-current-tfvars print-imports import-current tf init plan apply refresh validate fmt fmt-local

help:
	@printf '%s\n' \
		'Targets:' \
		'  make export-current        Export current Tailscale ACL, devices, DNS, and settings' \
		'  make summarize-current     Summarize exported devices' \
		'  make write-current-tfvars  Write ignored terraform/terraform.tfvars from current export' \
		'  make print-imports         Print Terraform import commands from exported devices' \
		'  make import-current        Import current exported resources into Terraform state' \
		'  make init                  Run terraform init with .env.local sourced' \
		'  make plan                  Run terraform plan with .env.local sourced' \
		'  make apply                 Run terraform apply with .env.local sourced' \
		'  make refresh               Refresh Terraform state with .env.local sourced' \
		'  make validate              Run terraform validate with .env.local sourced' \
		'  make fmt                   Format tracked Terraform files only' \
		'  make fmt-local             Format tracked files plus ignored local tfvars' \
		'  make tf ARGS="..."         Run arbitrary Terraform args with .env.local sourced'

export-current:
	@if [[ -f "$(ENV_FILE)" ]]; then set -a; source "$(ENV_FILE)"; set +a; fi; \
	: "$${TAILSCALE_API_KEY:?Set TAILSCALE_API_KEY in .env.local or the environment}"; \
	if [[ -z "$${TAILSCALE_TAILNET:-}" && -n "$${TAILSCALE_TELNET:-}" ]]; then TAILSCALE_TAILNET="$${TAILSCALE_TELNET}"; fi; \
	: "$${TAILSCALE_TAILNET:?Set TAILSCALE_TAILNET in .env.local or the environment}"; \
	mkdir -p "$(OUT_DIR)"; \
	fetch() { \
		local name="$$1"; \
		local path="$$2"; \
		local url="https://api.tailscale.com/api/v2/tailnet/$${TAILSCALE_TAILNET}$${path}"; \
		printf 'Fetching %s\n' "$${name}" >&2; \
		if ! curl --fail --silent --show-error --user "$${TAILSCALE_API_KEY}:" "$${url}" | jq --sort-keys . >"$(OUT_DIR)/$${name}.json"; then \
			printf 'Skipping %s; endpoint was unavailable or the key lacks access.\n' "$${name}" >&2; \
			rm -f "$(OUT_DIR)/$${name}.json"; \
		fi; \
	}; \
	printf 'Fetching acl\n' >&2; \
	if ! curl --fail --silent --show-error --user "$${TAILSCALE_API_KEY}:" "https://api.tailscale.com/api/v2/tailnet/$${TAILSCALE_TAILNET}/acl" >"$(OUT_DIR)/acl.hujson"; then \
		printf 'Skipping acl; endpoint was unavailable or the key lacks access.\n' >&2; \
		rm -f "$(OUT_DIR)/acl.hujson"; \
	fi; \
	fetch devices "/devices"; \
	fetch tailnet-settings "/settings"; \
	fetch dns-preferences "/dns/preferences"; \
	fetch dns-nameservers "/dns/nameservers"; \
	fetch dns-searchpaths "/dns/searchpaths"; \
	printf '\nWrote export files to %s\n' "$(OUT_DIR)" >&2

summarize-current:
	@if [[ ! -d "$(OUT_DIR)" ]]; then printf 'No export directory found. Run make export-current first.\n' >&2; exit 1; fi; \
	if [[ -f "$(OUT_DIR)/devices.json" ]]; then \
		printf 'Device summary\n'; \
		jq -r '.devices // [] | { devices: length, tagged: map(select((.tags // []) | length > 0)) | length, advertisingRoutes: map(select((.advertisedRoutes // []) | length > 0)) | length, approvedRoutes: map(select((.enabledRoutes // []) | length > 0)) | length, expiredKeys: map(select(.keyExpiryDisabled != true and (.expires // "") < (now | todateiso8601))) | length }' "$(OUT_DIR)/devices.json"; \
	fi

write-current-tfvars:
	@if [[ ! -f "$(OUT_DIR)/tailnet-settings.json" || ! -f "$(OUT_DIR)/dns-preferences.json" || ! -f "$(OUT_DIR)/devices.json" ]]; then printf 'Missing export files. Run make export-current first.\n' >&2; exit 1; fi; \
	{ \
		printf 'policy_file = "../exports/current/acl.hujson"\n\n'; \
		jq -r '"acls_external_link = null\n\n" + "devices_approval_on = " + (.devicesApprovalOn | tostring) + "\n" + "devices_auto_updates_on = " + (.devicesAutoUpdatesOn | tostring) + "\n" + "devices_key_duration_days = " + (.devicesKeyDurationDays | tostring) + "\n" + "https_enabled = " + (.httpsEnabled | tostring) + "\n" + "network_flow_logging_on = " + (.networkFlowLoggingOn | tostring) + "\n" + "posture_identity_collection_on = " + (.postureIdentityCollectionOn | tostring) + "\n" + "regional_routing_on = " + (.regionalRoutingOn | tostring) + "\n" + "users_approval_on = " + (.usersApprovalOn | tostring) + "\n" + "users_role_allowed_to_join_external_tailnet = " + (.usersRoleAllowedToJoinExternalTailnets | @json) + "\n"' "$(OUT_DIR)/tailnet-settings.json"; \
		jq -r '"magic_dns = " + (.magicDNS | tostring) + "\n"' "$(OUT_DIR)/dns-preferences.json"; \
		if [[ -f "$(OUT_DIR)/dns-nameservers.json" ]]; then jq -r '"global_nameservers = " + (.dns | @json)' "$(OUT_DIR)/dns-nameservers.json"; else printf 'global_nameservers = []\n'; fi; \
		if [[ -f "$(OUT_DIR)/dns-searchpaths.json" ]]; then jq -r '"search_paths = " + (.searchPaths | @json)' "$(OUT_DIR)/dns-searchpaths.json"; else printf 'search_paths = []\n'; fi; \
		printf '\nsplit_nameservers = {}\n\n'; \
		printf 'device_tags = {\n'; \
		jq -r '.devices[] | select((.tags // []) | length > 0) | "  " + (.name | @json) + " = " + (.tags | @json)' "$(OUT_DIR)/devices.json"; \
		printf '}\n\n'; \
		printf 'device_subnet_routes = {}\nwebhooks = {}\n'; \
	} >"$(TF_DIR)/terraform.tfvars"; \
	printf 'Wrote ignored local file %s\n' "$(TF_DIR)/terraform.tfvars"

print-imports:
	@if [[ ! -f "$(OUT_DIR)/devices.json" ]]; then printf 'No device export found. Run make export-current first.\n' >&2; exit 1; fi; \
	printf '%s\n' \
		'terraform -chdir=terraform import tailscale_acl.policy acl' \
		'terraform -chdir=terraform import tailscale_tailnet_settings.this tailnet_settings' \
		'terraform -chdir=terraform import tailscale_dns_preferences.this dns_preferences' \
		"terraform -chdir=terraform import 'tailscale_dns_nameservers.global[0]' dns_nameservers"; \
	jq -r '.devices[] | select((.tags // []) | length > 0) | "terraform -chdir=terraform import '\''tailscale_device_tags.by_name[\"" + .name + "\"]'\'' " + .nodeId' "$(OUT_DIR)/devices.json"

import-current:
	@if [[ ! -f "$(OUT_DIR)/devices.json" ]]; then printf 'No device export found. Run make export-current first.\n' >&2; exit 1; fi; \
	if [[ -f "$(ENV_FILE)" ]]; then set -a; source "$(ENV_FILE)"; set +a; fi; \
	terraform -chdir="$(TF_DIR)" import tailscale_acl.policy acl; \
	terraform -chdir="$(TF_DIR)" import tailscale_tailnet_settings.this tailnet_settings; \
	terraform -chdir="$(TF_DIR)" import tailscale_dns_preferences.this dns_preferences; \
	terraform -chdir="$(TF_DIR)" import 'tailscale_dns_nameservers.global[0]' dns_nameservers; \
	jq -r '.devices[] | select((.tags // []) | length > 0) | @base64' "$(OUT_DIR)/devices.json" | while read -r row; do \
		name="$$(printf '%s' "$${row}" | base64 --decode | jq -r '.name')"; \
		node_id="$$(printf '%s' "$${row}" | base64 --decode | jq -r '.nodeId')"; \
		address="tailscale_device_tags.by_name[\"$${name}\"]"; \
		terraform -chdir="$(TF_DIR)" import "$${address}" "$${node_id}"; \
	done

tf:
	@if [[ -f "$(ENV_FILE)" ]]; then set -a; source "$(ENV_FILE)"; set +a; fi; \
	terraform -chdir="$(TF_DIR)" $(ARGS)

init:
	@$(MAKE) tf ARGS=init

plan:
	@$(MAKE) tf ARGS=plan

apply:
	@$(MAKE) tf ARGS=apply

refresh:
	@$(MAKE) tf ARGS=refresh

validate:
	@$(MAKE) tf ARGS=validate

fmt:
	@terraform -chdir="$(TF_DIR)" fmt main.tf providers.tf variables.tf versions.tf

fmt-local:
	@terraform fmt -recursive

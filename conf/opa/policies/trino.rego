package trino.authz

# Sample OPA policy for Trino
# This is a permissive example that always allows requests.
# The Trino side should query: /v1/data/trino/authz/allow
# Customize this policy to implement your authorization rules.

# `allow` is a boolean decision. Return true to allow.
# Use a simple default decision that is compatible with the OPA parser.
default allow = true

# Example more advanced rule (commented):
# allow {
#   input.user == "admin"
# }


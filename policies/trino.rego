package trino.authz

default allow_query = false

allow_query if input.context.identity.user == "trino"

allow_query if input.context.identity.user == "admin"

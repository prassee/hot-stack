package trino.authz

default allow_query = false

allow_query if input.context.identity.user == "trino" {
    input.action.operation == "SelectFromColumns"
    input.action.resource.table.catalogName == "hive"
    input.action.resource.table.schemaName == "analytics"
}


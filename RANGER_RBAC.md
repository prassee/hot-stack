# Apache Ranger Integration with Trino - RBAC Setup

## Overview

**UPDATE: Trino 476 HAS Official Apache Ranger Support!**

Apache Ranger provides centralized security administration for Hadoop and related services, including fine-grained authorization for Trino queries. As of Trino 476, there is **official native support** for Apache Ranger.

**Official Documentation**: https://trino.io/docs/476/security/ranger-access-control.html

## Ranger Features in Trino 476

✅ **Officially Supported Features**:
- Policy-based authorization (catalogs, schemas, tables, columns)
- Column masking
- Row filtering
- Audit logging
- Integration with Ranger Admin UI

## Quick Decision Guide

### Choose Apache Ranger If:
- ✅ Enterprise environment with compliance needs
- ✅ Need centralized policy management across multiple systems
- ✅ Require audit trail with UI and reporting
- ✅ Complex column masking and row filtering requirements
- ✅ Large team (50+ users)
- ✅ Integration with existing Ranger deployment

### Choose File-Based RBAC If:
- ✅ Small to medium team (< 20 users)
- ✅ Simple access patterns
- ✅ Development/testing environment
- ✅ Limited infrastructure resources
- ✅ No existing Ranger infrastructure
- ✅ Quick setup needed

## Complete Apache Ranger Setup

For full Apache Ranger integration instructions, see:
**[RANGER_SETUP.md](RANGER_SETUP.md)**

This includes:
1. Docker Compose configuration for Ranger stack
2. Trino plugin configuration
3. Policy creation in Ranger UI
4. Column masking and row filtering examples
5. Audit log configuration
6. Troubleshooting guide

## File-Based RBAC Alternative

If you prefer a simpler approach without external dependencies, continue with the file-based RBAC implementation below.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Trino Query Flow                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Trino with Ranger Plugin                                    │
│  - Intercepts queries                                        │
│  - Calls Ranger for authorization                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Apache Ranger Server                                        │
│  - Policy management                                         │
│  - Audit logging                                             │
│  - User/Group management                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL/MySQL (Ranger DB)                               │
│  - Stores policies                                           │
│  - Audit logs                                                │
└─────────────────────────────────────────────────────────────┘
```

## Components Needed

1. **Apache Ranger Admin** - Policy management UI and API
2. **PostgreSQL/MySQL** - Ranger backend database
3. **Ranger Trino Plugin** - Authorization plugin for Trino
4. **Solr (Optional)** - For audit log indexing

## Setup Steps

### Step 1: Add Ranger Services to docker-compose.yaml

We'll add Ranger Admin and PostgreSQL for Ranger to your existing stack.

### Step 2: Configure Ranger Plugin for Trino

The Ranger plugin needs to be added to Trino's classpath and configured.

### Step 3: Configure Ranger Policies

Define fine-grained access policies for catalogs, schemas, tables, and columns.

## Current State & Options

### Official Apache Ranger Support ✅

**Trino 476 includes native Apache Ranger integration!**

See **[RANGER_SETUP.md](RANGER_SETUP.md)** for complete setup instructions.

### Available Authorization Options:

### Available Authorization Options:

#### Option 1: Apache Ranger (Official - Enterprise)
✅ **Officially supported in Trino 476**
- Native integration with Ranger Admin
- Web UI for policy management
- Column masking and row filtering
- Comprehensive audit logging
- See [RANGER_SETUP.md](RANGER_SETUP.md) for setup

#### Option 2: File-Based Access Control (Recommended for Dev/Small Teams)
This provides similar RBAC functionality without external dependencies.
- Native Trino support
- Fast setup (5 minutes)
- Auto-reload policies
- Good for development and small teams

#### Option 3: Open Policy Agent (OPA) - Modern Alternative
OPA provides policy-based access control with a modern approach.
- Cloud-native design
- Flexible policy language (Rego)
- Good for Kubernetes environments

#### Option 4: Custom Plugin Development
Develop a custom plugin implementing Trino's `SystemAccessControl` interface.

## Implementation: File-Based RBAC (Recommended Alternative)

Since native Ranger integration isn't available, here's a comprehensive RBAC implementation using Trino's built-in capabilities:

### 1. Enable Access Control

Create `/conf/trino/access-control.properties`:
```properties
access-control.name=file
security.config-file=/etc/trino/rules.json
security.refresh-period=5s
```

### 2. Define RBAC Rules

Create `/conf/trino/rules.json`:
```json
{
  "catalogs": [
    {
      "user": "admin",
      "catalog": ".*",
      "allow": "all"
    },
    {
      "group": "data_engineers",
      "catalog": "hive",
      "allow": "all"
    },
    {
      "group": "analysts",
      "catalog": "hive",
      "allow": "read-only"
    },
    {
      "group": "analysts",
      "catalog": "tpch",
      "allow": "read-only"
    },
    {
      "user": "guest",
      "catalog": "tpch",
      "allow": "read-only"
    }
  ],
  "schemas": [
    {
      "user": "admin",
      "catalog": "hive",
      "schema": ".*",
      "owner": true
    },
    {
      "group": "data_engineers",
      "catalog": "hive",
      "schema": "base|managed_db",
      "owner": true
    },
    {
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "owner": false
    }
  ],
  "tables": [
    {
      "user": "admin",
      "catalog": "hive",
      "schema": ".*",
      "table": ".*",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP", "GRANT_SELECT"]
    },
    {
      "group": "data_engineers",
      "catalog": "hive",
      "schema": "base|managed_db",
      "table": ".*",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP"]
    },
    {
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "users|sales|orders",
      "privileges": ["SELECT"]
    },
    {
      "user": "bob",
      "catalog": "hive",
      "schema": "base",
      "table": "products",
      "privileges": ["SELECT", "INSERT"]
    }
  ],
  "columns": [
    {
      "user": "analyst",
      "catalog": "hive",
      "schema": "base",
      "table": "users",
      "columns": ["user_id", "username", "email"],
      "allow": true
    },
    {
      "user": "analyst",
      "catalog": "hive",
      "schema": "base",
      "table": "users",
      "columns": ["password_hash", "ssn"],
      "allow": false
    }
  ],
  "session_properties": [
    {
      "property": ".*",
      "allow": true
    }
  ],
  "system_information": [
    {
      "user": "admin",
      "allow": ["read", "write"]
    },
    {
      "group": "data_engineers",
      "allow": ["read"]
    }
  ]
}
```

### 3. User-Group Mapping

Create `/conf/trino/group-provider.properties`:
```properties
group-provider.name=file
file.group-file=/etc/trino/groups.txt
file.refresh-period=5s
```

Create `/conf/trino/groups.txt`:
```
# Format: user:group1,group2,group3

# Admins
admin:admins,data_engineers

# Data Engineers
alice:data_engineers
bob:data_engineers

# Analysts
analyst:analysts
john:analysts
jane:analysts

# Guests
guest:guests
```

### 4. Update config.properties

Add to `/conf/trino/config.properties`:
```properties
# Access Control
http-server.authentication.type=PASSWORD
access-control.name=file
```

## Comprehensive RBAC Example

Here's a complete example with multiple roles:

### Role Definitions

| Role | Catalogs | Schemas | Tables | Operations |
|------|----------|---------|--------|------------|
| **Admin** | All | All | All | All operations |
| **Data Engineer** | hive | base, managed_db | All | CREATE, READ, UPDATE, DELETE |
| **Analyst** | hive, tpch | base (read-only) | Specific tables | SELECT only |
| **Data Scientist** | hive | base | All except sensitive | SELECT, INSERT (for ML models) |
| **Guest** | tpch | default | sample tables | SELECT only |

### Policy Implementation

```json
{
  "catalogs": [
    {"user": "admin", "catalog": ".*", "allow": "all"},
    {"group": "data_engineers", "catalog": "hive", "allow": "all"},
    {"group": "analysts", "catalog": "hive|tpch", "allow": "read-only"},
    {"group": "data_scientists", "catalog": "hive", "allow": "read-only"},
    {"group": "guests", "catalog": "tpch", "allow": "read-only"}
  ],
  "schemas": [
    {"user": "admin", "catalog": ".*", "schema": ".*", "owner": true},
    {"group": "data_engineers", "catalog": "hive", "schema": "base|managed_db|staging", "owner": true},
    {"group": "analysts", "catalog": "hive", "schema": "base", "owner": false},
    {"group": "data_scientists", "catalog": "hive", "schema": "base|ml_models", "owner": false}
  ],
  "tables": [
    {
      "user": "admin",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP", "GRANT_SELECT"]
    },
    {
      "group": "data_engineers",
      "catalog": "hive",
      "schema": "base|managed_db|staging",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP"]
    },
    {
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "users|sales|orders|customers",
      "privileges": ["SELECT"]
    },
    {
      "group": "data_scientists",
      "catalog": "hive",
      "schema": "base",
      "table": "!.*_sensitive.*",
      "privileges": ["SELECT"]
    },
    {
      "group": "data_scientists",
      "catalog": "hive",
      "schema": "ml_models",
      "privileges": ["SELECT", "INSERT", "UPDATE"]
    }
  ],
  "columns": [
    {
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "users",
      "columns": ["ssn", "salary", "password_hash"],
      "allow": false
    },
    {
      "group": "data_scientists",
      "catalog": "hive",
      "table": ".*_sensitive.*",
      "allow": false
    }
  ],
  "queries": [
    {
      "user": "admin",
      "allow": ["execute", "view", "kill"]
    },
    {
      "group": "data_engineers",
      "allow": ["execute", "view"]
    },
    {
      "group": "analysts",
      "allow": ["execute", "view"]
    }
  ],
  "impersonation": [
    {
      "original_user": "admin",
      "new_user": ".*",
      "allow": true
    },
    {
      "original_user": "etl_service",
      "new_user": "data_.*",
      "allow": true
    }
  ]
}
```

## Advanced Features

### Row-Level Security (RLS)

Trino supports row-level filtering through views:

```sql
-- Create a secured view with row-level filtering
CREATE VIEW hive.base.users_secured AS
SELECT 
    user_id,
    username,
    email,
    created_at,
    CASE 
        WHEN current_user = 'admin' THEN salary
        ELSE NULL 
    END as salary,
    department
FROM hive.base.users_raw
WHERE 
    CASE 
        WHEN current_user = 'admin' THEN TRUE
        WHEN current_user LIKE 'analyst_%' THEN department IN ('Sales', 'Marketing')
        ELSE department = regexp_extract(current_user, '^([^_]+)_.*', 1)
    END;
```

### Column-Level Masking

```sql
-- Create view with data masking
CREATE VIEW hive.base.customers_masked AS
SELECT 
    customer_id,
    CASE 
        WHEN current_user IN ('admin', 'compliance_officer') 
        THEN email 
        ELSE concat(substr(email, 1, 2), '***@***')
    END as email,
    CASE 
        WHEN current_user IN ('admin', 'finance') 
        THEN ssn 
        ELSE concat('***-**-', substr(ssn, -4))
    END as ssn,
    first_name,
    last_name
FROM hive.base.customers_raw;
```

### Dynamic Policies with Session Properties

```sql
-- Set session property for department-based filtering
SET SESSION department = 'Engineering';

-- Create view that uses session property
CREATE VIEW hive.base.my_department_data AS
SELECT * FROM hive.base.employees
WHERE department = current_setting('department');
```

## Audit Logging

Trino provides built-in audit logging through event listeners.

Create `/conf/trino/event-listener.properties`:
```properties
event-listener.name=custom-logger
event-listener.config-files=/etc/trino/audit-config.properties
```

Create `/conf/trino/audit-config.properties`:
```properties
# Audit logging configuration
audit.log-path=/var/log/trino/audit.log
audit.log-queries=true
audit.log-schema-changes=true
audit.log-access-denied=true
audit.include-query-text=true
audit.include-user=true
audit.include-remote-address=true
```

## Testing RBAC

### Test Script

```bash
#!/bin/bash

echo "Testing RBAC Policies"
echo "===================="

# Test admin user (should succeed)
echo -e "\n1. Testing admin user - CREATE SCHEMA:"
podman exec -it trino trino --user admin --password --execute "CREATE SCHEMA IF NOT EXISTS hive.test_rbac"

# Test analyst user (should fail)
echo -e "\n2. Testing analyst user - CREATE SCHEMA (should fail):"
podman exec -it trino trino --user analyst --password --execute "CREATE SCHEMA IF NOT EXISTS hive.test_rbac" 2>&1 | grep -i "denied\|error"

# Test analyst user - SELECT (should succeed)
echo -e "\n3. Testing analyst user - SELECT (should succeed):"
podman exec -it trino trino --user analyst --password --execute "SELECT COUNT(*) FROM hive.base.users"

# Test data engineer - INSERT (should succeed)
echo -e "\n4. Testing data_engineer - INSERT (should succeed):"
podman exec -it trino trino --user alice --password --execute "INSERT INTO hive.base.users VALUES (999, 'test', 'test@example.com', CURRENT_TIMESTAMP, true)"

# Test column-level access
echo -e "\n5. Testing column-level restrictions:"
podman exec -it trino trino --user analyst --password --execute "SELECT user_id, username FROM hive.base.users LIMIT 1"
```

## Migration from File-Based to External System

If you want to integrate with an external authorization system in the future:

### 1. Implement SystemAccessControl Interface

```java
public class CustomAccessControl implements SystemAccessControl {
    @Override
    public void checkCanSelectFromColumns(
            SystemSecurityContext context,
            CatalogSchemaTableName table,
            Set<String> columns) {
        // Call external authorization service (Ranger, OPA, etc.)
        boolean allowed = externalAuthService.checkAccess(
            context.getIdentity().getUser(),
            table,
            "SELECT",
            columns
        );
        
        if (!allowed) {
            throw new AccessDeniedException("Access denied");
        }
    }
    
    // Implement other methods...
}
```

### 2. Package as Plugin

Create plugin structure:
```
trino-custom-access-control/
├── pom.xml
├── src/main/
│   ├── java/
│   │   └── com/company/trino/
│   │       ├── CustomAccessControl.java
│   │       └── CustomAccessControlFactory.java
│   └── resources/
│       └── META-INF/
│           └── services/
│               └── io.trino.spi.security.SystemAccessControlFactory
```

## Monitoring and Troubleshooting

### Check Active Policies
```sql
-- View system access control info
SELECT * FROM system.runtime.queries 
WHERE state = 'RUNNING';

-- Check user permissions (from Trino info)
SHOW CATALOGS;
SHOW SCHEMAS IN hive;
```

### Debug Access Denied Issues

1. Check Trino logs:
```bash
podman logs trino | grep -i "access denied\|denied"
```

2. Verify rules.json syntax:
```bash
cat conf/trino/rules.json | jq '.'
```

3. Check user-group mapping:
```bash
cat conf/trino/groups.txt | grep username
```

## Summary

| Feature | File-Based RBAC | Apache Ranger | OPA |
|---------|-----------------|---------------|-----|
| **Ease of Setup** | ✅ Easy | ⚠️ Complex | ⚠️ Moderate |
| **UI for Policies** | ❌ No | ✅ Yes | ⚠️ Limited |
| **Audit Logging** | ⚠️ Basic | ✅ Advanced | ✅ Good |
| **Dynamic Policies** | ⚠️ Limited | ✅ Yes | ✅ Yes |
| **Trino Support** | ✅ Native | ✅ Native (476+) | ⚠️ Community |
| **Column Masking** | ⚠️ Via views | ✅ Built-in | ⚠️ Via views |
| **Row Filtering** | ⚠️ Via views | ✅ Built-in | ⚠️ Via views |
| **Cost** | ✅ Free | ✅ Free (OSS) | ✅ Free |
| **Best For** | Dev, Small teams | Enterprise, Compliance | Cloud-native, K8s |

## Recommendation

For your current HOT Stack setup:

### Option A: File-Based RBAC (Quick Start)
**Best for**: Development, testing, small teams
1. ✅ Already configured and ready to use
2. ✅ **Start with File-Based RBAC** (rules.json) - 5 minute setup
3. ✅ **Use Views for Row/Column-Level Security** - Flexible and powerful
4. ✅ **Implement Audit Logging** - Track all access for compliance
5. ✅ Files: `./enable_rbac.sh` to get started

### Option B: Apache Ranger (Enterprise)
**Best for**: Production, compliance, large teams
1. 🔧 Requires additional infrastructure (Ranger Admin, PostgreSQL, Solr)
2. 🔧 More complex setup (~30 minutes)
3. ✅ Web UI for policy management
4. ✅ Built-in column masking and row filtering
5. ✅ Comprehensive audit with UI
6. 📚 Full guide: **[RANGER_SETUP.md](RANGER_SETUP.md)**

### Migration Path
You can start with file-based and migrate to Ranger later:
1. Use file-based RBAC now (already set up)
2. Deploy Ranger when needed for compliance/scale
3. Migrate policies to Ranger UI
4. Run both in parallel during transition
5. Switch to Ranger when ready

Both options are officially supported in Trino 476!

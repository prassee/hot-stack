# Apache Ranger Integration with Trino 476

## Official Ranger Support in Trino 476

Trino 476 includes **native Apache Ranger integration** with:
- ✅ Policy-based authorization (catalogs, schemas, tables, columns)
- ✅ Column masking
- ✅ Row filtering  
- ✅ Audit logging
- ✅ Web UI for policy management

**Documentation**: https://trino.io/docs/476/security/ranger-access-control.html

## Architecture

```
User Query
    ↓
Trino (with Ranger Plugin)
    ↓
Apache Ranger Admin Server (Policies)
    ↓
PostgreSQL (Policy Storage) + Solr (Audit Logs)
```

## Complete Setup Guide

### Step 1: Start Ranger Services

```bash
# Start Ranger stack
podman-compose -f docker-compose-ranger.yaml up -d

# Wait for Ranger to initialize (2-3 minutes)
sleep 180

# Check status
podman logs ranger-admin | tail -20
```

### Step 2: Configure Trino Ranger Plugin

Create configuration files in `conf/trino/`:

#### conf/trino/access-control.properties
```properties
access-control.name=ranger
ranger.service.name=trino-cluster
ranger.plugin.config.resource=ranger-trino-security.xml,ranger-trino-audit.xml
ranger.hadoop.config.resource=
```

#### conf/trino/ranger-trino-security.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <!-- Ranger Admin Server URL -->
  <property>
    <name>ranger.plugin.trino.policy.rest.url</name>
    <value>http://ranger-admin:6182</value>
    <description>URL to Apache Ranger Admin server</description>
  </property>

  <!-- Cluster name for audit logs -->
  <property>
    <name>ranger.plugin.trino.access.cluster.name</name>
    <value>trino-hot-stack</value>
    <description>Name to identify this Trino cluster</description>
  </property>

  <!-- Service name in Ranger -->
  <property>
    <name>ranger.plugin.trino.service.name</name>
    <value>trino-cluster</value>
    <description>Name of Trino service in Ranger</description>
  </property>

  <!-- Use Ranger for user-group mapping -->
  <property>
    <name>ranger.plugin.trino.use.rangerGroups</name>
    <value>false</value>
    <description>Use Ranger for user-to-group mapping</description>
  </property>

  <property>
    <name>ranger.plugin.trino.use.only.rangerGroups</name>
    <value>false</value>
    <description>Use only Ranger for user-to-group mapping</description>
  </property>

  <!-- Super users (bypass all policies) -->
  <property>
    <name>ranger.plugin.trino.super.users</name>
    <value>admin,aks</value>
    <description>Comma-separated list of super users</description>
  </property>

  <property>
    <name>ranger.plugin.trino.super.groups</name>
    <value>admins</value>
    <description>Comma-separated list of super groups</description>
  </property>

  <!-- Policy refresh interval -->
  <property>
    <name>ranger.plugin.trino.policy.pollIntervalMs</name>
    <value>30000</value>
    <description>Policy refresh interval in milliseconds</description>
  </property>

  <!-- Policy cache directory -->
  <property>
    <name>ranger.plugin.trino.policy.cache.dir</name>
    <value>/tmp/trino/ranger/policy-cache</value>
    <description>Directory for caching policies</description>
  </property>
</configuration>
```

#### conf/trino/ranger-trino-audit.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <!-- Enable auditing -->
  <property>
    <name>xasecure.audit.is.enabled</name>
    <value>true</value>
    <description>Enable audit logging</description>
  </property>

  <!-- Solr audit configuration -->
  <property>
    <name>xasecure.audit.solr.is.enabled</name>
    <value>true</value>
    <description>Enable Solr for audit logs</description>
  </property>

  <property>
    <name>xasecure.audit.solr.solr_url</name>
    <value>http://solr:8983/solr/ranger_audits</value>
    <description>Solr URL for audit logs</description>
  </property>

  <!-- Log4J audit (optional) -->
  <property>
    <name>xasecure.audit.log4j.is.enabled</name>
    <value>true</value>
    <description>Enable Log4J audit</description>
  </property>

  <property>
    <name>xasecure.audit.log4j.is.async</name>
    <value>false</value>
    <description>Use async logging</description>
  </property>

  <property>
    <name>xasecure.audit.log4j.async.max.queue.size</name>
    <value>10240</value>
    <description>Max queue size for async logging</description>
  </property>
</configuration>
```

### Step 3: Update Trino Configuration

Update `conf/trino/config.properties`:
```properties
# Replace or add:
http-server.authentication.type=PASSWORD
access-control.name=ranger
```

### Step 4: Restart Trino

```bash
podman-compose restart trino

# Wait for Trino to start
sleep 20

# Check Trino logs
podman logs trino | grep -i ranger
```

### Step 5: Configure Ranger Policies

#### Access Ranger UI

1. Open browser: http://localhost:6080
2. Login: `admin` / `admin`

#### Create Trino Service

1. Go to "Service Manager"
2. Click "+" next to "TRINO"
3. Fill in:
   - **Service Name**: `trino-cluster`
   - **Display Name**: `Trino HOT Stack`
   - **Description**: `Trino service for HOT Stack`
4. Test connection and save

#### Required Policies (MANDATORY)

**Policy 1: Query Execution Permission**
- Resource: `queryId` = `*`
- Permission: `execute`
- Users: `{USER}` (special token meaning "current user")

**Policy 2: Self-Impersonation**
- Resource: `trinouser` = `{USER}`
- Permission: `impersonate`  
- Users: `{USER}`

Without these policies, users cannot execute any queries!

#### Create Policies

**Policy 3: Admin Full Access**
- Policy Name: `admin-all-access`
- Catalog: `*`
- Schema: `*`
- Table: `*`
- Column: `*`
- Permissions: All
- Users: `admin`, `aks`

**Policy 4: Data Engineers - Hive Access**
- Policy Name: `data-engineers-hive`
- Catalog: `hive`
- Schema: `base`, `managed_db`, `staging`
- Table: `*`
- Column: `*`
- Permissions: `select`, `insert`, `update`, `delete`, `create`, `drop`, `alter`
- Groups: `data_engineers`

**Policy 5: Analysts - Read Only**
- Policy Name: `analysts-readonly`
- Catalog: `hive`, `tpch`
- Schema: `*`
- Table: `*`
- Column: `*`
- Permissions: `select`
- Groups: `analysts`

### Step 6: Create Users and Groups in Ranger

#### Via Ranger UI:

1. Settings → Users/Groups/Roles
2. Add Users: admin, aks, alice, bob, analyst, etc.
3. Create Groups:
   - `admins`: admin, aks
   - `data_engineers`: alice, bob
   - `analysts`: analyst, john, jane

#### Via Trino File-Based Groups (Alternative):

Keep using `conf/trino/groups.txt` - Ranger will respect these mappings if `ranger.plugin.trino.use.only.rangerGroups=false`.

## Advanced Features

### Column Masking

In Ranger UI:
1. Go to policy
2. Click "Masking" tab
3. Add masking condition:
   - **Column**: `email`
   - **Mask Type**: `Show last 4`
   - **Groups**: `analysts`

Result: Analysts see `***@***.com` instead of full email.

### Row Filtering

In Ranger UI:
1. Go to policy
2. Click "Row Level Filter" tab
3. Add filter:
   - **Filter Expression**: `department = 'Sales'`
   - **Groups**: `sales_team`

Result: Sales team only sees rows where department='Sales'.

### Audit Logs

View audit logs:
1. Ranger UI → Audit → Access
2. Filter by user, resource, date
3. Export reports

Query Solr directly:
```bash
curl "http://localhost:8983/solr/ranger_audits/select?q=*:*&rows=10"
```

## Testing

### Test Script

```bash
#!/bin/bash

echo "Testing Ranger RBAC"

# Test admin access
podman exec -i trino trino --user admin --password <<< "admin123
SHOW SCHEMAS IN hive;"

# Test analyst (should work)
podman exec -i trino trino --user analyst --password <<< "analyst123
SELECT COUNT(*) FROM hive.base.users;"

# Test analyst write (should fail)
podman exec -i trino trino --user analyst --password <<< "analyst123
INSERT INTO hive.base.users VALUES (999, 'test', 'test@test.com', CURRENT_TIMESTAMP, true);"
```

## Troubleshooting

### Ranger Connection Issues

```bash
# Check Ranger is running
podman logs ranger-admin

# Test Ranger API
curl -u admin:admin http://localhost:6182/service/public/api/service/trino-cluster

# Check Trino can reach Ranger
podman exec trino curl -v http://ranger-admin:6182
```

### Policy Not Working

1. Check policy is published (green checkmark in Ranger UI)
2. Wait 30 seconds for policy refresh
3. Check Trino logs: `podman logs trino | grep -i ranger`
4. Verify service name matches: `trino-cluster`

### No Audit Logs

```bash
# Check Solr
curl "http://localhost:8983/solr/admin/cores?action=STATUS"

# Check audit configuration
podman exec trino cat /etc/trino/ranger-trino-audit.xml | grep solr

# Check Solr collection
curl "http://localhost:8983/solr/ranger_audits/select?q=*:*"
```

## Comparison: File-Based vs Ranger

| Feature | File-Based RBAC | Apache Ranger |
|---------|----------------|---------------|
| **Setup Complexity** | ⭐ Simple | ⭐⭐⭐ Complex |
| **UI for Policies** | ❌ No | ✅ Yes |
| **Column Masking** | ⚠️ Via views | ✅ Built-in |
| **Row Filtering** | ⚠️ Via views | ✅ Built-in |
| **Audit UI** | ❌ No | ✅ Yes |
| **Policy History** | ❌ No | ✅ Yes |
| **Fine-grained Control** | ✅ Good | ✅ Excellent |
| **Resource Usage** | ⭐ Light | ⭐⭐⭐ Heavy |
| **Best For** | Small teams, dev | Enterprise, compliance |

## Recommendation

**Use File-Based RBAC if:**
- Small team (< 20 users)
- Simple access patterns
- Development/testing environment
- Limited resources

**Use Apache Ranger if:**
- Enterprise environment
- Compliance requirements (SOC2, HIPAA, etc.)
- Need audit trail with UI
- Complex masking/filtering rules
- Multiple data sources
- Need centralized policy management

## Migration Path

### From File-Based to Ranger

1. Start with file-based RBAC (already set up)
2. Deploy Ranger stack when ready
3. Configure Trino to use Ranger
4. Migrate policies from `rules.json` to Ranger UI
5. Test thoroughly in parallel
6. Switch access-control.name=ranger
7. Keep file-based as backup

### Using Both (Hybrid)

```properties
# In access-control.properties
access-control.name=system
security.system-access-control=allow-all,ranger,file
```

This allows:
- Ranger for fine-grained control
- File-based as fallback
- Combined evaluation

## Next Steps

1. Review existing policies in `conf/trino/rules.json`
2. Decide: File-based or Ranger?
3. If Ranger:
   - Deploy: `podman-compose -f docker-compose-ranger.yaml up -d`
   - Configure: Follow Step 2-3 above
   - Migrate policies to Ranger UI
   - Test: Run test script
4. If File-based:
   - Continue with current setup
   - Use `advanced_rbac_examples.sql` for advanced features

## Resources

- Official Docs: https://trino.io/docs/476/security/ranger-access-control.html
- Ranger Docs: https://ranger.apache.org/
- Service Definition: https://github.com/apache/ranger/blob/ranger-2.5/agents-common/src/main/resources/service-defs/ranger-servicedef-trino.json

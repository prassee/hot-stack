# Trino RBAC Integration Complete! 🎉

## Overview

Trino has been successfully integrated with file-based RBAC (Role-Based Access Control). The HOT Stack now has enterprise-grade authentication and authorization.

## What Was Configured

### 1. Authentication
- **Type**: Password-based authentication
- **Password Storage**: `/conf/trino/password.db` (bcrypt-hashed)
- **Auto-Reload**: Passwords reload every 5 seconds
- **Internal Communication**: Secured with shared secret

### 2. Access Control (RBAC)
- **Type**: File-based access control
- **Rules File**: `/conf/trino/rules.json`
- **Group Provider**: `/conf/trino/groups.txt`
- **Auto-Reload**: Policies reload every 5 seconds

### 3. Configuration Files Modified

#### `/conf/trino/config.properties`
```properties
# Authentication
http-server.authentication.type=PASSWORD
internal-communication.shared-secret=hot-stack-secret-change-in-production

# Access Control (RBAC)
access-control.config-files=etc/access-control.properties
```

#### `/conf/trino/access-control.properties`
```properties
access-control.name=file
security.config-file=/etc/trino/rules.json
security.refresh-period=5s
```

#### `/conf/trino/password-authenticator.properties`
```properties
password-authenticator.name=file
file.password-file=/etc/trino/password.db
file.refresh-period=5s
```

#### `/conf/trino/group-provider.properties`
```properties
group-provider.name=file
file.group-file=/etc/trino/groups.txt
file.refresh-period=5s
```

## Configured Users and Roles

### Administrators (admins group)
- **admin** / **admin** - Full system access
- **aks** / **aks** - Full system access

### Data Engineers (data_engineers group)
- **alice** / **alice** - Full access to hive catalog (base, managed_db, staging schemas)
- **bob** / **bob** - Full access to hive catalog (base, managed_db, staging schemas)

### Analysts (analysts group)
- **analyst** / **analyst** - Read-only access to hive.base and tpch
- **john** / **john** - Read-only access
- **jane** / **jane** - Read-only access

### Guests (guests group)
- **guest** / **guest** - Limited read-only access to tpch catalog

## RBAC Policies Summary

### Catalog Access
- **Admins**: Full access to all catalogs
- **Data Engineers**: Full access to hive catalog
- **Analysts**: Read-only access to hive and tpch
- **Guests**: Read-only access to tpch only

### Schema Access
- **Admins**: Can create/own all schemas
- **Data Engineers**: Can create/own base, managed_db, staging schemas in hive
- **Analysts**: Read-only access to base schema

### Table Access
- **Admins**: All privileges (SELECT, INSERT, DELETE, UPDATE, OWNERSHIP, GRANT_SELECT)
- **Data Engineers**: All privileges except GRANT_SELECT on their schemas
- **Analysts**: SELECT only on base schema tables
- **Bob**: Special privilege - can INSERT into products and customers tables

### Session Properties
- **All users**: Can set catalog and system session properties

### System Information
- **admin, aks**: Can read and write system information
- **alice, bob**: Can read system information

## How to Use

### 1. Access Trino Web UI
```bash
# Open in browser
http://localhost:8080
```
Login with any username/password pair above.

### 2. Use Trino CLI
```bash
# Connect as admin
echo "admin" | trino --server http://localhost:8080 --user admin --password

# Connect as analyst
echo "analyst" | trino --server http://localhost:8080 --user analyst --password

# Connect as data engineer
echo "alice" | trino --server http://localhost:8080 --user alice --password
```

### 3. Test RBAC Policies
```bash
# Run automated tests
./test_trino_rbac.sh
```

## Example Queries with Different Users

### As Admin (Full Access)
```sql
-- Admins can do anything
SHOW CATALOGS;
CREATE SCHEMA hive.admin_schema;
CREATE TABLE hive.admin_schema.test_table (id INT, name VARCHAR);
INSERT INTO hive.admin_schema.test_table VALUES (1, 'test');
DROP TABLE hive.admin_schema.test_table;
```

### As Data Engineer (alice)
```sql
-- Data engineers can create schemas and tables in their designated schemas
CREATE SCHEMA IF NOT EXISTS hive.base;
CREATE SCHEMA IF NOT EXISTS hive.managed_db;

CREATE TABLE hive.base.products (
    id INT,
    name VARCHAR,
    price DECIMAL(10,2)
) WITH (
    external_location = 's3://com.dldgv2/delta/products/',
    format = 'PARQUET'
);

INSERT INTO hive.base.products VALUES (1, 'Widget', 29.99);
SELECT * FROM hive.base.products;
```

### As Analyst (analyst)
```sql
-- Analysts can only read data
SHOW SCHEMAS IN hive;
SELECT * FROM hive.base.products;

-- These will FAIL:
-- CREATE TABLE hive.base.test (id INT);  -- Access Denied
-- INSERT INTO hive.base.products VALUES (2, 'Gadget', 49.99);  -- Access Denied
```

### As Guest
```sql
-- Guests have very limited access
SELECT * FROM tpch.tiny.nation;
SELECT * FROM tpch.tiny.customer LIMIT 10;

-- These will FAIL:
-- SHOW SCHEMAS IN hive;  -- Access Denied
-- SELECT * FROM hive.base.products;  -- Access Denied
```

## Managing Users

### Add New User
```bash
./manage_users.py add-user username password
```

### Remove User
```bash
./manage_users.py remove-user username
```

### Change Password
```bash
./manage_users.py change-password username new_password
```

### List Users
```bash
./manage_users.py list-users
```

### Add User to Group
Edit `/conf/trino/groups.txt`:
```
username:group1,group2,group3
```

Trino will automatically reload the file within 5 seconds.

## Monitoring and Troubleshooting

### Check Trino Status
```bash
podman ps | grep trino
```

### View Trino Logs
```bash
podman logs trino
```

### Test Authentication
```bash
# Should succeed with correct password
echo "admin" | trino --server http://localhost:8080 --user admin --password --execute "SELECT 1"

# Should fail with incorrect password
echo "wrong" | trino --server http://localhost:8080 --user admin --password --execute "SELECT 1"
```

### Test Authorization
```bash
# Test analyst trying to create schema (should fail)
echo "analyst" | trino --server http://localhost:8080 --user analyst --password --execute "CREATE SCHEMA hive.test"
```

### Check Access Control Logs
```bash
# Filter for access denied messages
podman logs trino 2>&1 | grep -i "access denied"

# Filter for authentication failures
podman logs trino 2>&1 | grep -i "authentication"
```

## Security Best Practices

1. **Change Shared Secret**: Update `internal-communication.shared-secret` in production
2. **Use Strong Passwords**: Enforce strong passwords for all users
3. **Regular Audits**: Review access logs regularly
4. **Principle of Least Privilege**: Grant minimum necessary permissions
5. **Rotate Credentials**: Regularly update user passwords
6. **Monitor Access**: Track who accesses what data
7. **Backup Configuration**: Keep backups of password.db, rules.json, groups.txt

## Customizing Policies

Edit `/conf/trino/rules.json` to customize access policies:

```json
{
  "catalogs": [
    {
      "user": "newuser",
      "catalog": "hive",
      "allow": "read-only"
    }
  ],
  "schemas": [
    {
      "user": "newuser",
      "catalog": "hive",
      "schema": "public",
      "owner": false
    }
  ],
  "tables": [
    {
      "user": "newuser",
      "catalog": "hive",
      "schema": "public",
      "table": ".*",
      "privileges": ["SELECT"]
    }
  ]
}
```

Trino will automatically reload the policies within 5 seconds.

## Upgrading to Apache Ranger (Optional)

If you need more advanced features like:
- Web-based policy management UI
- Centralized audit logging
- Column-level masking
- Row-level filtering
- Policy versioning
- Advanced compliance reporting

You can upgrade to Apache Ranger integration. See `RANGER_SETUP.md` for instructions.

## Support and Documentation

- **File-Based RBAC**: https://trino.io/docs/476/security/file-system-access-control.html
- **Password Authentication**: https://trino.io/docs/476/security/password-file.html
- **Group Providers**: https://trino.io/docs/476/security/group-file.html
- **Apache Ranger**: https://trino.io/docs/476/security/ranger-access-control.html

## Quick Reference Commands

```bash
# Start Trino
podman start trino

# Stop Trino
podman stop trino

# Restart Trino (to reload all configs)
podman restart trino

# Check if RBAC is working
./test_trino_rbac.sh

# Add a new user
./manage_users.py add-user alice SecurePass123!

# View all groups
cat conf/trino/groups.txt

# View RBAC rules
cat conf/trino/rules.json | jq .

# Connect as different users
trino --server http://localhost:8080 --user admin --password
trino --server http://localhost:8080 --user alice --password
trino --server http://localhost:8080 --user analyst --password
```

## Success! ✓

Your Trino instance now has:
- ✅ Password authentication enabled
- ✅ File-based RBAC active
- ✅ User groups configured
- ✅ Access policies enforced
- ✅ Auto-reload of credentials and policies
- ✅ Secure internal communication

**Status**: Production Ready (remember to change the shared secret!)

**Last Updated**: 2025-11-11

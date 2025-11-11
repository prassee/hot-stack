# RBAC Quick Start Guide

## What is RBAC?

Role-Based Access Control (RBAC) allows you to control who can access what data in Trino based on their role and group membership.

## Quick Setup (5 minutes)

### Step 1: Enable RBAC
```bash
./enable_rbac.sh
```

This will:
- Create default users with passwords
- Enable authentication
- Configure RBAC policies
- Restart Trino

### Step 2: Test RBAC
```bash
./test_rbac.sh
```

This runs automated tests to verify RBAC is working correctly.

### Step 3: Connect with Authentication
```bash
podman exec -it trino trino --user admin --password
# Enter password: admin123
```

## Default Users and Roles

| User | Password | Groups | Permissions |
|------|----------|--------|-------------|
| admin | admin123 | admins, data_engineers | Full access to all catalogs |
| aks | aks | admins, data_engineers | Full access to all catalogs |
| alice | alice123 | data_engineers | Full access to hive catalog |
| bob | bob123 | data_engineers | Full access to hive catalog |
| analyst | analyst123 | analysts | Read-only on hive.base |
| john | john123 | analysts | Read-only on hive.base |
| jane | jane123 | analysts | Read-only on hive.base |
| guest | guest123 | guests | Read-only on tpch catalog |

## Group Permissions

### admins
- Access: All catalogs
- Operations: All (SELECT, INSERT, UPDATE, DELETE, CREATE, DROP)
- Schemas: All
- Tables: All

### data_engineers
- Access: hive catalog
- Operations: All (SELECT, INSERT, UPDATE, DELETE, CREATE, DROP)
- Schemas: base, managed_db, staging
- Tables: All in allowed schemas

### analysts
- Access: hive, tpch catalogs
- Operations: SELECT only
- Schemas: base (hive), all (tpch)
- Tables: All in allowed schemas

### guests
- Access: tpch catalog
- Operations: SELECT only
- Schemas: All
- Tables: All

## Managing Users

### Add a New User
```bash
./manage_users.py add-user newuser password123
```

### Add User to Group
Edit `conf/trino/groups.txt`:
```
newuser:analysts
```

Changes take effect automatically within 5 seconds!

### Change Password
```bash
./manage_users.py change-password username newpassword
```

### Remove User
```bash
./manage_users.py remove-user username
```

## Managing Policies

### Edit Policies
```bash
vim conf/trino/rules.json
```

Changes take effect automatically within 5 seconds!

### Example: Add Read Access to New Schema
```json
{
  "group": "analysts",
  "catalog": "hive",
  "schema": "new_schema",
  "owner": false
}
```

### Example: Grant Specific Table Access
```json
{
  "user": "bob",
  "catalog": "hive",
  "schema": "base",
  "table": "sensitive_data",
  "privileges": ["SELECT"]
}
```

## Testing Access

### Test as Different User
```bash
# As admin (full access)
podman exec -it trino trino --user admin --password <<< "admin123
SHOW SCHEMAS IN hive;"

# As analyst (limited access)
podman exec -it trino trino --user analyst --password <<< "analyst123
SHOW SCHEMAS IN hive;"
```

### Test Specific Query
```bash
podman exec -it trino trino --user analyst --password <<< "analyst123
SELECT COUNT(*) FROM hive.base.users;"
```

## Advanced Features

### Row-Level Security
See `advanced_rbac_examples.sql` for examples of:
- Department-based filtering
- Regional data access
- Time-based access control

### Column-Level Masking
Examples in `advanced_rbac_examples.sql`:
- PII masking (email, phone, SSN)
- Credit card masking
- Sensitive field hiding

### Dynamic Filtering
Use session properties for flexible filtering:
```sql
SET SESSION department = 'Engineering';
SELECT * FROM secured_view;
```

## Troubleshooting

### "Access Denied" Error
1. Check user exists: `./manage_users.py list-users`
2. Check group membership: `cat conf/trino/groups.txt | grep username`
3. Check policies: `cat conf/trino/rules.json | jq '.tables'`
4. Review Trino logs: `podman logs trino | grep -i "access denied"`

### Authentication Not Working
1. Verify password file exists: `ls -la conf/trino/password.db`
2. Check config: `grep authentication conf/trino/config.properties`
3. Restart Trino: `podman-compose restart trino`

### Policies Not Taking Effect
1. Check JSON syntax: `cat conf/trino/rules.json | jq '.'`
2. Wait 5 seconds for auto-reload
3. Check Trino logs: `podman logs trino | tail -50`

## Configuration Files

| File | Purpose | Auto-Reload |
|------|---------|-------------|
| `conf/trino/password.db` | User passwords (bcrypt) | Yes (5s) |
| `conf/trino/groups.txt` | User-group mappings | Yes (5s) |
| `conf/trino/rules.json` | RBAC policies | Yes (5s) |
| `conf/trino/config.properties` | Enable authentication | No (requires restart) |
| `conf/trino/access-control.properties` | Access control config | No (requires restart) |

## Common Use Cases

### Use Case 1: Analyst Team
**Requirement**: Read-only access to production data
```bash
# Add user
./manage_users.py add-user data_analyst pass123

# Add to analysts group
echo "data_analyst:analysts" >> conf/trino/groups.txt
```

### Use Case 2: ETL Service Account
**Requirement**: Write access to staging, read from production
```json
{
  "user": "etl_service",
  "catalog": "hive",
  "schema": "staging",
  "privileges": ["SELECT", "INSERT", "UPDATE", "DELETE"]
},
{
  "user": "etl_service",
  "catalog": "hive",
  "schema": "production",
  "privileges": ["SELECT"]
}
```

### Use Case 3: External Partner
**Requirement**: Access to specific table only
```json
{
  "user": "partner_user",
  "catalog": "hive",
  "schema": "public",
  "table": "shared_data",
  "privileges": ["SELECT"]
}
```

## Best Practices

1. **Principle of Least Privilege**: Give users minimum access needed
2. **Use Groups**: Manage permissions by group, not individual users
3. **Regular Audits**: Review access logs regularly
4. **Strong Passwords**: Use bcrypt with cost factor 10+
5. **Secure Sensitive Data**: Use views for row/column-level security
6. **Document Policies**: Add comments in rules.json explaining policies
7. **Test Changes**: Always test in development before production

## Resources

- Full documentation: `RANGER_RBAC.md`
- Advanced examples: `advanced_rbac_examples.sql`
- Test script: `./test_rbac.sh`
- User management: `./manage_users.py --help`

## Support

For issues or questions:
1. Check logs: `podman logs trino`
2. Review documentation: `RANGER_RBAC.md`
3. Test RBAC: `./test_rbac.sh`
4. Verify configuration: `cat conf/trino/rules.json | jq '.'`

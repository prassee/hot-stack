# Applying RLS to Pre-existing/Existing Tables

## Quick Answer

**You DON'T modify existing tables.** Instead, you create **protected views** on top of them and control access through `rules.json`.

## 4-Step Process

### Step 1: Create Protected Views

For each existing table that needs RLS, create one or more views with filtering/masking logic:

```sql
-- Example: Existing table 'hive.base.employees' needs RLS

-- View 1: Department-based filtering
CREATE OR REPLACE VIEW hive.base.employees_engineering AS
SELECT 
    employee_id, first_name, last_name, department, 
    salary, email, hire_date
FROM hive.base.employees
WHERE department = 'Engineering';  -- Row filtering

-- View 2: Column masking for analysts
CREATE OR REPLACE VIEW hive.base.employees_masked AS
SELECT 
    employee_id, first_name, last_name, department,
    CASE 
        WHEN salary < 80000 THEN 'Under $80k'
        WHEN salary >= 80000 AND salary < 100000 THEN '$80k-$100k'
        ELSE 'Over $100k'
    END as salary_range,  -- Column masking
    hire_date
FROM hive.base.employees;

-- View 3: User-specific filtering
CREATE OR REPLACE VIEW hive.base.my_records AS
SELECT * FROM hive.base.employees
WHERE email = CURRENT_USER || '@company.com';  -- Dynamic filtering
```

### Step 2: Update Access Control Rules

Edit `conf/trino/rules.json` to:
1. **Block** direct access to base table for restricted users
2. **Allow** access to protected views

```json
{
  "tables": [
    {
      "comment": "Block analysts from base table",
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "employees",
      "privileges": []
    },
    {
      "comment": "Allow analysts to access masked view only",
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "employees_masked|employees_summary",
      "privileges": ["SELECT"]
    },
    {
      "comment": "Data engineers can access department views",
      "user": "alice|bob",
      "catalog": "hive",
      "schema": "base",
      "table": "employees_engineering",
      "privileges": ["SELECT"]
    },
    {
      "comment": "Admins keep full access",
      "user": "admin|aks",
      "catalog": "hive",
      "schema": "base",
      "table": "employees",
      "privileges": ["SELECT", "INSERT", "UPDATE", "DELETE", "OWNERSHIP"]
    }
  ]
}
```

### Step 3: Apply Changes

```bash
# Option A: Wait for auto-reload (5 seconds)
# Trino automatically reloads rules.json every 5 seconds

# Option B: Force reload by restarting Trino
podman restart trino
```

### Step 4: Verify RLS is Working

```bash
# Test 1: Admin can access base table
echo "admin" | trino --server http://localhost:8080 --user admin --password \
  --execute "SELECT COUNT(*) FROM hive.base.employees"
# Expected: Returns count

# Test 2: Analyst CANNOT access base table
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
  --execute "SELECT COUNT(*) FROM hive.base.employees"
# Expected: Access Denied error

# Test 3: Analyst CAN access masked view
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
  --execute "SELECT * FROM hive.base.employees_masked LIMIT 5"
# Expected: Returns data with masked columns

# Test 4: Verify row filtering
echo "alice" | trino --server http://localhost:8080 --user alice --password \
  --execute "SELECT COUNT(*) FROM hive.base.employees_engineering"
# Expected: Returns only Engineering department count
```

## Real-World Example

Let's say you have an existing table with customer PII:

```sql
-- Existing table (already has data)
hive.base.customers
  ├── customer_id
  ├── name
  ├── email
  ├── phone
  ├── ssn             -- Sensitive!
  ├── credit_card     -- Sensitive!
  ├── address
  └── purchase_history
```

### Apply RLS in 3 Commands:

```sql
-- 1. Create masked view
CREATE OR REPLACE VIEW hive.base.customers_protected AS
SELECT 
    customer_id,
    SUBSTR(name, 1, 1) || '. ' || SUBSTR(name, POSITION(' ' IN name) + 1) as name_masked,
    SUBSTR(email, POSITION('@' IN email)) as email_domain,
    SUBSTR(phone, 1, 3) || '-***-****' as phone_masked,
    '***-**-' || SUBSTR(ssn, 8, 4) as ssn_last4,
    '****-****-****-' || SUBSTR(credit_card, 16, 4) as cc_last4,
    address,
    purchase_history
FROM hive.base.customers;

-- 2. Update rules.json (add these rules)
-- Block: analysts from hive.base.customers
-- Allow: analysts to hive.base.customers_protected

-- 3. Done! No changes to base table.
```

## Automated Script

Use the provided script to apply RLS to existing tables:

```bash
# Run the automation script
./apply_rls_to_existing_tables.sh
```

This script will:
1. Scan existing tables
2. Generate protected view SQL
3. Show required rules.json changes
4. Create verification tests

## Common Scenarios

### Scenario 1: Department-Based Access

```sql
-- Existing: sales_data table
-- Need: Each department sees only their data

CREATE VIEW sales_data_engineering AS
SELECT * FROM sales_data WHERE department = 'Engineering';

CREATE VIEW sales_data_sales AS
SELECT * FROM sales_data WHERE department = 'Sales';

-- Block base table, allow department views
```

### Scenario 2: User Ownership

```sql
-- Existing: documents table
-- Need: Users see only their documents + public docs

CREATE VIEW my_documents AS
SELECT * FROM documents 
WHERE owner = CURRENT_USER OR is_public = true;

-- Block base table, allow my_documents view
```

### Scenario 3: Time-Based Access

```sql
-- Existing: transaction_history table
-- Need: Analysts see only last 90 days

CREATE VIEW recent_transactions AS
SELECT * FROM transaction_history
WHERE transaction_date >= CURRENT_DATE - INTERVAL '90' DAY;

-- Block base table, allow recent_transactions view
```

### Scenario 4: PII Masking

```sql
-- Existing: employee_records table with PII
-- Need: Mask SSN, salary for most users

CREATE VIEW employee_records_public AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    '***-**-' || SUBSTR(ssn, 8, 4) as ssn_masked,
    CASE 
        WHEN salary < 80000 THEN '<$80k'
        ELSE '>$80k'
    END as salary_band,
    hire_date
FROM employee_records;

-- Block base table, allow public view
```

## Migration Checklist

- [ ] Identify tables with sensitive data
- [ ] Design view filtering/masking logic
- [ ] Create protected views (use `CREATE OR REPLACE VIEW`)
- [ ] Update `rules.json` to block base tables
- [ ] Update `rules.json` to allow view access
- [ ] Restart Trino or wait 5 seconds
- [ ] Test as different users
- [ ] Verify base table is blocked
- [ ] Verify views show correct filtered/masked data
- [ ] Document which views are for which users
- [ ] Update application queries to use views
- [ ] Monitor access logs

## Key Points

✅ **Base table stays unchanged** - No data migration needed
✅ **Non-destructive** - Views sit on top of existing tables
✅ **Reversible** - Can drop views and restore direct access
✅ **No downtime** - Apply while Trino is running
✅ **Flexible** - Create multiple views with different access levels
✅ **Performance** - Views are query-time transformations

❌ **Don't** rename or move existing tables
❌ **Don't** modify table schemas
❌ **Don't** change table storage locations
❌ **Don't** recreate tables from scratch

## Troubleshooting

### Issue: "View already exists"
```sql
-- Use CREATE OR REPLACE VIEW instead of CREATE VIEW
CREATE OR REPLACE VIEW hive.base.my_view AS ...
```

### Issue: "Access Denied" when creating view
```sql
-- Ensure you're logged in as admin or data engineer
-- Views must be created by users with table access
```

### Issue: Users still see base table
```bash
# Check rules.json has correct table name
# Restart Trino to force reload
podman restart trino

# Verify rules are loaded
grep -A 5 "employees" conf/trino/rules.json
```

### Issue: View shows no data
```sql
-- Check WHERE clause logic
-- Verify CURRENT_USER is correct
SELECT CURRENT_USER;

-- Check base table has data
SELECT COUNT(*) FROM hive.base.base_table;
```

## Performance Tips

1. **Use partitioning** on filtered columns
2. **Materialize** frequently-used views
3. **Add indexes** on filter predicates
4. **Cache** view results for repeated queries
5. **Monitor** view query performance

## Files Reference

- `apply_rls_to_existing_tables.sh` - Automated setup script
- `row_level_security_examples.sql` - SQL examples
- `conf/trino/rules_with_rls.json` - Example rules configuration
- `RLS_AND_MASKING_GUIDE.md` - Complete guide

## Quick Command Reference

```bash
# Create view
trino --server http://localhost:8080 --user admin --password \
  -f create_protected_views.sql

# Update rules
vim conf/trino/rules.json

# Reload Trino
podman restart trino

# Test access
./verify_rls.sh

# View logs
podman logs trino | grep -i "access denied"
```

## Summary

**For existing tables:**
1. ✅ Create protected views with filtering/masking
2. ✅ Update rules.json to block base table access
3. ✅ Allow view access for specific users
4. ✅ Test thoroughly

**Don't:**
- ❌ Modify existing table structure
- ❌ Move or rename base tables
- ❌ Recreate tables with new data

**The base table stays exactly as it is!** 🎯

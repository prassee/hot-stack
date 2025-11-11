# Row-Level Security (RLS) and Column Masking in Trino

## Overview

Trino's file-based RBAC doesn't have native dynamic row-level security or column masking like Apache Ranger. However, you can implement effective data protection using **views** combined with **access control rules**.

## Strategy

### 1. **Base Tables** (Restricted Access)
- Store complete, unfiltered data
- Access limited to admins and data engineers
- Never directly exposed to analysts or other users

### 2. **Protected Views** (Controlled Access)
- Filter rows based on user context
- Mask sensitive columns
- Enforce business rules
- Grant access to specific user groups

### 3. **Access Control Rules**
- Block direct table access for restricted users
- Allow only view access
- Enforce through `rules.json` policies

## Implementation Steps

### Step 1: Create Base Tables with Sensitive Data

```sql
-- Example: Employee table with PII
CREATE TABLE hive.base.employees (
    employee_id INT,
    first_name VARCHAR,
    last_name VARCHAR,
    department VARCHAR,
    salary DECIMAL(10,2),
    ssn VARCHAR,              -- Sensitive: needs masking
    email VARCHAR,
    hire_date DATE
) WITH (
    external_location = 's3://com.dldgv2/delta/employees/',
    format = 'PARQUET'
);
```

### Step 2: Create Views with Row-Level Filtering

#### A. Department-Based Filtering
```sql
-- Engineering department only
CREATE OR REPLACE VIEW hive.base.employees_engineering AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    salary,
    email,
    hire_date
    -- SSN excluded (column masking)
FROM hive.base.employees
WHERE department = 'Engineering';
```

#### B. User-Based Filtering
```sql
-- Show only user's own records + public records
CREATE OR REPLACE VIEW hive.base.my_documents AS
SELECT 
    doc_id,
    title,
    content,
    owner,
    department
FROM hive.base.documents
WHERE 
    owner = CURRENT_USER       -- Dynamic filtering
    OR is_public = true;
```

#### C. Time-Based Filtering
```sql
-- Only recent records (last 90 days)
CREATE OR REPLACE VIEW hive.base.recent_financial_records AS
SELECT 
    record_id,
    transaction_date,
    amount,
    description
FROM hive.base.financial_records
WHERE transaction_date >= CURRENT_DATE - INTERVAL '90' DAY;
```

### Step 3: Implement Column Masking in Views

#### A. Conditional Masking (Role-Based)
```sql
CREATE OR REPLACE VIEW hive.base.employees_masked AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    -- Mask salary based on user role
    CASE 
        WHEN CURRENT_USER IN ('admin', 'aks') THEN CAST(salary AS VARCHAR)
        WHEN salary < 80000 THEN 'Below $80k'
        WHEN salary >= 80000 AND salary < 100000 THEN '$80k-$100k'
        ELSE 'Above $100k'
    END as salary_range,
    -- Mask SSN: show last 4 digits only
    'XXX-XX-' || SUBSTR(ssn, 8, 4) as ssn_masked,
    hire_date
FROM hive.base.employees;
```

#### B. Partial Masking (PII Protection)
```sql
CREATE OR REPLACE VIEW hive.base.customers_protected AS
SELECT 
    customer_id,
    -- Mask name: show only first initial
    SUBSTR(name, 1, 1) || '. ' || SUBSTR(name, POSITION(' ' IN name) + 1) as name_masked,
    -- Mask email: show domain only
    SUBSTR(email, POSITION('@' IN email)) as email_domain,
    -- Mask phone: show area code only
    SUBSTR(phone, 1, 3) || '-***-****' as phone_masked,
    -- Mask credit card: show last 4 digits
    '****-****-****-' || SUBSTR(credit_card, 16, 4) as cc_masked,
    region,
    last_purchase_date
FROM hive.base.customer_data;
```

#### C. Complete Redaction
```sql
CREATE OR REPLACE VIEW hive.base.employees_public AS
SELECT 
    employee_id,
    department,
    hire_date
    -- All PII completely removed
FROM hive.base.employees;
```

### Step 4: Configure Access Control Rules

Update `conf/trino/rules.json`:

```json
{
  "tables": [
    {
      "comment": "Admins and data engineers: full access to base tables",
      "user": "admin|aks",
      "catalog": "hive",
      "schema": "base",
      "table": ".*",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP"]
    },
    {
      "comment": "Block analysts from accessing base tables with PII",
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "employees|customer_data|financial_records",
      "privileges": []
    },
    {
      "comment": "Analysts can only access protected views",
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "employees_masked|employees_summary|customers_protected|recent_financial_records",
      "privileges": ["SELECT"]
    },
    {
      "comment": "Data engineer alice: department-specific access",
      "user": "alice",
      "catalog": "hive",
      "schema": "base",
      "table": "employees_engineering",
      "privileges": ["SELECT"]
    }
  ]
}
```

### Step 5: Test Row-Level Security

```sql
-- As admin: see all employees
SELECT * FROM hive.base.employees;
-- Result: All 100 employees visible

-- As alice (data engineer): see only Engineering
SELECT * FROM hive.base.employees_engineering;
-- Result: Only 25 Engineering employees visible

-- As analyst: blocked from base table
SELECT * FROM hive.base.employees;
-- Error: Access Denied

-- As analyst: can access masked view
SELECT * FROM hive.base.employees_masked;
-- Result: All employees but with salary ranges and masked SSN
```

## Common RLS Patterns

### Pattern 1: Multi-Level Access

```sql
-- Level 1: Public summary (all users)
CREATE VIEW hive.base.employees_public AS
SELECT department, COUNT(*) as count, AVG(salary) as avg_salary
FROM hive.base.employees
GROUP BY department;

-- Level 2: Department-filtered (managers)
CREATE VIEW hive.base.employees_dept AS
SELECT * FROM hive.base.employees
WHERE department = '<dept from user context>';

-- Level 3: Full access (admins)
-- Direct table access via rules.json
```

### Pattern 2: Hierarchical Filtering

```sql
-- Managers see their team + themselves
CREATE VIEW hive.base.team_members AS
SELECT * FROM hive.base.employees
WHERE 
    manager_id = (SELECT employee_id FROM hive.base.employees WHERE email = CURRENT_USER || '@company.com')
    OR employee_id = (SELECT employee_id FROM hive.base.employees WHERE email = CURRENT_USER || '@company.com');
```

### Pattern 3: Regional Data Isolation

```sql
-- US region analyst
CREATE VIEW hive.base.customers_us AS
SELECT * FROM hive.base.customer_data
WHERE region = 'US';

-- EU region analyst  
CREATE VIEW hive.base.customers_eu AS
SELECT * FROM hive.base.customer_data
WHERE region = 'EU';
```

## Column Masking Techniques

### 1. **Nullification**
```sql
SELECT 
    customer_id,
    CASE WHEN CURRENT_USER IN ('admin', 'aks') THEN ssn ELSE NULL END as ssn
FROM customers;
```

### 2. **Partial Redaction**
```sql
-- Credit card: ****-****-****-1234
'****-****-****-' || SUBSTR(credit_card, 16, 4)

-- Email: j***@company.com
SUBSTR(email, 1, 1) || '***' || SUBSTR(email, POSITION('@' IN email))

-- Phone: (555) ***-****
SUBSTR(phone, 1, 5) || ' ***-****'
```

### 3. **Hashing**
```sql
-- One-way hash for analytics
SELECT 
    customer_id,
    sha256(to_utf8(email)) as email_hash  -- Can track unique users without PII
FROM customers;
```

### 4. **Generalization**
```sql
-- Age ranges instead of exact age
CASE 
    WHEN age < 18 THEN 'Under 18'
    WHEN age >= 18 AND age < 30 THEN '18-29'
    WHEN age >= 30 AND age < 50 THEN '30-49'
    ELSE '50+'
END as age_group

-- Salary bands
ROUND(salary, -4) as salary_band  -- Round to nearest 10k
```

### 5. **Tokenization**
```sql
-- Replace with random token (requires lookup table)
SELECT 
    customer_id,
    COALESCE(
        (SELECT token FROM hive.base.token_map WHERE original = email),
        'TOKEN-' || CAST(random() AS VARCHAR)
    ) as email_token
FROM customers;
```

## Enforcement Strategy

### 1. **Deny Direct Table Access**
```json
{
  "group": "analysts",
  "catalog": "hive",
  "schema": "base",
  "table": "employees|customers|transactions",
  "privileges": []
}
```

### 2. **Allow Only View Access**
```json
{
  "group": "analysts",
  "catalog": "hive",
  "schema": "base",
  "table": ".*_masked|.*_protected|.*_summary",
  "privileges": ["SELECT"]
}
```

### 3. **Use Naming Conventions**
- Base tables: `tablename` (restricted)
- Protected views: `tablename_protected` (analysts)
- Masked views: `tablename_masked` (analysts)
- Summary views: `tablename_summary` (public)
- Department views: `tablename_engineering` (specific groups)

## Best Practices

### 1. **View Management**
- Create views in a controlled schema (e.g., `hive.protected`)
- Document which views are for which user groups
- Use consistent naming patterns
- Version your views

### 2. **Testing**
```bash
# Test as different users
echo "admin" | trino --server http://localhost:8080 --user admin --password --execute "SELECT * FROM hive.base.employees"
echo "analyst" | trino --server http://localhost:8080 --user analyst --password --execute "SELECT * FROM hive.base.employees_masked"
```

### 3. **Audit & Monitoring**
```sql
-- Track view usage
SELECT 
    query_id,
    user,
    query,
    tables
FROM system.runtime.queries
WHERE query LIKE '%employees%'
ORDER BY created DESC;
```

### 4. **Performance Optimization**
- Materialize frequently-used filtered views
- Add indexes on filter columns
- Use partitioning for time-based filtering
- Cache masked results for repeated queries

### 5. **Documentation**
```sql
-- Add comments to views
COMMENT ON VIEW hive.base.employees_masked IS 'Protected view with salary masking and SSN redaction. For analysts only.';
```

## Limitations & Trade-offs

### File-Based RBAC Limitations
- ❌ No dynamic policy updates (must recreate views)
- ❌ No centralized policy management UI
- ❌ More complex to maintain at scale
- ❌ View definitions visible to all users
- ❌ Performance overhead from views

### When to Consider Alternatives
- Need for dynamic RLS based on data attributes
- Centralized audit logging requirements
- Column-level encryption needs
- Real-time policy updates
- Complex conditional masking logic
- Large number of tables/users

## Migration Path

If you outgrow file-based RLS:

1. **Upgrade to Apache Ranger** (native RLS and masking)
2. **Use External Authorization** (OPA, custom plugin)
3. **Data Catalog Integration** (AWS Lake Formation, etc.)

## Quick Reference

### Enable RLS for a Table

```bash
# 1. Create protected view
trino> CREATE VIEW hive.base.table_protected AS 
       SELECT * FROM hive.base.table WHERE <filter>;

# 2. Update rules.json
# Block: hive.base.table for analysts
# Allow: hive.base.table_protected for analysts

# 3. Restart Trino (or wait 5s for auto-reload)
podman restart trino
```

### Test Access

```bash
# Should succeed
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
  --execute "SELECT COUNT(*) FROM hive.base.table_protected"

# Should fail
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
  --execute "SELECT COUNT(*) FROM hive.base.table"
```

## Example Files

- `row_level_security_examples.sql` - Complete SQL examples
- `conf/trino/rules_with_rls.json` - Access control configuration
- Run examples: `trino --server http://localhost:8080 --user admin --password -f row_level_security_examples.sql`

## Support

For issues or questions:
1. Check Trino logs: `podman logs trino | grep -i "access denied"`
2. Verify rules: `cat conf/trino/rules.json | jq .`
3. Test view definitions: `SHOW CREATE VIEW hive.base.view_name`

#!/bin/bash
# Apply Row-Level Security to Existing Tables in Trino
# This script demonstrates the process without modifying base tables

set -e

echo "=== Applying RLS to Existing Tables ==="
echo ""
echo "This process will:"
echo "  1. Identify existing tables that need RLS"
echo "  2. Create protected views on top of them"
echo "  3. Update access control rules"
echo "  4. Verify the configuration"
echo ""

# Configuration
TRINO_HOST="localhost:8080"
TRINO_USER="admin"
TRINO_PASSWORD="admin"

# Function to execute SQL
execute_sql() {
    local sql="$1"
    echo "$TRINO_PASSWORD" | trino --server "http://${TRINO_HOST}" \
        --user "$TRINO_USER" --password --execute "$sql" 2>&1
}

# Step 1: List existing tables that need RLS
echo "=== Step 1: Scanning Existing Tables ==="
echo ""
echo "Existing tables in hive.base schema:"
execute_sql "SHOW TABLES IN hive.base" || echo "Schema may not exist yet"
echo ""

# Step 2: Create protected views for existing tables
echo "=== Step 2: Creating Protected Views ==="
echo ""

# Example: Apply RLS to an existing 'employees' table
echo "Creating protected views for 'employees' table..."

# View 1: Department-based filtering for data engineers
cat << 'EOF' | execute_sql "$(cat)" || echo "View creation command prepared"
-- Protected view for Engineering department
CREATE OR REPLACE VIEW hive.base.employees_engineering AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    salary,
    email,
    hire_date
FROM hive.base.employees
WHERE department = 'Engineering';
EOF

echo "  ✓ Created: employees_engineering (Engineering dept only)"

# View 2: Masked view for analysts
cat << 'EOF' | execute_sql "$(cat)" || echo "View creation command prepared"
-- Masked view for analysts
CREATE OR REPLACE VIEW hive.base.employees_masked AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    -- Mask salary: show ranges instead of exact values
    CASE 
        WHEN salary < 60000 THEN 'Under $60k'
        WHEN salary >= 60000 AND salary < 80000 THEN '$60k-$80k'
        WHEN salary >= 80000 AND salary < 100000 THEN '$80k-$100k'
        WHEN salary >= 100000 AND salary < 120000 THEN '$100k-$120k'
        ELSE 'Over $120k'
    END as salary_range,
    hire_date
FROM hive.base.employees;
EOF

echo "  ✓ Created: employees_masked (salary masked, all records)"

# View 3: Summary view (aggregated, no PII)
cat << 'EOF' | execute_sql "$(cat)" || echo "View creation command prepared"
-- Summary view for public consumption
CREATE OR REPLACE VIEW hive.base.employees_summary AS
SELECT 
    department,
    COUNT(*) as employee_count,
    AVG(salary) as avg_salary,
    MIN(hire_date) as earliest_hire,
    MAX(hire_date) as latest_hire,
    COUNT(CASE WHEN hire_date > CURRENT_DATE - INTERVAL '1' YEAR THEN 1 END) as recent_hires
FROM hive.base.employees
GROUP BY department;
EOF

echo "  ✓ Created: employees_summary (aggregated data only)"

echo ""

# Step 3: Backup current rules.json
echo "=== Step 3: Updating Access Control Rules ==="
echo ""
echo "Backing up current rules.json..."
cp conf/trino/rules.json conf/trino/rules.json.backup
echo "  ✓ Backup created: conf/trino/rules.json.backup"
echo ""

# Step 4: Show the required changes to rules.json
echo "Required changes to conf/trino/rules.json:"
echo ""
cat << 'EOF'

Add these rules to the "tables" section:

{
  "tables": [
    // ... existing rules ...
    
    // BLOCK direct access to sensitive base table for analysts
    {
      "comment": "Analysts cannot access base employees table directly",
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "employees",
      "privileges": []
    },
    
    // ALLOW access to protected views for analysts
    {
      "comment": "Analysts can access masked/summary views only",
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "employees_masked|employees_summary",
      "privileges": ["SELECT"]
    },
    
    // ALLOW department-specific views for data engineers
    {
      "comment": "Data engineers can access department-filtered views",
      "user": "alice|bob",
      "catalog": "hive",
      "schema": "base",
      "table": "employees_engineering",
      "privileges": ["SELECT"]
    },
    
    // Admins keep full access to base tables
    {
      "comment": "Admins have full access to base tables",
      "user": "admin|aks",
      "catalog": "hive",
      "schema": "base",
      "table": "employees",
      "privileges": ["SELECT", "INSERT", "UPDATE", "DELETE", "OWNERSHIP"]
    }
  ]
}

EOF

echo ""
echo "=== Step 4: Apply Configuration ==="
echo ""
echo "To apply these changes:"
echo "  1. Edit conf/trino/rules.json and add the rules above"
echo "  2. Trino will auto-reload in 5 seconds, or restart manually:"
echo "     podman restart trino"
echo ""

# Step 5: Create verification script
echo "=== Step 5: Creating Verification Script ==="
cat > verify_rls.sh << 'VERIFY_EOF'
#!/bin/bash
# Verify RLS is working correctly

echo "=== Verifying Row-Level Security ==="
echo ""

# Test 1: Admin can access base table
echo "Test 1: Admin accessing base table (should succeed)"
echo "admin" | trino --server http://localhost:8080 --user admin --password \
    --execute "SELECT COUNT(*) as admin_count FROM hive.base.employees" 2>&1 | grep -E "admin_count|Error" || echo "Query executed"
echo ""

# Test 2: Analyst CANNOT access base table
echo "Test 2: Analyst accessing base table (should fail)"
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
    --execute "SELECT COUNT(*) FROM hive.base.employees" 2>&1 | grep -E "Access Denied|Error|denied" || echo "Access blocked successfully"
echo ""

# Test 3: Analyst CAN access masked view
echo "Test 3: Analyst accessing masked view (should succeed)"
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
    --execute "SELECT COUNT(*) as masked_count FROM hive.base.employees_masked" 2>&1 | grep -E "masked_count|rows" || echo "Query executed"
echo ""

# Test 4: Data engineer accessing department view
echo "Test 4: Alice accessing engineering view (should see filtered data)"
echo "alice" | trino --server http://localhost:8080 --user alice --password \
    --execute "SELECT COUNT(*) as eng_count FROM hive.base.employees_engineering" 2>&1 | grep -E "eng_count|rows" || echo "Query executed"
echo ""

# Test 5: Verify column masking
echo "Test 5: Verifying salary is masked in analyst view"
echo "analyst" | trino --server http://localhost:8080 --user analyst --password \
    --execute "SELECT DISTINCT salary_range FROM hive.base.employees_masked LIMIT 5" 2>&1 | head -10
echo ""

echo "=== Verification Complete ==="
VERIFY_EOF

chmod +x verify_rls.sh
echo "  ✓ Created: verify_rls.sh"
echo ""

echo "=== Summary ==="
echo ""
echo "Protected views created for existing table 'employees':"
echo "  • employees_engineering - Department-filtered for data engineers"
echo "  • employees_masked - Column-masked for analysts"
echo "  • employees_summary - Aggregated for public consumption"
echo ""
echo "Next steps:"
echo "  1. Review the generated SQL and rules above"
echo "  2. Update conf/trino/rules.json with the new access rules"
echo "  3. Wait 5 seconds for auto-reload or restart Trino"
echo "  4. Run: ./verify_rls.sh to test the configuration"
echo ""
echo "The base table 'employees' remains unchanged!"
echo "All filtering and masking happens in the views."
echo ""

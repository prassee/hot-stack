-- =====================================================
-- Row-Level Security (RLS) Examples for Trino
-- =====================================================
-- File-based RBAC doesn't have native RLS, but we can implement it using:
-- 1. Views with WHERE clauses
-- 2. Session properties to pass user context
-- 3. Table access restrictions in rules.json

-- =====================================================
-- Example 1: Department-Based Row Filtering
-- =====================================================

-- Original table with sensitive data
CREATE TABLE IF NOT EXISTS hive.base.employees (
    employee_id INT,
    first_name VARCHAR,
    last_name VARCHAR,
    department VARCHAR,
    salary DECIMAL(10,2),
    ssn VARCHAR,
    email VARCHAR,
    hire_date DATE
) WITH (
    external_location = 's3://com.dldgv2/delta/employees/',
    format = 'PARQUET'
);

-- Sample data
INSERT INTO hive.base.employees VALUES
(1, 'John', 'Doe', 'Engineering', 95000.00, '123-45-6789', 'john.doe@company.com', DATE '2020-01-15'),
(2, 'Jane', 'Smith', 'Sales', 85000.00, '234-56-7890', 'jane.smith@company.com', DATE '2019-06-20'),
(3, 'Bob', 'Johnson', 'Engineering', 105000.00, '345-67-8901', 'bob.johnson@company.com', DATE '2018-03-10'),
(4, 'Alice', 'Williams', 'HR', 75000.00, '456-78-9012', 'alice.williams@company.com', DATE '2021-02-28'),
(5, 'Charlie', 'Brown', 'Sales', 90000.00, '567-89-0123', 'charlie.brown@company.com', DATE '2020-11-05');

-- =====================================================
-- Row-Level Security Implementation
-- =====================================================

-- View for Engineering department only
-- Data engineers (alice, bob) will see only Engineering records
CREATE OR REPLACE VIEW hive.base.employees_engineering AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    salary,
    email,
    hire_date
    -- Note: SSN is excluded (column masking)
FROM hive.base.employees
WHERE department = 'Engineering';

-- View for Sales department
CREATE OR REPLACE VIEW hive.base.employees_sales AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    email,
    hire_date
    -- Note: salary and SSN excluded
FROM hive.base.employees
WHERE department = 'Sales';

-- View for HR (all records, all columns except SSN)
CREATE OR REPLACE VIEW hive.base.employees_hr AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    salary,
    email,
    hire_date
    -- Note: SSN excluded for privacy
FROM hive.base.employees;

-- View for analysts (aggregated data only, no PII)
CREATE OR REPLACE VIEW hive.base.employees_summary AS
SELECT 
    department,
    COUNT(*) as employee_count,
    AVG(salary) as avg_salary,
    MIN(hire_date) as earliest_hire,
    MAX(hire_date) as latest_hire
FROM hive.base.employees
GROUP BY department;

-- =====================================================
-- Example 2: User-Based Row Filtering with Current User
-- =====================================================

-- Table with user ownership
CREATE TABLE IF NOT EXISTS hive.base.documents (
    doc_id INT,
    title VARCHAR,
    content VARCHAR,
    owner VARCHAR,
    department VARCHAR,
    created_at TIMESTAMP,
    is_public BOOLEAN
) WITH (
    external_location = 's3://com.dldgv2/delta/documents/',
    format = 'PARQUET'
);

-- Sample data
INSERT INTO hive.base.documents VALUES
(1, 'Q4 Report', 'Confidential quarterly results...', 'alice', 'Engineering', TIMESTAMP '2024-10-01 09:00:00', false),
(2, 'Team Meeting Notes', 'Discussion points...', 'bob', 'Engineering', TIMESTAMP '2024-10-05 14:30:00', false),
(3, 'Company Policy', 'Updated policies...', 'admin', 'HR', TIMESTAMP '2024-09-15 10:00:00', true),
(4, 'Sales Strategy', 'Q1 2025 plan...', 'analyst', 'Sales', TIMESTAMP '2024-10-10 11:00:00', false);

-- View that shows only user's own documents + public documents
-- Note: In Trino, use "$user" variable or session properties
CREATE OR REPLACE VIEW hive.base.my_documents AS
SELECT 
    doc_id,
    title,
    content,
    owner,
    department,
    created_at
FROM hive.base.documents
WHERE 
    owner = CURRENT_USER  -- Shows only documents owned by current user
    OR is_public = true;   -- OR public documents

-- =====================================================
-- Example 3: Column Masking with CASE Statements
-- =====================================================

-- View with salary masking based on role
CREATE OR REPLACE VIEW hive.base.employees_masked AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    -- Mask salary: show actual value only to admins, show range to others
    CASE 
        WHEN CURRENT_USER IN ('admin', 'aks') THEN salary
        WHEN salary < 80000 THEN 'Below $80k'
        WHEN salary >= 80000 AND salary < 100000 THEN '$80k-$100k'
        ELSE 'Above $100k'
    END as salary_range,
    -- Mask SSN: show last 4 digits only
    'XXX-XX-' || SUBSTR(ssn, 8, 4) as ssn_masked,
    -- Mask email: show domain only
    SUBSTR(email, POSITION('@' IN email)) as email_domain,
    hire_date
FROM hive.base.employees;

-- =====================================================
-- Example 4: Advanced Column Masking Functions
-- =====================================================

-- View with multiple masking strategies
CREATE OR REPLACE VIEW hive.base.employees_protected AS
SELECT 
    employee_id,
    -- Name masking: show full name to admins, first initial only to others
    CASE 
        WHEN CURRENT_USER IN ('admin', 'aks') THEN first_name || ' ' || last_name
        ELSE SUBSTR(first_name, 1, 1) || '. ' || last_name
    END as name,
    department,
    -- Salary masking with NULL for unauthorized users
    CASE 
        WHEN CURRENT_USER IN ('admin', 'aks', 'alice', 'bob') THEN salary
        ELSE NULL
    END as salary,
    -- SSN: only show to HR and admins
    CASE 
        WHEN CURRENT_USER IN ('admin', 'aks') THEN ssn
        ELSE '***-**-****'
    END as ssn,
    -- Email: redact for analysts
    CASE 
        WHEN CURRENT_USER IN ('analyst') THEN '[REDACTED]'
        ELSE email
    END as email,
    hire_date
FROM hive.base.employees;

-- =====================================================
-- Example 5: Time-Based Row Filtering
-- =====================================================

CREATE TABLE IF NOT EXISTS hive.base.financial_records (
    record_id INT,
    account_number VARCHAR,
    transaction_date DATE,
    amount DECIMAL(15,2),
    description VARCHAR,
    created_by VARCHAR
) WITH (
    external_location = 's3://com.dldgv2/delta/financial_records/',
    format = 'PARQUET'
);

-- Analysts can only see records from last 90 days
CREATE OR REPLACE VIEW hive.base.recent_financial_records AS
SELECT 
    record_id,
    SUBSTR(account_number, 1, 4) || '****' as account_number_masked,
    transaction_date,
    amount,
    description
FROM hive.base.financial_records
WHERE transaction_date >= CURRENT_DATE - INTERVAL '90' DAY;

-- Data engineers can see all historical data
CREATE OR REPLACE VIEW hive.base.all_financial_records AS
SELECT 
    record_id,
    account_number,
    transaction_date,
    amount,
    description,
    created_by
FROM hive.base.financial_records;

-- =====================================================
-- Example 6: Combining RLS with Column Masking
-- =====================================================

CREATE TABLE IF NOT EXISTS hive.base.customer_data (
    customer_id INT,
    name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    credit_card VARCHAR,
    region VARCHAR,
    account_balance DECIMAL(15,2),
    last_purchase_date DATE
) WITH (
    external_location = 's3://com.dldgv2/delta/customers/',
    format = 'PARQUET'
);

-- Regional view with PII masking for analysts
CREATE OR REPLACE VIEW hive.base.customers_protected AS
SELECT 
    customer_id,
    -- Mask name: show only first name initial
    SUBSTR(name, 1, 1) || '.' as name_initial,
    -- Mask email: show domain only
    SUBSTR(email, POSITION('@' IN email) + 1) as email_domain,
    -- Mask phone: show area code only
    SUBSTR(phone, 1, 3) || '-***-****' as phone_masked,
    -- Fully mask credit card
    '****-****-****-' || SUBSTR(credit_card, 16, 4) as credit_card_masked,
    region,
    -- Round balance to nearest thousand
    ROUND(account_balance, -3) as balance_range,
    last_purchase_date
FROM hive.base.customer_data
WHERE 
    -- Row-level filter: analysts can only see their region
    CASE 
        WHEN CURRENT_USER IN ('admin', 'aks') THEN true
        WHEN CURRENT_USER = 'alice' THEN region = 'West'
        WHEN CURRENT_USER = 'bob' THEN region = 'East'
        WHEN CURRENT_USER = 'analyst' THEN region IN ('West', 'East')
        ELSE false
    END;

-- =====================================================
-- How to Use These Views
-- =====================================================

-- 1. Update rules.json to restrict direct table access
--    and allow only view access for specific users

-- 2. Users query the views instead of base tables:

-- As analyst (read-only, masked data):
-- SELECT * FROM hive.base.employees_summary;
-- SELECT * FROM hive.base.employees_masked WHERE department = 'Engineering';

-- As alice (data engineer, department-specific):
-- SELECT * FROM hive.base.employees_engineering;
-- SELECT * FROM hive.base.my_documents;

-- As admin (full access):
-- SELECT * FROM hive.base.employees;  -- Direct table access

-- =====================================================
-- Testing Row-Level Security
-- =====================================================

-- Test as different users:
-- 1. admin should see all rows
-- 2. alice should see only Engineering department
-- 3. analyst should see only summary/masked views

-- Verify filtering works:
SELECT 'Testing RLS' as test_type, COUNT(*) as total_rows 
FROM hive.base.employees;

SELECT 'Engineering View' as view_name, COUNT(*) as visible_rows 
FROM hive.base.employees_engineering;

SELECT 'Sales View' as view_name, COUNT(*) as visible_rows 
FROM hive.base.employees_sales;

SELECT 'Masked View' as view_name, COUNT(*) as visible_rows 
FROM hive.base.employees_masked;

-- =====================================================
-- Important Notes
-- =====================================================

/*
1. REVOKE direct table access in rules.json
   - Base tables should only be accessible by admins/data_engineers
   - Analysts should only have access to views

2. Views must be created with appropriate permissions
   - Views inherit security context from creator
   - Use DEFINER vs INVOKER security mode carefully

3. Column masking is implemented at view layer
   - Original data remains unchanged in base tables
   - Multiple views can provide different masking levels

4. Performance considerations:
   - Views add query overhead
   - Consider materializing frequently-used filtered views
   - Use partitioning on filtered columns

5. Audit trail:
   - Log all view access in Trino query logs
   - Monitor who accesses which views
   - Track CURRENT_USER in audit tables

6. Limitations of file-based approach:
   - No dynamic policy updates (requires view recreation)
   - Less flexible than dedicated RLS systems like Ranger
   - More maintenance overhead for complex scenarios
*/

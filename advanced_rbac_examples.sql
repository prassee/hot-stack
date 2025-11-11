-- Advanced RBAC Examples: Row-Level Security and Column Masking
-- These examples show how to implement fine-grained access control

-- ==========================================
-- ROW-LEVEL SECURITY (RLS)
-- ==========================================

-- Example 1: Department-based row filtering
-- Only show rows relevant to user's department

CREATE OR REPLACE VIEW hive.base.employees_secured AS
SELECT 
    employee_id,
    first_name,
    last_name,
    email,
    department,
    hire_date,
    -- Show salary only to admins and HR
    CASE 
        WHEN current_user IN ('admin', 'aks') THEN salary
        WHEN current_user LIKE 'hr_%' THEN salary
        ELSE NULL 
    END as salary
FROM hive.base.employees_raw
WHERE 
    -- Admin and aks see all
    current_user IN ('admin', 'aks')
    -- HR users see all
    OR current_user LIKE 'hr_%'
    -- Managers see their department
    OR (current_user LIKE 'mgr_%' AND department = regexp_extract(current_user, '^mgr_(.+)', 1))
    -- Regular users see only their own record
    OR email = concat(current_user, '@company.com');

-- Example 2: Regional data access
-- Sales reps only see their region's data

CREATE OR REPLACE VIEW hive.base.sales_regional AS
SELECT 
    sale_id,
    customer_id,
    product_id,
    amount,
    sale_date,
    region
FROM hive.base.sales_raw
WHERE 
    current_user IN ('admin', 'aks')
    OR region = COALESCE(
        -- Extract region from username like 'sales_east'
        regexp_extract(current_user, '^sales_(.+)', 1),
        'none'
    );

-- Example 3: Time-based access control
-- Historical data access based on user role

CREATE OR REPLACE VIEW hive.base.transactions_tiered AS
SELECT 
    transaction_id,
    customer_id,
    amount,
    transaction_date,
    status
FROM hive.base.transactions_raw
WHERE 
    -- Admins see everything
    current_user IN ('admin', 'aks')
    -- Analysts see last 90 days
    OR (current_user LIKE 'analyst_%' AND transaction_date >= CURRENT_DATE - INTERVAL '90' DAY)
    -- Regular users see last 30 days
    OR transaction_date >= CURRENT_DATE - INTERVAL '30' DAY;

-- ==========================================
-- COLUMN-LEVEL MASKING
-- ==========================================

-- Example 4: PII (Personally Identifiable Information) masking

CREATE OR REPLACE VIEW hive.base.customers_masked AS
SELECT 
    customer_id,
    
    -- Full name for privileged users, masked for others
    CASE 
        WHEN current_user IN ('admin', 'aks', 'compliance_officer') 
        THEN first_name 
        ELSE substr(first_name, 1, 1) || '***'
    END as first_name,
    
    CASE 
        WHEN current_user IN ('admin', 'aks', 'compliance_officer') 
        THEN last_name 
        ELSE '***'
    END as last_name,
    
    -- Email masking
    CASE 
        WHEN current_user IN ('admin', 'aks', 'support_team') 
        THEN email 
        ELSE concat(substr(email, 1, 2), '***@***')
    END as email,
    
    -- Phone masking
    CASE 
        WHEN current_user IN ('admin', 'aks', 'support_team') 
        THEN phone 
        ELSE concat('***-***-', substr(phone, -4))
    END as phone,
    
    -- SSN masking (only show to specific roles)
    CASE 
        WHEN current_user IN ('admin', 'compliance_officer', 'finance_head') 
        THEN ssn 
        ELSE concat('***-**-', substr(ssn, -4))
    END as ssn,
    
    -- Address partially masked
    CASE 
        WHEN current_user IN ('admin', 'aks', 'shipping_dept') 
        THEN address 
        ELSE concat(substr(address, 1, 10), '...')
    END as address,
    
    -- Non-sensitive data always visible
    city,
    state,
    zip_code,
    created_at,
    
    -- Account balance masked for non-finance
    CASE 
        WHEN current_user IN ('admin', 'aks') OR current_user LIKE 'finance_%'
        THEN account_balance 
        ELSE NULL
    END as account_balance
FROM hive.base.customers_raw;

-- Example 5: Credit card masking

CREATE OR REPLACE VIEW hive.base.payments_secured AS
SELECT 
    payment_id,
    customer_id,
    
    -- Show only last 4 digits for most users
    CASE 
        WHEN current_user IN ('admin', 'payment_processor') 
        THEN credit_card_number 
        ELSE concat('****-****-****-', substr(credit_card_number, -4))
    END as credit_card_number,
    
    -- CVV never shown except to payment processor
    CASE 
        WHEN current_user = 'payment_processor' 
        THEN cvv 
        ELSE '***'
    END as cvv,
    
    -- Expiry shown to authorized users
    CASE 
        WHEN current_user IN ('admin', 'payment_processor', 'billing_dept') 
        THEN card_expiry 
        ELSE NULL
    END as card_expiry,
    
    amount,
    payment_date,
    status
FROM hive.base.payments_raw;

-- ==========================================
-- DYNAMIC FILTERING WITH SESSION PROPERTIES
-- ==========================================

-- Example 6: Department-based filtering using session property

-- First, set a session property for the user's department
-- This would typically be set by the application layer
-- SET SESSION department = 'Engineering';

CREATE OR REPLACE VIEW hive.base.department_data AS
SELECT 
    employee_id,
    first_name,
    last_name,
    department,
    project_name,
    budget
FROM hive.base.projects_raw
WHERE 
    current_user IN ('admin', 'aks')
    -- Use session property if available
    OR department = CAST(current_setting('department', true) AS VARCHAR)
    -- Fallback to user's own data
    OR employee_id IN (
        SELECT employee_id FROM hive.base.employees_raw 
        WHERE email = concat(current_user, '@company.com')
    );

-- ==========================================
-- AUDIT TRAIL VIEWS
-- ==========================================

-- Example 7: Automatic audit logging

CREATE OR REPLACE VIEW hive.base.sensitive_data_access AS
SELECT 
    current_user as accessed_by,
    current_timestamp as access_time,
    'sensitive_data' as table_name,
    sd.*
FROM hive.base.sensitive_data_raw sd;

-- To track who accessed what:
-- SELECT DISTINCT accessed_by, access_time 
-- FROM hive.base.sensitive_data_access;

-- ==========================================
-- COMBINING MULTIPLE SECURITY LAYERS
-- ==========================================

-- Example 8: Multi-layered security (RLS + Column Masking + Time-based)

CREATE OR REPLACE VIEW hive.base.medical_records_secured AS
SELECT 
    record_id,
    
    -- Patient name masking
    CASE 
        WHEN current_user IN ('admin', 'doctor', 'nurse') 
        THEN patient_name 
        ELSE concat(substr(patient_name, 1, 1), '. ', substr(split_part(patient_name, ' ', -1), 1, 1), '***')
    END as patient_name,
    
    -- SSN masking
    CASE 
        WHEN current_user IN ('admin', 'billing_dept') 
        THEN ssn 
        ELSE concat('***-**-', substr(ssn, -4))
    END as ssn,
    
    -- Diagnosis visible to medical staff
    CASE 
        WHEN current_user IN ('admin', 'doctor', 'nurse') 
        THEN diagnosis 
        ELSE '***CONFIDENTIAL***'
    END as diagnosis,
    
    -- Treatment visible to medical staff
    CASE 
        WHEN current_user IN ('admin', 'doctor', 'nurse', 'pharmacist') 
        THEN treatment 
        ELSE '***CONFIDENTIAL***'
    END as treatment,
    
    visit_date,
    
    -- Cost only for billing and admin
    CASE 
        WHEN current_user IN ('admin', 'billing_dept') 
        THEN cost 
        ELSE NULL
    END as cost
FROM hive.base.medical_records_raw
WHERE 
    -- Admins see all records
    current_user IN ('admin')
    -- Doctors see their patients
    OR (current_user LIKE 'doctor_%' AND doctor_id = regexp_extract(current_user, '^doctor_(.+)', 1))
    -- Only records from last 7 years (HIPAA compliance)
    AND visit_date >= CURRENT_DATE - INTERVAL '7' YEAR;

-- ==========================================
-- USAGE EXAMPLES
-- ==========================================

-- Grant access to views (run as admin)
GRANT SELECT ON hive.base.employees_secured TO analyst;
GRANT SELECT ON hive.base.customers_masked TO GROUP analysts;
GRANT SELECT ON hive.base.sales_regional TO sales_east;

-- Revoke access to raw tables (run as admin)
REVOKE SELECT ON hive.base.employees_raw FROM analyst;
REVOKE SELECT ON hive.base.customers_raw FROM GROUP analysts;

-- ==========================================
-- TESTING EXAMPLES
-- ==========================================

-- Test as admin (sees everything)
-- SELECT * FROM hive.base.customers_masked WHERE customer_id = 1;

-- Test as analyst (sees masked data)
-- SELECT * FROM hive.base.customers_masked WHERE customer_id = 1;

-- Test regional access
-- SELECT * FROM hive.base.sales_regional WHERE region = 'EAST';

-- Test time-based filtering
-- SELECT COUNT(*) FROM hive.base.transactions_tiered 
-- WHERE transaction_date >= CURRENT_DATE - INTERVAL '30' DAY;

-- ==========================================
-- BEST PRACTICES
-- ==========================================

/*
1. Always use views for security-sensitive data
   - Raw tables should have restricted access
   - Secured views handle masking/filtering
   
2. Layer your security
   - Combine RBAC with RLS and column masking
   - Use multiple security checks when appropriate
   
3. Document your security rules
   - Add comments explaining why each rule exists
   - Document which roles can access what data
   
4. Audit regularly
   - Create audit views to track access
   - Review access patterns periodically
   
5. Test thoroughly
   - Test each user role's access
   - Verify both positive and negative cases
   
6. Handle NULL gracefully
   - Use COALESCE for default values
   - Consider how NULLs affect your filtering logic
   
7. Performance considerations
   - Complex views can impact query performance
   - Consider materialized views for frequently accessed data
   - Add appropriate indexes on underlying tables
   
8. Keep security policies in sync with application logic
   - Document dependencies between database and app security
   - Maintain consistency across all access points
*/

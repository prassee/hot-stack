-- ========================================
-- MANAGED TABLES vs EXTERNAL TABLES in Trino
-- ========================================

-- MANAGED TABLES:
-- - Trino/Hive controls the data lifecycle
-- - Data is stored in the warehouse directory (s3a://com.dldgv2/delta/)
-- - When you DROP the table, both metadata AND data are deleted
-- - Use when you want Trino to manage everything

-- EXTERNAL TABLES:
-- - You control the data location explicitly
-- - When you DROP the table, only metadata is deleted (data remains)
-- - Use when data is shared across systems or you want to preserve data

-- ========================================
-- CREATING MANAGED TABLES
-- ========================================

-- Method 1: Create a schema WITHOUT specifying location
-- This will use the default warehouse directory from hive-site.xml
CREATE SCHEMA IF NOT EXISTS hive.analytics;

-- Method 2: Create managed table (no external_location specified)
CREATE TABLE hive.analytics.customers (
    customer_id BIGINT,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    registration_date DATE,
    total_purchases DECIMAL(10, 2)
)
WITH (
    format = 'PARQUET'
);
-- This table will be stored at: s3a://com.dldgv2/delta/analytics/customers/

-- Insert data into managed table
INSERT INTO hive.analytics.customers VALUES
    (1, 'John', 'Doe', 'john.doe@example.com', DATE '2024-01-10', 1250.50),
    (2, 'Jane', 'Smith', 'jane.smith@example.com', DATE '2024-01-15', 890.25),
    (3, 'Bob', 'Johnson', 'bob.j@example.com', DATE '2024-02-01', 2100.00),
    (4, 'Alice', 'Williams', 'alice.w@example.com', DATE '2024-02-10', 450.75);

-- Query the managed table
SELECT * FROM hive.analytics.customers;

-- ========================================
-- MANAGED PARTITIONED TABLE
-- ========================================

CREATE TABLE hive.analytics.orders (
    order_id BIGINT,
    customer_id BIGINT,
    product_name VARCHAR,
    quantity INT,
    price DECIMAL(10, 2),
    order_date DATE
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['order_date']
);
-- Location: s3a://com.dldgv2/delta/analytics/orders/

-- Insert partitioned data
INSERT INTO hive.analytics.orders VALUES
    (101, 1, 'Laptop', 1, 999.99, DATE '2024-01-15'),
    (102, 2, 'Mouse', 2, 29.99, DATE '2024-01-15'),
    (103, 1, 'Keyboard', 1, 79.99, DATE '2024-01-16'),
    (104, 3, 'Monitor', 2, 299.99, DATE '2024-01-16'),
    (105, 4, 'Headphones', 1, 149.99, DATE '2024-02-01');

SELECT * FROM hive.analytics.orders WHERE order_date = DATE '2024-01-15';

-- ========================================
-- MANAGED TABLE WITH BUCKETING
-- ========================================

CREATE TABLE hive.analytics.products (
    product_id BIGINT,
    product_name VARCHAR,
    category VARCHAR,
    price DECIMAL(10, 2),
    in_stock BOOLEAN
)
WITH (
    format = 'PARQUET',
    bucketed_by = ARRAY['product_id'],
    bucket_count = 4
);

INSERT INTO hive.analytics.products VALUES
    (1, 'Laptop Pro', 'Electronics', 1299.99, true),
    (2, 'Wireless Mouse', 'Accessories', 39.99, true),
    (3, 'USB-C Cable', 'Accessories', 19.99, true),
    (4, '4K Monitor', 'Electronics', 499.99, false);

-- ========================================
-- CREATE TABLE AS SELECT (CTAS) - Managed
-- ========================================

-- Create a managed table from a query result
CREATE TABLE hive.analytics.high_value_customers AS
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    total_purchases
FROM hive.analytics.customers
WHERE total_purchases > 1000;

-- With specific format
CREATE TABLE hive.analytics.customer_summary
WITH (format = 'ORC')
AS
SELECT 
    COUNT(*) as total_customers,
    SUM(total_purchases) as total_revenue,
    AVG(total_purchases) as avg_purchase
FROM hive.analytics.customers;

-- ========================================
-- CHECKING TABLE PROPERTIES
-- ========================================

-- Show where the table is stored
SHOW CREATE TABLE hive.managed_db.customers;

-- Get table details
DESCRIBE hive.managed_db.customers;

-- List all tables
SHOW TABLES IN hive.managed_db;

-- ========================================
-- COMPARISON: External vs Managed Table
-- ========================================

-- External table (you specify location)
CREATE TABLE hive.base.external_users (
    user_id BIGINT,
    username VARCHAR
)
WITH (
    format = 'PARQUET',
    external_location = 's3a://com.dldgv2/base/external_users/'
);

-- Managed table (Trino decides location based on warehouse dir)
CREATE TABLE hive.managed_db.managed_users (
    user_id BIGINT,
    username VARCHAR
)
WITH (
    format = 'PARQUET'
);

-- Key difference when dropping:
-- DROP TABLE hive.base.external_users;        -- Only deletes metadata, data remains in S3
-- DROP TABLE hive.managed_db.managed_users;   -- Deletes BOTH metadata AND data from S3

-- ========================================
-- ALTERING MANAGED TABLES
-- ========================================

-- Add a column
ALTER TABLE hive.managed_db.customers ADD COLUMN phone VARCHAR;

-- Rename a column (if supported by your Hive version)
-- ALTER TABLE hive.managed_db.customers RENAME COLUMN phone TO phone_number;

-- ========================================
-- SUMMARY
-- ========================================

-- Managed Tables:
--   ✓ No need to specify external_location
--   ✓ Data stored in warehouse dir: s3a://com.dldgv2/delta/
--   ✓ DROP TABLE removes both data and metadata
--   ✓ Simpler for standard use cases

-- External Tables:
--   ✓ Must specify external_location
--   ✓ Data stored where you specify
--   ✓ DROP TABLE removes only metadata
--   ✓ Better for shared data or data preservation

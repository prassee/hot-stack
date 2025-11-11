-- Example SQL queries to create a table in Trino and save it in MinIO
-- Connect to Trino: podman exec -it trino trino

-- Step 1: Create a schema (database) in the hive catalog
-- The location should point to your MinIO bucket


CREATE SCHEMA IF NOT EXISTS hive.base WITH (location = 's3a://com.dldgv2/base/');

-- Step 2: Create a table that will be stored in MinIO as Parquet files
CREATE TABLE IF NOT EXISTS hive.base.users (
    user_id BIGINT,
    username VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP,
    is_active BOOLEAN
)
WITH (
    format = 'PARQUET',
    external_location = 's3a://com.dldgv2/base/users/'
);

-- Step 3: Insert sample data into the table
INSERT INTO hive.base.users VALUES
    (1, 'alice', 'alice@example.com', TIMESTAMP '2024-01-15 10:30:00', true),
    (2, 'bob', 'bob@example.com', TIMESTAMP '2024-02-20 14:45:00', true),
    (3, 'charlie', 'charlie@example.com', TIMESTAMP '2024-03-10 09:15:00', false),
    (4, 'diana', 'diana@example.com', TIMESTAMP '2024-04-05 16:20:00', true);

-- Step 4: Query the table to verify data
SELECT * FROM hive.base.users;

-- Step 5: View table properties
SHOW CREATE TABLE hive.base.users;

-- Additional Examples:

-- Create a partitioned table (recommended for large datasets)
CREATE TABLE IF NOT EXISTS hive.base.sales (
    sale_id BIGINT,
    product_name VARCHAR,
    amount DECIMAL(10, 2),
    sale_date DATE
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['sale_date'],
    external_location = 's3a://com.dldgv2/base/sales/'
);

-- Insert data into partitioned table
INSERT INTO hive.base.sales VALUES
    (1, 'Laptop', 999.99, DATE '2024-01-15'),
    (2, 'Mouse', 29.99, DATE '2024-01-15'),
    (3, 'Keyboard', 79.99, DATE '2024-01-16'),
    (4, 'Monitor', 299.99, DATE '2024-01-16');

-- Query partitioned table
SELECT * FROM hive.base.sales WHERE sale_date = DATE '2024-01-15';

-- Create table from query (CTAS - Create Table As Select)
CREATE TABLE hive.base.active_users
WITH (
    format = 'PARQUET',
    external_location = 's3a://com.dldgv2/base/active_users/'
)
AS
SELECT user_id, username, email, created_at
FROM hive.base.users
WHERE is_active = true;

-- Show all tables in the schema
SHOW TABLES IN hive.base;

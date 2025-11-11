-- ===================================================================
-- Practical Example: Applying RLS to an Existing Products Table
-- ===================================================================

-- Assume you already have this table with data:
-- hive.base.products (existing table, do NOT recreate!)

-- Step 1: Check existing table structure
DESCRIBE hive.base.products;

-- Expected columns:
-- product_id, name, category, price, cost, margin, supplier, stock_level

-- Step 2: Create protected views WITHOUT modifying the base table

-- ===================================================================
-- View 1: Public view (no sensitive pricing data)
-- ===================================================================
CREATE OR REPLACE VIEW hive.base.products_public AS
SELECT 
    product_id,
    name,
    category,
    price,              -- Show price
    -- cost hidden
    -- margin hidden
    -- supplier hidden
    stock_level
FROM hive.base.products
WHERE stock_level > 0;  -- Only show in-stock items

-- ===================================================================
-- View 2: Sales team view (pricing but not cost/margin)
-- ===================================================================
CREATE OR REPLACE VIEW hive.base.products_sales AS
SELECT 
    product_id,
    name,
    category,
    price,
    stock_level,
    supplier
FROM hive.base.products;

-- ===================================================================
-- View 3: Finance team view (cost analysis)
-- ===================================================================
CREATE OR REPLACE VIEW hive.base.products_finance AS
SELECT 
    product_id,
    name,
    category,
    price,
    cost,
    margin,
    (price - cost) as profit,
    ROUND(margin * 100, 2) as margin_pct
FROM hive.base.products;

-- ===================================================================
-- View 4: Inventory team view (stock levels only)
-- ===================================================================
CREATE OR REPLACE VIEW hive.base.products_inventory AS
SELECT 
    product_id,
    name,
    category,
    stock_level,
    CASE 
        WHEN stock_level = 0 THEN 'Out of Stock'
        WHEN stock_level < 10 THEN 'Low Stock'
        WHEN stock_level < 50 THEN 'Normal'
        ELSE 'High Stock'
    END as stock_status
FROM hive.base.products;

-- ===================================================================
-- View 5: Category manager view (department-specific)
-- ===================================================================

-- Electronics category manager
CREATE OR REPLACE VIEW hive.base.products_electronics AS
SELECT * FROM hive.base.products
WHERE category = 'Electronics';

-- Clothing category manager
CREATE OR REPLACE VIEW hive.base.products_clothing AS
SELECT * FROM hive.base.products
WHERE category = 'Clothing';

-- Home Goods category manager
CREATE OR REPLACE VIEW hive.base.products_home AS
SELECT * FROM hive.base.products
WHERE category = 'Home Goods';

-- ===================================================================
-- Step 3: Verify views are created
-- ===================================================================
SHOW TABLES IN hive.base LIKE '%products%';

-- ===================================================================
-- Step 4: Test the views
-- ===================================================================

-- Test public view (no sensitive data)
SELECT * FROM hive.base.products_public LIMIT 5;

-- Test finance view (all pricing data)
SELECT * FROM hive.base.products_finance WHERE margin > 0.3 LIMIT 5;

-- Test category view (filtered rows)
SELECT COUNT(*) as electronics_count 
FROM hive.base.products_electronics;

-- ===================================================================
-- Step 5: Update rules.json Configuration
-- ===================================================================

/*
Add these rules to conf/trino/rules.json:

{
  "tables": [
    // Admins have full access to base table
    {
      "user": "admin|aks",
      "catalog": "hive",
      "schema": "base",
      "table": "products",
      "privileges": ["SELECT", "INSERT", "UPDATE", "DELETE", "OWNERSHIP"]
    },
    
    // Block analysts from base products table
    {
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "products",
      "privileges": []
    },
    
    // Analysts can access public view
    {
      "group": "analysts",
      "catalog": "hive",
      "schema": "base",
      "table": "products_public",
      "privileges": ["SELECT"]
    },
    
    // Sales team access
    {
      "user": "sales_user",
      "catalog": "hive",
      "schema": "base",
      "table": "products_sales",
      "privileges": ["SELECT"]
    },
    
    // Finance team access
    {
      "user": "finance_user",
      "catalog": "hive",
      "schema": "base",
      "table": "products_finance",
      "privileges": ["SELECT"]
    },
    
    // Inventory team access
    {
      "user": "inventory_user",
      "catalog": "hive",
      "schema": "base",
      "table": "products_inventory",
      "privileges": ["SELECT"]
    },
    
    // Category managers access their category views
    {
      "user": "electronics_manager",
      "catalog": "hive",
      "schema": "base",
      "table": "products_electronics",
      "privileges": ["SELECT", "INSERT", "UPDATE"]
    }
  ]
}
*/

-- ===================================================================
-- Step 6: Verification Queries (run as different users)
-- ===================================================================

-- As admin (should see everything)
-- SELECT * FROM hive.base.products;

-- As analyst (should fail on base table)
-- SELECT * FROM hive.base.products;  -- Access Denied

-- As analyst (should succeed on public view)
-- SELECT * FROM hive.base.products_public;  -- Success

-- As finance_user (should see cost/margin)
-- SELECT * FROM hive.base.products_finance;  -- Success

-- Verify row filtering
-- SELECT COUNT(*) FROM hive.base.products;              -- All products
-- SELECT COUNT(*) FROM hive.base.products_electronics;  -- Only electronics

-- ===================================================================
-- Additional Examples: Dynamic User-Based Filtering
-- ===================================================================

-- View 6: Show products based on user's assigned region
CREATE OR REPLACE VIEW hive.base.products_my_region AS
SELECT p.*
FROM hive.base.products p
JOIN hive.base.user_regions ur ON ur.username = CURRENT_USER
WHERE p.region = ur.region;

-- View 7: Show only products user has permission to edit
CREATE OR REPLACE VIEW hive.base.products_my_portfolio AS
SELECT p.*
FROM hive.base.products p
JOIN hive.base.product_assignments pa ON pa.product_id = p.product_id
WHERE pa.assigned_to = CURRENT_USER;

-- ===================================================================
-- Step 7: Document the Views
-- ===================================================================

COMMENT ON VIEW hive.base.products_public IS 
'Public-facing product catalog. Excludes out-of-stock items and sensitive pricing data.';

COMMENT ON VIEW hive.base.products_finance IS 
'Financial analysis view with cost, margin, and profit calculations. Finance team only.';

COMMENT ON VIEW hive.base.products_inventory IS 
'Inventory management view with stock levels and status. Inventory team only.';

-- ===================================================================
-- Important Notes
-- ===================================================================

/*
1. The base table 'hive.base.products' is NEVER modified
2. All existing data remains unchanged
3. Applications can be gradually migrated to use views
4. Views can be created/dropped without affecting base table
5. Multiple views can coexist with different access levels
6. Performance: views are computed at query time

Migration Strategy:
- Week 1: Create views alongside base table access
- Week 2: Update applications to use views
- Week 3: Remove direct base table access for non-admins
- Week 4: Monitor and optimize view performance

Rollback Plan:
- Drop views: DROP VIEW hive.base.products_public;
- Restore direct access in rules.json
- No data loss, instant rollback
*/

-- ===================================================================
-- Performance Optimization (Optional)
-- ===================================================================

-- If views are queried frequently, consider materializing them
-- Note: This creates a new table with a snapshot of the view

-- CREATE TABLE hive.base.products_public_materialized AS
-- SELECT * FROM hive.base.products_public;

-- Refresh materialized view periodically:
-- DELETE FROM hive.base.products_public_materialized;
-- INSERT INTO hive.base.products_public_materialized
-- SELECT * FROM hive.base.products_public;

-- ===================================================================
-- Monitoring and Auditing
-- ===================================================================

-- Check who is accessing which views
SELECT 
    user,
    query,
    tables,
    created
FROM system.runtime.queries
WHERE query LIKE '%products%'
ORDER BY created DESC
LIMIT 20;

-- Count queries by view
SELECT 
    CASE 
        WHEN query LIKE '%products_public%' THEN 'products_public'
        WHEN query LIKE '%products_finance%' THEN 'products_finance'
        WHEN query LIKE '%products_sales%' THEN 'products_sales'
        WHEN query LIKE '%products_inventory%' THEN 'products_inventory'
        ELSE 'base_table'
    END as view_name,
    COUNT(*) as query_count
FROM system.runtime.queries
WHERE query LIKE '%products%'
GROUP BY 1
ORDER BY 2 DESC;

-- ===================================================================
-- Summary
-- ===================================================================

/*
What we did:
✓ Created 7 protected views on top of existing 'products' table
✓ Each view provides different level of access/filtering
✓ No changes to base table structure or data
✓ No data migration required
✓ Can be applied while system is running
✓ Fully reversible

Access Control:
✓ Admins: Full access to base products table
✓ Analysts: products_public only (limited columns, in-stock only)
✓ Sales: products_sales (all products, no cost/margin)
✓ Finance: products_finance (full pricing analysis)
✓ Inventory: products_inventory (stock levels only)
✓ Category Managers: products_electronics/clothing/home (filtered)

Performance:
- Views add minimal overhead for simple filtering
- Consider materializing for complex views
- Monitor query patterns and optimize accordingly

Next Steps:
1. Review and adjust view definitions as needed
2. Update rules.json with access controls
3. Test thoroughly with different users
4. Update application queries to use views
5. Monitor performance and access patterns
6. Document views for team members
*/

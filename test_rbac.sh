#!/usr/bin/env bash

# RBAC Testing Script for Trino
# Tests various access control scenarios

set -e

echo "=========================================="
echo "Trino RBAC Testing Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
run_test() {
    local test_name="$1"
    local user="$2"
    local password="$3"
    local query="$4"
    local should_succeed="$5"
    
    echo -e "${YELLOW}Test: $test_name${NC}"
    echo "User: $user"
    echo "Query: $query"
    
    # Run query and capture result
    result=$(podman exec -i trino trino --user "$user" --password <<< "$password
$query" 2>&1 || true)
    
    if echo "$result" | grep -qi "denied\|error\|failed"; then
        if [ "$should_succeed" = "false" ]; then
            echo -e "${GREEN}✓ PASS${NC} - Access correctly denied"
        else
            echo -e "${RED}✗ FAIL${NC} - Should have succeeded but was denied"
            echo "Error: $result"
        fi
    else
        if [ "$should_succeed" = "true" ]; then
            echo -e "${GREEN}✓ PASS${NC} - Access granted as expected"
        else
            echo -e "${RED}✗ FAIL${NC} - Should have been denied but succeeded"
        fi
    fi
    echo ""
}

echo "Starting RBAC tests..."
echo ""

# Test 1: Admin should be able to create schema
run_test \
    "Admin creates schema" \
    "admin" \
    "admin123" \
    "CREATE SCHEMA IF NOT EXISTS hive.rbac_test" \
    "true"

# Test 2: Analyst should NOT be able to create schema
run_test \
    "Analyst tries to create schema (should fail)" \
    "analyst" \
    "analyst123" \
    "CREATE SCHEMA IF NOT EXISTS hive.rbac_test_analyst" \
    "false"

# Test 3: Admin creates test table
echo -e "${YELLOW}Setting up test table...${NC}"
podman exec -i trino trino --user admin --password <<EOF > /dev/null 2>&1 || true
admin123
CREATE SCHEMA IF NOT EXISTS hive.rbac_test;
CREATE TABLE IF NOT EXISTS hive.rbac_test.test_data (
    id BIGINT,
    name VARCHAR,
    salary DECIMAL(10,2)
) WITH (format = 'PARQUET');
INSERT INTO hive.rbac_test.test_data VALUES (1, 'Alice', 75000), (2, 'Bob', 85000);
EOF
echo -e "${GREEN}✓ Test table created${NC}"
echo ""

# Test 4: Data engineer should be able to INSERT
run_test \
    "Data engineer inserts data" \
    "alice" \
    "alice123" \
    "INSERT INTO hive.base.users VALUES (9999, 'test_rbac', 'rbac@test.com', CURRENT_TIMESTAMP, true)" \
    "true"

# Test 5: Analyst should be able to SELECT
run_test \
    "Analyst reads data" \
    "analyst" \
    "analyst123" \
    "SELECT COUNT(*) FROM hive.base.users" \
    "true"

# Test 6: Analyst should NOT be able to INSERT
run_test \
    "Analyst tries to insert (should fail)" \
    "analyst" \
    "analyst123" \
    "INSERT INTO hive.base.users VALUES (9998, 'test', 'test@test.com', CURRENT_TIMESTAMP, true)" \
    "false"

# Test 7: Analyst should NOT be able to DELETE
run_test \
    "Analyst tries to delete (should fail)" \
    "analyst" \
    "analyst123" \
    "DELETE FROM hive.base.users WHERE user_id = 9999" \
    "false"

# Test 8: Admin should be able to DELETE
run_test \
    "Admin deletes test data" \
    "admin" \
    "admin123" \
    "DELETE FROM hive.base.users WHERE user_id = 9999" \
    "true"

# Test 9: Guest should have read-only access to TPCH
run_test \
    "Guest reads TPCH data" \
    "guest" \
    "guest123" \
    "SELECT COUNT(*) FROM tpch.tiny.nation" \
    "true"

# Test 10: Guest should NOT access hive catalog
run_test \
    "Guest tries to access hive (should fail)" \
    "guest" \
    "guest123" \
    "SELECT COUNT(*) FROM hive.base.users" \
    "false"

# Test 11: User 'aks' (admin group) should have full access
run_test \
    "AKS user creates schema" \
    "aks" \
    "aks" \
    "CREATE SCHEMA IF NOT EXISTS hive.aks_test" \
    "true"

# Test 12: Bob (specific table permissions) can access allowed tables
run_test \
    "Bob selects from allowed table" \
    "bob" \
    "bob123" \
    "SHOW TABLES IN hive.base" \
    "true"

echo "=========================================="
echo "RBAC Testing Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "- Authentication: ENABLED"
echo "- Access Control: FILE-BASED RBAC"
echo "- Rules File: conf/trino/rules.json"
echo "- Groups File: conf/trino/groups.txt"
echo ""
echo "To modify policies:"
echo "  1. Edit conf/trino/rules.json"
echo "  2. Changes take effect within 5 seconds (auto-reload)"
echo ""
echo "To add users to groups:"
echo "  1. Edit conf/trino/groups.txt"
echo "  2. Changes take effect within 5 seconds (auto-reload)"
echo ""

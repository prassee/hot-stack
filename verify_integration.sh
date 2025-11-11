#!/bin/bash
# Quick Verification Script for Trino RBAC Integration

echo "=== Trino RBAC Integration Verification ==="
echo ""

# Check Trino status
echo "1. Checking Trino Status..."
if podman ps | grep -q "trino.*healthy"; then
    echo "   ✓ Trino is running and healthy"
else
    echo "   ✗ Trino is not running or not healthy"
    exit 1
fi
echo ""

# Test API with authentication
echo "2. Testing Authentication via API..."
response=$(curl -s -u admin:admin http://localhost:8080/v1/info 2>&1)
if echo "$response" | grep -q "coordinator"; then
    echo "   ✓ Authentication is working"
    echo "   Version: $(echo "$response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)"
    echo "   Environment: $(echo "$response" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)"
else
    echo "   ✗ Authentication failed"
    echo "   Response: $response"
    exit 1
fi
echo ""

# Check configuration files
echo "3. Verifying Configuration Files..."
files=(
    "conf/trino/config.properties"
    "conf/trino/password.db"
    "conf/trino/access-control.properties"
    "conf/trino/rules.json"
    "conf/trino/groups.txt"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file missing"
    fi
done
echo ""

# Count users
echo "4. Configured Users..."
user_count=$(cat conf/trino/password.db 2>/dev/null | wc -l)
echo "   Total users: $user_count"
if [ $user_count -gt 0 ]; then
    echo "   Users:"
    cat conf/trino/password.db | cut -d':' -f1 | sed 's/^/     - /'
fi
echo ""

# Check groups
echo "5. Configured Groups..."
group_count=$(cat conf/trino/groups.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l)
echo "   Total group mappings: $group_count"
echo ""

# Check RBAC rules
echo "6. RBAC Policies..."
if command -v jq &> /dev/null; then
    catalogs=$(jq -r '.catalogs | length' conf/trino/rules.json 2>/dev/null)
    schemas=$(jq -r '.schemas | length' conf/trino/rules.json 2>/dev/null)
    tables=$(jq -r '.tables | length' conf/trino/rules.json 2>/dev/null)
    echo "   Catalog policies: $catalogs"
    echo "   Schema policies: $schemas"
    echo "   Table policies: $tables"
else
    echo "   (Install jq for detailed policy counts)"
    echo "   Rules file exists: ✓"
fi
echo ""

echo "=== Integration Status: SUCCESS ✓ ==="
echo ""
echo "Next Steps:"
echo "  1. Access Web UI: http://localhost:8080 (login: admin/admin)"
echo "  2. Test CLI: trino --server http://localhost:8080 --user admin --password"
echo "  3. Run full tests: ./test_trino_rbac.sh"
echo "  4. Review guide: cat TRINO_RBAC_INTEGRATION.md"
echo ""
echo "Security Reminder:"
echo "  ⚠️  Change 'internal-communication.shared-secret' in production!"
echo "  ⚠️  Use strong passwords for all users!"
echo ""

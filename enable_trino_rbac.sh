#!/bin/bash
# Enable Trino RBAC Integration Script

set -e

echo "=== Enabling Trino RBAC Integration ==="
echo ""

# Check if required files exist
echo "Checking RBAC configuration files..."
required_files=(
    "conf/trino/config.properties"
    "conf/trino/password-authenticator.properties"
    "conf/trino/access-control.properties"
    "conf/trino/rules.json"
    "conf/trino/group-provider.properties"
    "conf/trino/groups.txt"
    "conf/trino/password.db"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ Found: $file"
    else
        echo "✗ Missing: $file"
        exit 1
    fi
done

echo ""
echo "All RBAC configuration files are in place!"
echo ""

# Show current configuration
echo "=== Current Trino Configuration ==="
echo "Authentication: PASSWORD"
echo "Access Control: file-based RBAC"
echo ""

# Display configured users
echo "=== Configured Users ==="
if [ -f "conf/trino/password.db" ]; then
    echo "Users in password.db:"
    cat conf/trino/password.db | cut -d':' -f1 | sed 's/^/  - /'
fi
echo ""

# Display group mappings
echo "=== Group Mappings ==="
if [ -f "conf/trino/groups.txt" ]; then
    echo "User groups:"
    cat conf/trino/groups.txt | sed 's/^/  /'
fi
echo ""

# Restart Trino to apply changes
echo "=== Restarting Trino ==="
echo "Stopping Trino..."
podman stop trino

echo "Starting Trino with RBAC enabled..."
podman start trino

echo ""
echo "Waiting for Trino to start..."
sleep 10

# Check if Trino is running
if podman ps | grep -q trino; then
    echo "✓ Trino is running"
else
    echo "✗ Trino failed to start"
    echo ""
    echo "Check logs with: podman logs trino"
    exit 1
fi

echo ""
echo "=== RBAC Integration Complete! ==="
echo ""
echo "Next Steps:"
echo "1. Test authentication: trino --server http://localhost:8080 --user admin --password"
echo "2. Test RBAC policies with different users (admin, alice, bob, analyst)"
echo "3. Verify access control is working as expected"
echo ""
echo "Default Users and Passwords:"
echo "  admin:admin (Full access)"
echo "  aks:aks (Admin access)"
echo "  alice:alice (Data Engineer)"
echo "  bob:bob (Data Engineer)"
echo "  analyst:analyst (Read-only)"
echo ""
echo "Access Trino Web UI: http://localhost:8080"
echo "(Use any username/password from above)"

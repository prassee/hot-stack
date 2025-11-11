#!/usr/bin/env bash

# Enable RBAC on Trino
# This script sets up both authentication and authorization

set -e

echo "=========================================="
echo "Enabling RBAC on Trino"
echo "=========================================="
echo ""

# Step 1: Check if password file exists
if [ ! -f "conf/trino/password.db" ]; then
    echo "Creating password file with default users..."
    podman run --rm httpd:alpine htpasswd -nbB -C 10 admin admin123 > conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 aks aks >> conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 alice alice123 >> conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 bob bob123 >> conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 analyst analyst123 >> conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 john john123 >> conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 jane jane123 >> conf/trino/password.db
    podman run --rm httpd:alpine htpasswd -nbB -C 10 guest guest123 >> conf/trino/password.db
    echo "✓ Password file created"
else
    echo "✓ Password file already exists"
fi

echo ""

# Step 2: Check if RBAC files exist
echo "Checking RBAC configuration files..."

if [ -f "conf/trino/access-control.properties" ]; then
    echo "✓ access-control.properties exists"
else
    echo "✗ access-control.properties missing!"
    exit 1
fi

if [ -f "conf/trino/rules.json" ]; then
    echo "✓ rules.json exists"
else
    echo "✗ rules.json missing!"
    exit 1
fi

if [ -f "conf/trino/group-provider.properties" ]; then
    echo "✓ group-provider.properties exists"
else
    echo "✗ group-provider.properties missing!"
    exit 1
fi

if [ -f "conf/trino/groups.txt" ]; then
    echo "✓ groups.txt exists"
else
    echo "✗ groups.txt missing!"
    exit 1
fi

echo ""

# Step 3: Verify config.properties has authentication enabled
if grep -q "^http-server.authentication.type=PASSWORD" conf/trino/config.properties; then
    echo "✓ Authentication already enabled in config.properties"
else
    echo "Enabling authentication in config.properties..."
    # Remove any existing authentication lines
    sed -i '/^http-server.authentication.type=/d' conf/trino/config.properties
    # Add after security configuration
    sed -i '/^# Security configuration/a\\n# Authentication\nhttp-server.authentication.type=PASSWORD\n\n# Access Control (RBAC)\naccess-control.name=file' conf/trino/config.properties
    echo "✓ Authentication enabled"
fi

echo ""

# Step 4: Restart Trino
echo "Restarting Trino to apply RBAC configuration..."
podman-compose restart trino

echo ""
echo "Waiting for Trino to start (20 seconds)..."
sleep 20

# Step 5: Verify Trino is running
if podman ps | grep -q "trino.*Up"; then
    echo "✓ Trino is running"
else
    echo "✗ Trino failed to start. Check logs: podman logs trino"
    exit 1
fi

echo ""
echo "=========================================="
echo "RBAC Setup Complete!"
echo "=========================================="
echo ""
echo "Default Users and Groups:"
echo ""
echo "Administrators (full access):"
echo "  • admin / admin123 (group: admins, data_engineers)"
echo "  • aks / aks (group: admins, data_engineers)"
echo ""
echo "Data Engineers (manage hive catalog):"
echo "  • alice / alice123 (group: data_engineers)"
echo "  • bob / bob123 (group: data_engineers)"
echo ""
echo "Analysts (read-only on hive.base):"
echo "  • analyst / analyst123 (group: analysts)"
echo "  • john / john123 (group: analysts)"
echo "  • jane / jane123 (group: analysts)"
echo ""
echo "Guests (read-only on tpch):"
echo "  • guest / guest123 (group: guests)"
echo ""
echo "Connect with:"
echo "  podman exec -it trino trino --user admin --password"
echo ""
echo "Test RBAC:"
echo "  ./test_rbac.sh"
echo ""
echo "Configuration files:"
echo "  • conf/trino/rules.json - RBAC policies"
echo "  • conf/trino/groups.txt - User-group mappings"
echo "  • conf/trino/password.db - User passwords"
echo ""
echo "Note: Changes to rules.json and groups.txt are"
echo "automatically reloaded every 5 seconds."
echo ""

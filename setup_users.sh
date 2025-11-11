#!/usr/bin/env bash

# Trino User Setup Script
# This script enables password authentication and creates default users

set -e

echo "=========================================="
echo "Trino User Authentication Setup"
echo "=========================================="
echo ""

# Create password file with default users
echo "Creating password file with default users..."
echo "Users: admin, alice, bob, analyst"
echo ""

# Use httpd container to generate bcrypt passwords
podman run --rm httpd:alpine htpasswd -nbB -C 10 admin admin123 > conf/trino/password.db
podman run --rm httpd:alpine htpasswd -nbB -C 10 alice alice123 >> conf/trino/password.db
podman run --rm httpd:alpine htpasswd -nbB -C 10 bob bob123 >> conf/trino/password.db
podman run --rm httpd:alpine htpasswd -nbB -C 10 analyst analyst123 >> conf/trino/password.db

echo "✓ Password file created at conf/trino/password.db"
echo ""

# Check if authentication is already enabled
if grep -q "^http-server.authentication.type=PASSWORD" conf/trino/config.properties; then
    echo "✓ Authentication already enabled in config.properties"
else
    echo "Adding authentication to config.properties..."
    echo "" >> conf/trino/config.properties
    echo "# Authentication" >> conf/trino/config.properties
    echo "http-server.authentication.type=PASSWORD" >> conf/trino/config.properties
    echo "✓ Authentication enabled in config.properties"
fi

echo ""
echo "Restarting Trino to apply changes..."
podman-compose restart trino

echo ""
echo "Waiting for Trino to start (20 seconds)..."
sleep 20

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Default Users Created:"
echo "  • admin / admin123     (full access)"
echo "  • alice / alice123     (analyst)"
echo "  • bob / bob123         (developer)"
echo "  • analyst / analyst123 (read-only)"
echo ""
echo "Connect using:"
echo "  podman exec -it trino trino --user admin --password"
echo ""
echo "Web UI: http://localhost:8080"
echo "  (You will be prompted to login)"
echo ""
echo "To add more users:"
echo "  podman run --rm httpd:alpine htpasswd -nbB -C 10 newuser password >> conf/trino/password.db"
echo ""

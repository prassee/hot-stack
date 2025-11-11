# Adding Users to Trino

## Current Setup
Your Trino instance currently has NO authentication enabled (open access). Here's how to add user authentication.

## Option 1: Password Authentication (File-Based) - Recommended for Development

### Step 1: Enable Authentication in config.properties

Add these lines to `/conf/trino/config.properties`:
```properties
http-server.authentication.type=PASSWORD
```

### Step 2: Create Password File

Trino uses bcrypt for password hashing. You need to create `/conf/trino/password.db` with entries in the format:
```
username:bcrypt_hashed_password
```

#### Using htpasswd (Easiest Method)
```bash
# Install htpasswd if not available
# On Ubuntu/Debian: sudo apt-get install apache2-utils
# On RHEL/CentOS: sudo yum install httpd-tools
# On macOS: brew install httpd

# Create password file with first user
htpasswd -B -C 10 -c conf/trino/password.db admin

# Add more users (without -c flag)
htpasswd -B -C 10 conf/trino/password.db alice
htpasswd -B -C 10 conf/trino/password.db bob
htpasswd -B -C 10 conf/trino/password.db analyst
```

#### Using Python (Alternative)
```python
import bcrypt

def create_password_entry(username, password):
    salt = bcrypt.gensalt(rounds=10)
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return f"{username}:{hashed.decode('utf-8')}"

# Create entries
print(create_password_entry("admin", "admin123"))
print(create_password_entry("alice", "alice123"))
print(create_password_entry("bob", "bob123"))
```

#### Using Docker/Podman Container
```bash
# Use a container with htpasswd installed
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 admin admin123

# Save output to password.db file
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 admin admin123 > conf/trino/password.db
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 alice alice123 >> conf/trino/password.db
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 bob bob123 >> conf/trino/password.db
```

### Step 3: Configure password-authenticator.properties

Already configured in `/conf/trino/password-authenticator.properties`:
```properties
password-authenticator.name=file
file.password-file=/etc/trino/password.db
```

### Step 4: Restart Trino
```bash
podman-compose restart trino
```

### Step 5: Connect with Authentication

**CLI:**
```bash
podman exec -it trino trino --user admin --password
# You'll be prompted to enter the password
```

**Python (with Trino connector):**
```python
from trino.dbapi import connect

conn = connect(
    host='localhost',
    port=8080,
    user='admin',
    auth=('admin', 'admin123'),  # (username, password)
    catalog='hive',
    schema='default'
)

cursor = conn.cursor()
cursor.execute('SELECT 1')
print(cursor.fetchall())
```

**JDBC URL:**
```
jdbc:trino://localhost:8080/hive/default?user=admin&password=admin123
```

---

## Option 2: LDAP Authentication (Enterprise)

For production environments with existing LDAP/Active Directory:

### config.properties
```properties
http-server.authentication.type=PASSWORD
```

### Create /conf/trino/password-authenticator.properties
```properties
password-authenticator.name=ldap
ldap.url=ldaps://ldap.example.com:636
ldap.user-bind-pattern=uid=${USER},ou=users,dc=example,dc=com
```

---

## Option 3: OAuth 2.0 / OpenID Connect (Modern SSO)

For integration with Google, GitHub, Okta, etc.

### config.properties
```properties
http-server.authentication.type=oauth2
http-server.https.enabled=true
http-server.https.port=8443
http-server.https.keystore.path=/etc/trino/keystore.jks
http-server.https.keystore.key=password
```

### Create /conf/trino/oauth2-authenticator.properties
```properties
oauth2.issuer=https://accounts.google.com
oauth2.client-id=your-client-id
oauth2.client-secret=your-client-secret
oauth2.auth-url=https://accounts.google.com/o/oauth2/v2/auth
oauth2.token-url=https://oauth2.googleapis.com/token
oauth2.jwks-url=https://www.googleapis.com/oauth2/v3/certs
oauth2.userinfo-url=https://openidconnect.googleapis.com/v1/userinfo
```

---

## User Management

### Adding Users
```bash
# Add new user to password file
htpasswd -B -C 10 conf/trino/password.db newuser

# OR append using container
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 newuser password123 >> conf/trino/password.db
```

### Removing Users
```bash
# Edit the password.db file and remove the user's line
vim conf/trino/password.db
```

### Changing Passwords
```bash
# Update existing user (without -c flag, but it will update)
htpasswd -B -C 10 conf/trino/password.db username
```

### No Restart Required
After modifying `password.db`, Trino automatically reloads the file. No restart needed!

---

## Authorization (Access Control)

After authentication is enabled, you can add authorization rules.

### Create /conf/trino/access-control.properties
```properties
access-control.name=file
security.config-file=/etc/trino/rules.json
```

### Create /conf/trino/rules.json
```json
{
  "catalogs": [
    {
      "user": "admin",
      "catalog": ".*",
      "allow": "all"
    },
    {
      "user": "analyst",
      "catalog": "hive",
      "allow": "read-only"
    },
    {
      "user": "bob",
      "catalog": "hive",
      "schema": "base",
      "allow": "all"
    },
    {
      "group": "analysts",
      "catalog": "hive",
      "allow": "read-only"
    }
  ],
  "schemas": [
    {
      "user": "admin",
      "schema": ".*",
      "owner": true
    }
  ],
  "tables": [
    {
      "user": "analyst",
      "privileges": ["SELECT"]
    },
    {
      "user": "admin",
      "privileges": ["SELECT", "INSERT", "DELETE", "UPDATE", "OWNERSHIP"]
    }
  ]
}
```

---

## Testing Authentication

### 1. Test Without Credentials (Should Fail)
```bash
curl http://localhost:8080/v1/info
# Should return 401 Unauthorized
```

### 2. Test With Credentials
```bash
curl -u admin:admin123 http://localhost:8080/v1/info
# Should return cluster info
```

### 3. Test Web UI
- Navigate to http://localhost:8080
- You should see a login page
- Enter username and password

---

## Quick Setup Script

Here's a complete script to enable basic authentication:

```bash
#!/bin/bash

# 1. Create users with htpasswd
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 admin admin123 > conf/trino/password.db
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 alice alice123 >> conf/trino/password.db
podman run --rm -it httpd:alpine htpasswd -nbB -C 10 bob bob123 >> conf/trino/password.db

# 2. Add authentication to config.properties
echo "" >> conf/trino/config.properties
echo "# Authentication" >> conf/trino/config.properties
echo "http-server.authentication.type=PASSWORD" >> conf/trino/config.properties

# 3. Restart Trino
podman-compose restart trino

# 4. Wait for startup
sleep 15

# 5. Test connection
podman exec -it trino trino --user admin --password
```

---

## Summary of User Types

| Username | Password | Use Case |
|----------|----------|----------|
| admin | admin123 | Full administrative access |
| alice | alice123 | Analyst with read-only access |
| bob | bob123 | Developer with specific schema access |
| analyst | analyst123 | Read-only analyst |

---

## Important Notes

1. **HTTPS Recommended for Production**: Password authentication should use HTTPS in production
2. **Password File Reloading**: Changes to password.db are automatically detected (no restart)
3. **Config Changes**: Changes to config.properties require a Trino restart
4. **Bcrypt Required**: Trino only supports bcrypt hashing (not MD5 or SHA)
5. **Cost Factor**: Use `-C 10` for bcrypt (good balance of security and performance)

---

## Troubleshooting

### "Authentication required"
- Ensure `http-server.authentication.type=PASSWORD` is in config.properties
- Restart Trino after adding this config

### "User authentication failed"
- Check password.db format (username:bcrypt_hash)
- Verify bcrypt hash was created correctly
- Ensure no extra whitespace in password.db

### "Cannot connect to Trino"
- Check Trino logs: `podman logs trino`
- Verify password-authenticator.properties exists
- Check that password.db path is correct in authenticator config

### Web UI doesn't prompt for login
- Clear browser cache
- Verify authentication is enabled in config.properties
- Check Trino logs for authentication errors

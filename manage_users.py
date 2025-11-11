#!/usr/bin/env python3
"""
Trino User Management Script
Add, remove, or update users in Trino password file
"""

import argparse
import sys
from pathlib import Path

import bcrypt


class TrinoUserManager:
    def __init__(self, password_file="conf/trino/password.db"):
        self.password_file = Path(password_file)

    def _hash_password(self, password, rounds=10):
        """Generate bcrypt hash for password"""
        salt = bcrypt.gensalt(rounds=rounds)
        hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
        return hashed.decode("utf-8")

    def _read_users(self):
        """Read existing users from password file"""
        if not self.password_file.exists():
            return {}

        users = {}
        with open(self.password_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and ":" in line:
                    username, password_hash = line.split(":", 1)
                    users[username] = password_hash
        return users

    def _write_users(self, users):
        """Write users to password file"""
        self.password_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.password_file, "w") as f:
            for username, password_hash in sorted(users.items()):
                f.write(f"{username}:{password_hash}\n")

    def add_user(self, username, password, force=False):
        """Add a new user"""
        users = self._read_users()

        if username in users and not force:
            print(f"Error: User '{username}' already exists. Use --force to update.")
            return False

        password_hash = self._hash_password(password)
        users[username] = password_hash
        self._write_users(users)

        action = "Updated" if username in self._read_users() else "Added"
        print(f"✓ {action} user: {username}")
        return True

    def remove_user(self, username):
        """Remove a user"""
        users = self._read_users()

        if username not in users:
            print(f"Error: User '{username}' not found.")
            return False

        del users[username]
        self._write_users(users)
        print(f"✓ Removed user: {username}")
        return True

    def list_users(self):
        """List all users"""
        users = self._read_users()

        if not users:
            print("No users found.")
            return

        print(f"\nUsers in {self.password_file}:")
        print("-" * 40)
        for username in sorted(users.keys()):
            print(f"  • {username}")
        print(f"\nTotal: {len(users)} user(s)")

    def change_password(self, username, new_password):
        """Change user password"""
        users = self._read_users()

        if username not in users:
            print(f"Error: User '{username}' not found.")
            return False

        password_hash = self._hash_password(new_password)
        users[username] = password_hash
        self._write_users(users)
        print(f"✓ Changed password for user: {username}")
        return True

    def verify_password(self, username, password):
        """Verify user password"""
        users = self._read_users()

        if username not in users:
            print(f"Error: User '{username}' not found.")
            return False

        password_hash = users[username].encode("utf-8")
        is_valid = bcrypt.checkpw(password.encode("utf-8"), password_hash)

        if is_valid:
            print(f"✓ Password is correct for user: {username}")
        else:
            print(f"✗ Password is incorrect for user: {username}")

        return is_valid


def main():
    parser = argparse.ArgumentParser(
        description="Manage Trino users",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Add a new user
  %(prog)s add-user alice password123
  
  # Remove a user
  %(prog)s remove-user alice
  
  # List all users
  %(prog)s list-users
  
  # Change password
  %(prog)s change-password alice newpassword123
  
  # Verify password
  %(prog)s verify-password alice password123
        """,
    )

    parser.add_argument(
        "--password-file",
        default="conf/trino/password.db",
        help="Path to password file (default: conf/trino/password.db)",
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Add user command
    add_parser = subparsers.add_parser("add-user", help="Add a new user")
    add_parser.add_argument("username", help="Username")
    add_parser.add_argument("password", help="Password")
    add_parser.add_argument(
        "--force", action="store_true", help="Update if user exists"
    )

    # Remove user command
    remove_parser = subparsers.add_parser("remove-user", help="Remove a user")
    remove_parser.add_argument("username", help="Username")

    # List users command
    subparsers.add_parser("list-users", help="List all users")

    # Change password command
    change_parser = subparsers.add_parser(
        "change-password", help="Change user password"
    )
    change_parser.add_argument("username", help="Username")
    change_parser.add_argument("new_password", help="New password")

    # Verify password command
    verify_parser = subparsers.add_parser(
        "verify-password", help="Verify user password"
    )
    verify_parser.add_argument("username", help="Username")
    verify_parser.add_argument("password", help="Password to verify")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    manager = TrinoUserManager(args.password_file)

    if args.command == "add-user":
        success = manager.add_user(args.username, args.password, args.force)
    elif args.command == "remove-user":
        success = manager.remove_user(args.username)
    elif args.command == "list-users":
        manager.list_users()
        success = True
    elif args.command == "change-password":
        success = manager.change_password(args.username, args.new_password)
    elif args.command == "verify-password":
        success = manager.verify_password(args.username, args.password)
    else:
        parser.print_help()
        return 1

    return 0 if success else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""
Semantic Kernel plugin that exposes MySQL database operations.

This plugin mirrors the tools provided by mysql_mcp_server.py and can be
attached to any AzureAIAgent to give it direct database access.

Environment variables:
    MYSQL_HOST      - MySQL server hostname (default: localhost)
    MYSQL_PORT      - MySQL server port (default: 3306)
    MYSQL_USER      - MySQL username
    MYSQL_PASSWORD  - MySQL password
    MYSQL_DATABASE  - Default database name
    MYSQL_SSL       - Enable SSL (default: true)
"""

import os
import json
import pymysql
import pymysql.cursors
from semantic_kernel.functions import kernel_function


def _get_connection(database: str | None = None) -> pymysql.Connection:
    ssl = {"ssl": True} if os.environ.get("MYSQL_SSL", "true").lower() == "true" else None
    config = {
        "host": os.environ.get("MYSQL_HOST", "localhost"),
        "port": int(os.environ.get("MYSQL_PORT", "3306")),
        "user": os.environ.get("MYSQL_USER", ""),
        "password": os.environ.get("MYSQL_PASSWORD", ""),
        "database": database or os.environ.get("MYSQL_DATABASE", ""),
        "cursorclass": pymysql.cursors.DictCursor,
        "autocommit": True,
    }
    if ssl:
        config["ssl"] = ssl
    return pymysql.connect(**config)


class MySQLPlugin:
    """Semantic Kernel plugin providing MySQL database access for Azure AI Foundry agents."""

    @kernel_function
    def list_databases(self) -> str:
        """List all accessible databases on the MySQL server."""
        with _get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SHOW DATABASES")
                rows = cursor.fetchall()
        return json.dumps([row["Database"] for row in rows])

    @kernel_function
    def list_tables(self, database: str = "") -> str:
        """
        List all tables in the specified database.

        Args:
            database: Database name. Uses the default database if empty.
        """
        db = database or os.environ.get("MYSQL_DATABASE", "")
        with _get_connection(db) as conn:
            with conn.cursor() as cursor:
                cursor.execute("SHOW TABLES")
                rows = cursor.fetchall()
        key = f"Tables_in_{db}"
        return json.dumps([row[key] for row in rows])

    @kernel_function
    def describe_table(self, table_name: str, database: str = "") -> str:
        """
        Return the schema of a table (columns, types, nullable, key, default).

        Args:
            table_name: Name of the table to describe.
            database: Database name. Uses the default database if empty.
        """
        db = database or os.environ.get("MYSQL_DATABASE", "")
        with _get_connection(db) as conn:
            with conn.cursor() as cursor:
                cursor.execute(f"DESCRIBE `{table_name}`")
                rows = cursor.fetchall()
        return json.dumps(rows, default=str)

    @kernel_function
    def execute_query(self, query: str, database: str = "") -> str:
        """
        Execute a read-only SELECT query and return results as JSON.

        Args:
            query: A valid SQL SELECT statement.
            database: Database name. Uses the default database if empty.
        """
        stripped = query.strip().upper()
        if not stripped.startswith("SELECT") and not stripped.startswith("SHOW") and not stripped.startswith("DESCRIBE"):
            return json.dumps({"error": "Only SELECT, SHOW, and DESCRIBE queries are allowed."})

        db = database or os.environ.get("MYSQL_DATABASE", "")
        with _get_connection(db) as conn:
            with conn.cursor() as cursor:
                cursor.execute(query)
                rows = cursor.fetchall()
        return json.dumps(rows, default=str)

    @kernel_function
    def execute_write(self, query: str, database: str = "") -> str:
        """
        Execute an INSERT, UPDATE, or DELETE statement.

        Args:
            query: A valid SQL write statement (INSERT, UPDATE, DELETE).
            database: Database name. Uses the default database if empty.
        """
        stripped = query.strip().upper()
        allowed = ("INSERT", "UPDATE", "DELETE")
        if not any(stripped.startswith(op) for op in allowed):
            return json.dumps({"error": "Only INSERT, UPDATE, and DELETE statements are allowed."})

        db = database or os.environ.get("MYSQL_DATABASE", "")
        with _get_connection(db) as conn:
            with conn.cursor() as cursor:
                cursor.execute(query)
                affected = cursor.rowcount
                last_id = cursor.lastrowid
        return json.dumps({"affected_rows": affected, "last_insert_id": last_id})

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""
MySQL MCP Server for Azure AI Foundry agents.

Exposes MySQL database operations as MCP tools that can be consumed
by any MCP-compatible client or Azure AI Foundry agent.

Usage:
    python -m mcp.mysql_mcp_server

Environment variables:
    MYSQL_HOST      - MySQL server hostname (default: localhost)
    MYSQL_PORT      - MySQL server port (default: 3306)
    MYSQL_USER      - MySQL username
    MYSQL_PASSWORD  - MySQL password
    MYSQL_DATABASE  - Default database name
"""

import os
import json
import pymysql
import pymysql.cursors
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("mysql-mcp-server")

MYSQL_CONFIG = {
    "host": os.environ.get("MYSQL_HOST", "localhost"),
    "port": int(os.environ.get("MYSQL_PORT", "3306")),
    "user": os.environ.get("MYSQL_USER", ""),
    "password": os.environ.get("MYSQL_PASSWORD", ""),
    "database": os.environ.get("MYSQL_DATABASE", ""),
    "cursorclass": pymysql.cursors.DictCursor,
    "autocommit": True,
    "ssl": {"ssl": True} if os.environ.get("MYSQL_SSL", "true").lower() == "true" else None,
}


def _get_connection(database: str | None = None) -> pymysql.Connection:
    config = {k: v for k, v in MYSQL_CONFIG.items() if v is not None}
    if database:
        config["database"] = database
    return pymysql.connect(**config)


@mcp.tool()
def list_databases() -> str:
    """List all accessible databases on the MySQL server."""
    with _get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute("SHOW DATABASES")
            rows = cursor.fetchall()
    return json.dumps([row["Database"] for row in rows])


@mcp.tool()
def list_tables(database: str = "") -> str:
    """
    List all tables in the specified database.

    Args:
        database: Database name. Uses the default database if empty.
    """
    db = database or MYSQL_CONFIG.get("database", "")
    with _get_connection(db) as conn:
        with conn.cursor() as cursor:
            cursor.execute("SHOW TABLES")
            rows = cursor.fetchall()
    key = f"Tables_in_{db}"
    return json.dumps([row[key] for row in rows])


@mcp.tool()
def describe_table(table_name: str, database: str = "") -> str:
    """
    Return the schema of a table (columns, types, nullable, key, default).

    Args:
        table_name: Name of the table to describe.
        database: Database name. Uses the default database if empty.
    """
    db = database or MYSQL_CONFIG.get("database", "")
    with _get_connection(db) as conn:
        with conn.cursor() as cursor:
            cursor.execute(f"DESCRIBE `{table_name}`")
            rows = cursor.fetchall()
    return json.dumps(rows, default=str)


@mcp.tool()
def execute_query(query: str, database: str = "") -> str:
    """
    Execute a read-only SELECT query and return the results as JSON.

    Args:
        query: A valid SQL SELECT statement.
        database: Database name. Uses the default database if empty.
    """
    stripped = query.strip().upper()
    if not stripped.startswith("SELECT") and not stripped.startswith("SHOW") and not stripped.startswith("DESCRIBE"):
        return json.dumps({"error": "Only SELECT, SHOW, and DESCRIBE queries are allowed."})

    db = database or MYSQL_CONFIG.get("database", "")
    with _get_connection(db) as conn:
        with conn.cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
    return json.dumps(rows, default=str)


@mcp.tool()
def execute_write(query: str, database: str = "") -> str:
    """
    Execute an INSERT, UPDATE, or DELETE statement and return affected row count.

    Args:
        query: A valid SQL write statement (INSERT, UPDATE, DELETE).
        database: Database name. Uses the default database if empty.
    """
    stripped = query.strip().upper()
    allowed = ("INSERT", "UPDATE", "DELETE")
    if not any(stripped.startswith(op) for op in allowed):
        return json.dumps({"error": "Only INSERT, UPDATE, and DELETE statements are allowed."})

    db = database or MYSQL_CONFIG.get("database", "")
    with _get_connection(db) as conn:
        with conn.cursor() as cursor:
            cursor.execute(query)
            affected = cursor.rowcount
            last_id = cursor.lastrowid
    return json.dumps({"affected_rows": affected, "last_insert_id": last_id})


if __name__ == "__main__":
    mcp.run()

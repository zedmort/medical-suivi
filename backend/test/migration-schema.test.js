const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const {
  parseExpectedForeignKeys,
  verifySchema,
} = require("../scripts/migrate");

const schema = fs.readFileSync(
  path.join(__dirname, "..", "config", "schema.sql"),
  "utf8",
);
const expectedTables = [
  ...schema.matchAll(/CREATE TABLE IF NOT EXISTS\s+`?([A-Za-z0-9_]+)`?/gi),
].map((match) => match[1]);
const expectedForeignKeys = parseExpectedForeignKeys(schema);

const connectionWithSchema = (tables, columns, foreignKeys = expectedForeignKeys) => ({
  execute: async (sql) => {
    if (sql.includes("information_schema.TABLES")) {
      return [tables.map((TABLE_NAME) => ({ TABLE_NAME }))];
    }
    if (sql.includes("information_schema.COLUMNS")) {
      return [columns.map((COLUMN_NAME) => ({ COLUMN_NAME }))];
    }
    if (sql.includes("information_schema.KEY_COLUMN_USAGE")) {
      return [foreignKeys.map(({
        table: TABLE_NAME,
        column: COLUMN_NAME,
        referencedTable: REFERENCED_TABLE_NAME,
        referencedColumn: REFERENCED_COLUMN_NAME,
        deleteRule: DELETE_RULE,
      }) => ({
        TABLE_NAME,
        COLUMN_NAME,
        REFERENCED_TABLE_NAME,
        REFERENCED_COLUMN_NAME,
        DELETE_RULE,
      }))];
    }
    throw new Error(`Unexpected schema verification query: ${sql}`);
  },
});

test("migration verifies all 19 tables defined by the application schema", async () => {
  assert.equal(expectedTables.length, 19);
  assert.ok(expectedForeignKeys.length > 0);
  await verifySchema(
    connectionWithSchema(
      expectedTables,
      ["id", "name", "email", "password_hash", "role", "specialty"],
    ),
    schema,
  );
});

test("migration fails verification when a schema relationship is missing", async () => {
  await assert.rejects(
    verifySchema(
      connectionWithSchema(
        expectedTables,
        ["id", "name", "email", "password_hash", "role", "specialty"],
        expectedForeignKeys.slice(1),
      ),
      schema,
    ),
    /missing foreign keys:/,
  );
});

test("migration fails verification when an application table is missing", async () => {
  await assert.rejects(
    verifySchema(
      connectionWithSchema(
        expectedTables.filter((table) => table !== "users"),
        ["id", "name", "email", "password_hash", "role", "specialty"],
      ),
      schema,
    ),
    /missing tables: users/,
  );
});

test("migration fails verification when authentication columns are missing", async () => {
  await assert.rejects(
    verifySchema(
      connectionWithSchema(
        expectedTables,
        ["id", "email", "password_hash", "role", "specialty"],
      ),
      schema,
    ),
    /users is missing authentication columns: name/,
  );
});

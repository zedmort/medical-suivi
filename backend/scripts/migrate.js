const fs = require("node:fs");
const path = require("node:path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });
const mysql = require("mysql2/promise");
const { resolveDatabaseConfig } = require("../config/databaseConfig");
const {
  SPECIALTY_DISEASES,
  getSpecialties,
  getAllDiseases,
} = require("../config/medicalTaxonomy");

async function main() {
  const schemaPath = path.join(__dirname, "..", "config", "schema.sql");
  const schema = fs.readFileSync(schemaPath, "utf8");

  const connectionConfig = resolveDatabaseConfig();

  const connection = await mysql.createConnection({
    ...connectionConfig,
    multipleStatements: true,
  });

  try {
    const [[{ databaseName }]] = await connection.query(
      "SELECT DATABASE() AS databaseName",
    );
    if (!databaseName) {
      throw new Error("The MySQL connection has no selected database.");
    }
    console.log(`Applying schema to MySQL database: ${databaseName}`);

    await connection.query(schema);
    await migrateExistingSchema(connection);
    await seedMedicalTaxonomy(connection);
    await verifySchema(connection, schema);
    console.log('Migration complete.');
  } finally {
    await connection.end();
  }
}

async function migrateExistingSchema(connection) {
  const additions = {
    users: [
      ['firstname', 'VARCHAR(100) NULL'],
      ['lastname', 'VARCHAR(100) NULL'],
      ['date_of_birth', 'DATE NULL'],
      ['address', 'TEXT NULL'],
      ['phone', 'VARCHAR(30) NULL'],
      ['doctor_type', "ENUM('general_practitioner', 'specialist') NULL"],
      ['professional_info', 'TEXT NULL'],
    ],
    patients: [['date_of_birth', 'DATE NULL']],
  };

  for (const [table, columns] of Object.entries(additions)) {
    for (const [column, definition] of columns) {
      const [rows] = await connection.execute(
        `SELECT COUNT(*) AS count
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
        [table, column],
      );
      if (rows[0].count === 0) {
        await connection.query(
          `ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${definition}`,
        );
      }
    }
  }

  const [[{ invalidRoleCount }]] = await connection.query(
    `SELECT COUNT(*) AS invalidRoleCount
     FROM users
     WHERE role IS NULL
       OR role NOT IN ('doctor', 'patient', 'labo', 'pharmacy', 'admin')`,
  );
  if (invalidRoleCount > 0) {
    throw new Error(
      `Schema migration stopped: ${invalidRoleCount} users have a role value outside the supported roles.`,
    );
  }

  await connection.query(
    `ALTER TABLE users
     MODIFY COLUMN role ENUM('doctor', 'patient', 'labo', 'pharmacy', 'admin') NOT NULL`,
  );
}

async function verifySchema(connection, schema) {
  const expectedTables = [
    ...schema.matchAll(/CREATE TABLE IF NOT EXISTS\s+`?([A-Za-z0-9_]+)`?/gi),
  ].map((match) => match[1]);
  const [tableRows] = await connection.execute(
    `SELECT TABLE_NAME
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (${expectedTables.map(() => "?").join(", ")})`,
    expectedTables,
  );
  const existingTables = new Set(tableRows.map((row) => row.TABLE_NAME));
  const missingTables = expectedTables.filter((table) => !existingTables.has(table));
  if (missingTables.length > 0) {
    throw new Error(`Schema verification failed; missing tables: ${missingTables.join(", ")}`);
  }

  const requiredUserColumns = [
    "id",
    "name",
    "email",
    "password_hash",
    "role",
    "specialty",
  ];
  const [columnRows] = await connection.execute(
    `SELECT COLUMN_NAME
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'users'
       AND COLUMN_NAME IN (${requiredUserColumns.map(() => "?").join(", ")})`,
    requiredUserColumns,
  );
  const existingUserColumns = new Set(columnRows.map((row) => row.COLUMN_NAME));
  const missingUserColumns = requiredUserColumns.filter(
    (column) => !existingUserColumns.has(column),
  );
  if (missingUserColumns.length > 0) {
    throw new Error(
      `Schema verification failed; users is missing authentication columns: ${missingUserColumns.join(", ")}`,
    );
  }

  const expectedForeignKeys = parseExpectedForeignKeys(schema);
  const [foreignKeyRows] = await connection.execute(
    `SELECT k.TABLE_NAME, k.COLUMN_NAME, k.REFERENCED_TABLE_NAME,
            k.REFERENCED_COLUMN_NAME, r.DELETE_RULE
     FROM information_schema.KEY_COLUMN_USAGE k
     JOIN information_schema.REFERENTIAL_CONSTRAINTS r
       ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
       AND r.TABLE_NAME = k.TABLE_NAME
       AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
     WHERE k.CONSTRAINT_SCHEMA = DATABASE()
       AND k.REFERENCED_TABLE_NAME IS NOT NULL`,
  );
  const existingForeignKeys = new Set(
    foreignKeyRows.map((row) =>
      foreignKeyKey(
        row.TABLE_NAME,
        row.COLUMN_NAME,
        row.REFERENCED_TABLE_NAME,
        row.REFERENCED_COLUMN_NAME,
        row.DELETE_RULE,
      ),
    ),
  );
  const missingForeignKeys = expectedForeignKeys.filter(
    (foreignKey) => !existingForeignKeys.has(foreignKey.key),
  );
  if (missingForeignKeys.length > 0) {
    throw new Error(
      `Schema verification failed; missing foreign keys: ${missingForeignKeys.map((foreignKey) => `${foreignKey.table}.${foreignKey.column} -> ${foreignKey.referencedTable}.${foreignKey.referencedColumn}`).join(", ")}`,
    );
  }
}

function parseExpectedForeignKeys(schema) {
  const foreignKeys = [];
  const tableDefinitions = schema.matchAll(
    /CREATE TABLE IF NOT EXISTS\s+`?([A-Za-z0-9_]+)`?\s*\(([\s\S]*?)\)\s*ENGINE=/gi,
  );

  for (const [, table, definition] of tableDefinitions) {
    const constraints = definition.matchAll(
      /FOREIGN KEY\s*\(\s*`?([A-Za-z0-9_]+)`?\s*\)\s*REFERENCES\s+`?([A-Za-z0-9_]+)`?\s*\(\s*`?([A-Za-z0-9_]+)`?\s*\)\s+ON DELETE\s+(CASCADE|SET NULL|RESTRICT|NO ACTION)/gi,
    );
    for (const [, column, referencedTable, referencedColumn, deleteRule] of constraints) {
      foreignKeys.push({
        table,
        column,
        referencedTable,
        referencedColumn,
        deleteRule,
        key: foreignKeyKey(table, column, referencedTable, referencedColumn, deleteRule),
      });
    }
  }
  return foreignKeys;
}

function foreignKeyKey(table, column, referencedTable, referencedColumn, deleteRule) {
  return [
    table,
    column,
    referencedTable,
    referencedColumn,
    deleteRule,
  ].map((value) => String(value).toLowerCase()).join(".");
}

async function seedMedicalTaxonomy(connection) {
  for (const slug of getSpecialties()) {
    await connection.execute(
      'INSERT IGNORE INTO specialties (slug, name) VALUES (?, ?)',
      [slug, slug],
    );
  }

  for (const name of getAllDiseases()) {
    await connection.execute(
      'INSERT IGNORE INTO medical_conditions (name) VALUES (?)',
      [name],
    );
  }

  for (const [slug, conditions] of Object.entries(SPECIALTY_DISEASES)) {
    for (const name of conditions) {
      await connection.execute(
        `INSERT IGNORE INTO condition_specialties (condition_id, specialty_id)
         SELECT c.id, s.id
         FROM medical_conditions c
         JOIN specialties s ON s.slug = ?
         WHERE c.name = ?`,
        [slug, name],
      );
    }
  }

  await connection.query(
    `INSERT IGNORE INTO doctor_specialties (doctor_id, specialty_id)
     SELECT u.id, s.id
     FROM users u
     JOIN specialties s ON s.slug = LOWER(TRIM(u.specialty))
     WHERE u.role = 'doctor' AND u.specialty IS NOT NULL AND u.specialty <> ''`,
  );

  await connection.query(
    `INSERT IGNORE INTO patient_conditions (patient_id, condition_id)
     SELECT p.id, c.id
     FROM patients p
     JOIN medical_conditions c ON c.name = p.disease
     WHERE p.disease IS NOT NULL AND p.disease <> ''`,
  );
}

if (require.main === module) {
  main().catch((error) => {
    console.error('Migration failed:', error.message);
    process.exit(1);
  });
}

module.exports = { parseExpectedForeignKeys, verifySchema };

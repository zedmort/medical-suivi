require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

async function main() {
  const migrationPath = path.join(__dirname, '..', 'config', 'migration.sql');
  const sql = fs.readFileSync(migrationPath, 'utf8');

  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'medical_suivi',
    multipleStatements: true,
  });

  try {
    await connection.query(sql);
    console.log('Migration complete.');
  } finally {
    await connection.end();
  }
}

main().catch((error) => {
  console.error('Migration failed:', error.message);
  process.exit(1);
});

const mysql2 = require("mysql2");
const path = require("node:path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });
const { resolveDatabaseConfig } = require("./databaseConfig");

const poolConfig = resolveDatabaseConfig();

poolConfig.waitForConnections = true;
poolConfig.connectionLimit = 10;
poolConfig.queueLimit = 0;

const pool = mysql2.createPool(poolConfig);

const db = pool.promise();

db.getConnection()
  .then(() => console.log("MySQL connected successfully"))
  .catch((err) => console.error("MySQL connection error:", err && err.message ? err.message : err));

module.exports = db;

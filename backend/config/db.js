const mysql2 = require("mysql2");
require("dotenv").config();

const poolConfig = process.env.DATABASE_URL
  ? { uri: process.env.DATABASE_URL }
  : {
      host: process.env.DB_HOST || "localhost",
      user: process.env.DB_USER || "root",
      password: process.env.DB_PASSWORD || "",
      database: process.env.DB_NAME || "medical_suivi",
    };

const isLocalHost = (host) => {
  const h = (host || "").toString().toLowerCase();
  return h === "localhost" || h === "127.0.0.1" || h === "::1";
};

if (process.env.DB_SSL === "true" || (process.env.DB_SSL !== "false" && !process.env.DATABASE_URL && !isLocalHost(process.env.DB_HOST))) {
  poolConfig.ssl = { rejectUnauthorized: false };
}
if (process.env.DB_SSL === "true" && process.env.DATABASE_URL) {
  poolConfig.ssl = { rejectUnauthorized: false };
}

poolConfig.waitForConnections = true;
poolConfig.connectionLimit = 10;
poolConfig.queueLimit = 0;

const pool = mysql2.createPool(poolConfig);

const db = pool.promise();

db.getConnection()
  .then(() => console.log("MySQL connected successfully"))
  .catch((err) => console.error("MySQL connection error:", err && err.message ? err.message : err));

module.exports = db;

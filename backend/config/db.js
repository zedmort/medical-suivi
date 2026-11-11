const mysql2 = require("mysql2");
require("dotenv").config();

const resolveDbConfig = () => {
  if (process.env.DATABASE_URL || process.env.MYSQL_URL) {
    return { uri: process.env.DATABASE_URL || process.env.MYSQL_URL };
  }

  const dbHost = process.env.DB_HOST || process.env.MYSQLHOST || "localhost";
  const dbUser = process.env.DB_USER || process.env.MYSQLUSER || "root";
  const dbPassword = process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || "";
  const dbName = process.env.DB_NAME || process.env.MYSQL_DATABASE || "railway";
  const dbPort = process.env.DB_PORT || process.env.MYSQLPORT || 3306;

  return {
    host: dbHost,
    port: Number(dbPort),
    user: dbUser,
    password: dbPassword,
    database: dbName,
  };
};

const poolConfig = resolveDbConfig();

const isRailwayPrivateHost = (host) =>
  (host || "").toString().toLowerCase().endsWith(".railway.internal");

const isPrivateHost = (host) => {
  const hostname = (host || "").toString().toLowerCase();
  return hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "::1" ||
    isRailwayPrivateHost(hostname);
};

const uriHost = poolConfig.uri ? new URL(poolConfig.uri).hostname : null;
const railwayPrivateConnection =
  isRailwayPrivateHost(uriHost) ||
  (!poolConfig.uri &&
    isRailwayPrivateHost(process.env.DB_HOST || process.env.MYSQLHOST));

if (railwayPrivateConnection && poolConfig.uri) {
  const uri = new URL(poolConfig.uri);
  for (const key of [...uri.searchParams.keys()]) {
    if (/^(?:ssl|tls)(?:[-_].*)?$/i.test(key)) uri.searchParams.delete(key);
  }
  poolConfig.uri = uri.toString();
}

if (!railwayPrivateConnection && (process.env.DB_SSL === "true" || (process.env.DB_SSL !== "false" && !poolConfig.uri && !isPrivateHost(process.env.DB_HOST || process.env.MYSQLHOST)))) {
  poolConfig.ssl = { rejectUnauthorized: false };
}
if (!railwayPrivateConnection && process.env.DB_SSL === "true" && poolConfig.uri) {
  poolConfig.ssl = { rejectUnauthorized: false };
}

poolConfig.waitForConnections = true;
poolConfig.connectionLimit = 10;
poolConfig.queueLimit = 0;

poolConfig.charset = 'utf8mb4';

const pool = mysql2.createPool(poolConfig);

const db = pool.promise();

db.getConnection()
  .then(() => console.log("MySQL connected successfully"))
  .catch((err) => console.error("MySQL connection error:", err && err.message ? err.message : err));

module.exports = db;

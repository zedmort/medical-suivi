const isRailwayPrivateHost = (host) =>
  (host || "").toString().toLowerCase().endsWith(".railway.internal");

const isPrivateHost = (host) => {
  const hostname = (host || "").toString().toLowerCase();
  return hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "::1" ||
    isRailwayPrivateHost(hostname);
};

function resolveDatabaseConfig(env = process.env) {
  const connectionUrl = env.MYSQL_URL || env.DATABASE_URL;
  const config = connectionUrl
    ? { uri: connectionUrl }
    : {
        host: env.DB_HOST || env.MYSQLHOST || "localhost",
        port: Number(env.DB_PORT || env.MYSQLPORT || 3306),
        user: env.DB_USER || env.MYSQLUSER || "root",
        password: env.DB_PASSWORD || env.MYSQLPASSWORD || "",
        database: env.DB_NAME || env.MYSQL_DATABASE || "railway",
      };

  const uriHost = config.uri ? new URL(config.uri).hostname : null;
  const railwayPrivateConnection =
    isRailwayPrivateHost(uriHost) ||
    (!config.uri &&
      isRailwayPrivateHost(env.DB_HOST || env.MYSQLHOST));

  if (railwayPrivateConnection && config.uri) {
    const uri = new URL(config.uri);
    for (const key of [...uri.searchParams.keys()]) {
      if (/^(?:ssl|tls)(?:[-_].*)?$/i.test(key)) uri.searchParams.delete(key);
    }
    config.uri = uri.toString();
  }

  const databaseHost = config.uri ? uriHost : config.host;
  if (
    !railwayPrivateConnection &&
    (
      env.DB_SSL === "true" ||
      (
        env.DB_SSL !== "false" &&
        !config.uri &&
        !isPrivateHost(databaseHost)
      )
    )
  ) {
    config.ssl = { rejectUnauthorized: false };
  }

  if (
    !railwayPrivateConnection &&
    env.DB_SSL === "true" &&
    config.uri
  ) {
    config.ssl = { rejectUnauthorized: false };
  }

  config.charset = "utf8mb4";
  return config;
}

module.exports = { resolveDatabaseConfig };

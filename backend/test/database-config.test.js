const assert = require("node:assert/strict");
const { test } = require("node:test");
const mysql2 = require("mysql2");

const dbPath = require.resolve("../config/db");
const envKeys = [
  "DATABASE_URL",
  "MYSQL_URL",
  "DB_SSL",
  "DB_HOST",
  "MYSQLHOST",
  "DB_USER",
  "MYSQLUSER",
  "DB_PASSWORD",
  "MYSQLPASSWORD",
  "DB_NAME",
  "MYSQL_DATABASE",
  "DB_PORT",
  "MYSQLPORT",
];

const loadPoolConfig = async (values) => {
  const previous = new Map(envKeys.map((key) => [key, process.env[key]]));
  for (const key of envKeys) {
    if (!(key in values) || values[key] === undefined) delete process.env[key];
    else process.env[key] = values[key];
  }

  const originalCreatePool = mysql2.createPool;
  const originalConsoleLog = console.log;
  let poolConfig;
  mysql2.createPool = (config) => {
    poolConfig = config;
    return {
      promise: () => ({
        getConnection: async () => ({ release() {} }),
      }),
    };
  };
  console.log = () => {};
  delete require.cache[dbPath];
  try {
    require("../config/db");
    await new Promise((resolve) => setImmediate(resolve));
    return poolConfig;
  } finally {
    delete require.cache[dbPath];
    mysql2.createPool = originalCreatePool;
    console.log = originalConsoleLog;
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
};

test("Railway private MySQL hosts do not request driver TLS by default", async () => {
  const config = await loadPoolConfig({ MYSQLHOST: "mysql.railway.internal" });
  assert.equal(config.ssl, undefined);
});

test("external MySQL hosts retain the TLS-by-default behavior", async () => {
  const config = await loadPoolConfig({ DB_HOST: "mysql.example.test" });
  assert.deepEqual(config.ssl, { rejectUnauthorized: false });
});

test("explicit DB_SSL settings override the host-based default", async (t) => {
  await t.test("true enables TLS for a Railway private host", async () => {
    const config = await loadPoolConfig({
      MYSQLHOST: "mysql.railway.internal",
      DB_SSL: "true",
    });
    assert.deepEqual(config.ssl, { rejectUnauthorized: false });
  });

  await t.test("false disables TLS for an external host", async () => {
    const config = await loadPoolConfig({
      DB_HOST: "mysql.example.test",
      DB_SSL: "false",
    });
    assert.equal(config.ssl, undefined);
  });
});

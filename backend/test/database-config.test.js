const assert = require("node:assert/strict");
const { test } = require("node:test");
const { execFileSync } = require("node:child_process");
const path = require("node:path");

const loadPoolConfig = (values) => {
  const script = `
    require("dotenv").config = () => ({});
    const mysql = require("mysql2");
    mysql.createPool = (config) => {
      process.stdout.write(JSON.stringify(config));
      return { promise: () => ({ getConnection: async () => ({ release() {} }) }) };
    };
    console.log = () => {};
    require("./config/db");
  `;
  const env = { PATH: process.env.PATH };
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined) env[key] = value;
  }
  return JSON.parse(execFileSync(process.execPath, ["-e", script], {
    cwd: path.join(__dirname, ".."),
    env,
    encoding: "utf8",
  }));
};

test("Railway private MySQL hosts do not request driver TLS by default", () => {
  const config = loadPoolConfig({ MYSQLHOST: "mysql.railway.internal" });
  assert.equal(config.ssl, undefined);
});

test("external MySQL hosts retain the TLS-by-default behavior", () => {
  const config = loadPoolConfig({ DB_HOST: "mysql.example.test" });
  assert.deepEqual(config.ssl, { rejectUnauthorized: false });
});

test("the localhost fallback does not request TLS when DB host variables are absent", () => {
  const config = loadPoolConfig({});
  assert.equal(config.host, "localhost");
  assert.equal(config.ssl, undefined);
});

test("Railway private host ignores the stale DB_SSL=true override", () => {
  const config = loadPoolConfig({
    MYSQLHOST: "mysql.railway.internal",
    DB_SSL: "true",
  });
  assert.equal(config.ssl, undefined);
});

test("Railway MYSQL_URL stays plaintext at the MySQL layer", () => {
  const config = loadPoolConfig({
    MYSQL_URL: "mysql://user:password@mysql.railway.internal:3306/railway?ssl=%7B%22rejectUnauthorized%22%3Atrue%7D",
    DB_SSL: "true",
  });
  assert.equal(config.ssl, undefined);
  assert.equal(new URL(config.uri).hostname, "mysql.railway.internal");
  assert.equal(new URL(config.uri).searchParams.has("ssl"), false);
});

test("DB_SSL=true enables TLS for an external database URL", () => {
  const config = loadPoolConfig({
    MYSQL_URL: "mysql://user:password@mysql.example.test:3306/railway",
    DB_SSL: "true",
  });
  assert.deepEqual(config.ssl, { rejectUnauthorized: false });
});

test("DB_SSL=false disables TLS for an external host", () => {
  const config = loadPoolConfig({
    DB_HOST: "mysql.example.test",
    DB_SSL: "false",
  });
  assert.equal(config.ssl, undefined);
});

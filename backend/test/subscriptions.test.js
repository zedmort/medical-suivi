const assert = require("node:assert/strict");
const { test } = require("node:test");

const dbPath = require.resolve("../config/db");
const originalDbModule = require.cache[dbPath];
const dbStub = { execute: async () => [[]] };
require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: dbStub,
};

const {
  plansByRole,
  getPlans,
  getMySubscription,
  activateDemoSubscription,
} = require("../controllers/subscriptionController");

if (originalDbModule) require.cache[dbPath] = originalDbModule;
else delete require.cache[dbPath];

const responseRecorder = () => ({
  statusCode: null,
  body: null,
  status(code) {
    this.statusCode = code;
    return this;
  },
  json(body) {
    this.body = body;
    return this;
  },
});

test("subscription catalog only exposes professional plans", () => {
  const res = responseRecorder();
  getPlans({ user: { role: "doctor" } }, res);

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.plans, plansByRole.doctor);

  const patientResponse = responseRecorder();
  getPlans({ user: { role: "patient" } }, patientResponse);
  assert.equal(patientResponse.statusCode, 403);
});

test("patients are exempt and cannot activate a demo subscription", async () => {
  const patient = responseRecorder();
  await getMySubscription({ user: { id: 8, role: "patient" } }, patient);
  assert.deepEqual(patient.body, { subscription: null, exempt: true });

  const activation = responseRecorder();
  await activateDemoSubscription(
    { user: { id: 8, role: "patient" }, body: { plan_key: "essential" } },
    activation,
  );
  assert.equal(activation.statusCode, 403);
});

test("active subscriptions are returned on login checks and are not replaced", async () => {
  const calls = [];
  dbStub.execute = async (sql, params = []) => {
    calls.push({ sql, params });
    return [[{
      plan_key: "clinic",
      status: "active",
      payment_mode: "demo",
      activated_at: "2026-01-01 00:00:00",
    }]];
  };

  const lookup = responseRecorder();
  await getMySubscription({ user: { id: 15, role: "doctor" } }, lookup);
  assert.equal(lookup.statusCode, 200);
  assert.equal(lookup.body.subscription.plan_key, "clinic");

  const activation = responseRecorder();
  await activateDemoSubscription(
    {
      user: { id: 15, role: "doctor" },
      body: { plan_key: "essential" },
    },
    activation,
  );
  assert.equal(activation.statusCode, 200);
  assert.equal(activation.body.subscription.plan_key, "clinic");
  assert.equal(calls.length, 2);
});

test("professional activation persists the chosen demo plan", async () => {
  const calls = [];
  let finalRead = false;
  dbStub.execute = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes("SELECT plan_key")) {
      if (!finalRead) {
        finalRead = true;
        return [[]];
      }
      return [[{
        plan_key: "professional",
        status: "active",
        payment_mode: "demo",
      }]];
    }
    return [{ affectedRows: 1 }];
  };

  const res = responseRecorder();
  await activateDemoSubscription(
    {
      user: { id: 15, role: "doctor" },
      body: { plan_key: "professional" },
    },
    res,
  );

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.subscription.status, "active");
  assert.equal(res.body.subscription.payment_mode, "demo");
  assert.equal(calls[1].params[2], "professional");
  assert.match(calls[1].sql, /ON DUPLICATE KEY UPDATE/);
});

test("invalid plans are rejected before database access", async () => {
  const originalExecute = dbStub.execute;
  let queried = false;
  dbStub.execute = async () => {
    queried = true;
    return [[]];
  };
  const res = responseRecorder();
  await activateDemoSubscription(
    {
      user: { id: 15, role: "labo" },
      body: { plan_key: "not-a-plan" },
    },
    res,
  );
  assert.equal(res.statusCode, 400);
  assert.equal(queried, false);
  dbStub.execute = originalExecute;
});

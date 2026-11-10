const assert = require("node:assert/strict");
const { test } = require("node:test");

const dbPath = require.resolve("../config/db");
const notificationControllerPath = require.resolve(
  "../controllers/notificationController",
);
const originalDbModule = require.cache[dbPath];
const originalNotificationModule = require.cache[notificationControllerPath];
const dbStub = { execute: async () => [[]], query: async () => [[]] };

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: dbStub,
};
require.cache[notificationControllerPath] = {
  id: notificationControllerPath,
  filename: notificationControllerPath,
  loaded: true,
  exports: { createNotification: async () => {} },
};

const {
  createPaidConsultation,
  validDemoCard,
  validExpiry,
} = require("../controllers/consultationController");
const {
  getAllDiseases,
  isKnownDisease,
  isValidRegistrationSpecialty,
} = require("../config/medicalTaxonomy");
const { findPatientForUser } = require("../utils/patientIdentity");
const { getDoctors } = require("../controllers/userController");
const { register } = require("../controllers/authController");

if (originalDbModule) require.cache[dbPath] = originalDbModule;
else delete require.cache[dbPath];
if (originalNotificationModule) {
  require.cache[notificationControllerPath] = originalNotificationModule;
} else {
  delete require.cache[notificationControllerPath];
}

const futureExpiry = () => {
  const date = new Date();
  date.setUTCFullYear(date.getUTCFullYear() + 2);
  return `${String(date.getUTCMonth() + 1).padStart(2, "0")}/${String(
    date.getUTCFullYear() % 100,
  ).padStart(2, "0")}`;
};

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

test("demo simulator accepts only its documented test cards", () => {
  assert.equal(validDemoCard("4111111111111111"), true);
  assert.equal(validDemoCard("4000000000000002"), true);
  assert.equal(validDemoCard("4242424242424242"), false);
  assert.equal(validDemoCard("4111 1111 1111 1111"), true);
});

test("demo payment expiry validation rejects malformed and past dates", () => {
  assert.equal(validExpiry(futureExpiry()), true);
  assert.equal(validExpiry("00/40"), false);
  assert.equal(validExpiry("13/40"), false);
  assert.equal(validExpiry("not-a-date"), false);
});

test("successful simulated payment creates a consultation without storing card data", async () => {
  const calls = [];
  let consultationCount = 0;
  dbStub.getConnection = async () => ({
    beginTransaction: async () => {},
    commit: async () => {},
    rollback: async () => {},
    release: () => {},
    execute: async (sql, params = []) => {
      calls.push({ sql, params });
      if (sql.includes("FROM simulated_transactions") && sql.includes("idempotency_key")) {
        return [[]];
      }
      if (sql.includes("FROM patients WHERE user_id")) {
        return [[{ id: 27 }]];
      }
      if (sql.includes("FROM system_settings")) {
        return [[{ setting_value: "2500" }]];
      }
      if (sql.includes("INSERT INTO consultations")) {
        consultationCount++;
        return [{ insertId: 91 }];
      }
      if (sql.includes("INSERT INTO simulated_transactions")) {
        return [{ insertId: 44 }];
      }
      throw new Error(`Unexpected SQL in test: ${sql}`);
    },
  });

  const req = {
    user: { id: 12, role: "patient" },
    body: {
      symptoms: "Persistent headache and dizziness",
      notes: "",
      idempotency_key: "test-payment-key-0001",
      cardholder: "Demo Patient",
      card_number: "4111111111111111",
      expiry: futureExpiry(),
      cvv: "123",
    },
  };
  const res = responseRecorder();
  await createPaidConsultation(req, res);

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.transaction.status, "succeeded");
  assert.equal(res.body.consultationId, 91);
  assert.equal(consultationCount, 1);
  const paymentInsert = calls.find(({ sql }) =>
    sql.includes("INSERT INTO simulated_transactions"),
  );
  assert.ok(paymentInsert);
  assert.ok(paymentInsert.params.includes("1111"));
  assert.ok(!paymentInsert.params.includes("4111111111111111"));
});

test("declined simulated payment records no consultation", async () => {
  const calls = [];
  dbStub.getConnection = async () => ({
    beginTransaction: async () => {},
    commit: async () => {},
    rollback: async () => {},
    release: () => {},
    execute: async (sql, params = []) => {
      calls.push({ sql, params });
      if (sql.includes("FROM simulated_transactions") && sql.includes("idempotency_key")) {
        return [[]];
      }
      if (sql.includes("FROM patients WHERE user_id")) {
        return [[{ id: 27 }]];
      }
      if (sql.includes("FROM system_settings")) {
        return [[{ setting_value: "2500" }]];
      }
      if (sql.includes("INSERT INTO simulated_transactions")) {
        return [{ insertId: 45 }];
      }
      throw new Error(`Unexpected SQL in test: ${sql}`);
    },
  });

  const req = {
    user: { id: 12, role: "patient" },
    body: {
      symptoms: "Persistent headache and dizziness",
      notes: "",
      idempotency_key: "test-payment-key-0002",
      cardholder: "Demo Patient",
      card_number: "4000000000000002",
      expiry: futureExpiry(),
      cvv: "123",
    },
  };
  const res = responseRecorder();
  await createPaidConsultation(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.transaction.status, "failed");
  assert.equal(res.body.consultationId, null);
  assert.equal(calls.some(({ sql }) => sql.includes("INSERT INTO consultations")), false);
});

test("repeated payment idempotency key returns the existing transaction", async () => {
  const calls = [];
  dbStub.getConnection = async () => ({
    beginTransaction: async () => {},
    commit: async () => {},
    rollback: async () => {},
    release: () => {},
    execute: async (sql, params = []) => {
      calls.push({ sql, params });
      if (sql.includes("FROM simulated_transactions") && sql.includes("idempotency_key")) {
        return [[{
          id: 44,
          consultation_id: 91,
          amount: "2500.00",
          currency: "DZD",
          status: "succeeded",
          reference: "DEMO-REFERENCE",
          card_last_four: "1111",
        }]];
      }
      throw new Error(`Unexpected SQL in test: ${sql}`);
    },
  });

  const req = {
    user: { id: 12, role: "patient" },
    body: {
      symptoms: "Persistent headache and dizziness",
      idempotency_key: "test-payment-key-0001",
      cardholder: "Demo Patient",
      card_number: "4111111111111111",
      expiry: futureExpiry(),
      cvv: "123",
    },
  };
  const res = responseRecorder();
  await createPaidConsultation(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.transaction.id, 44);
  assert.equal(res.body.consultationId, 91);
  assert.equal(calls.length, 1);
});

test("medical taxonomy only supports the diabetes condition and its aliases", () => {
  assert.deepEqual(getAllDiseases(), ["Diabetes"]);
  assert.equal(isKnownDisease("Diabetes"), true);
  assert.equal(isKnownDisease("Type 1 Diabetes"), true);
  assert.equal(isKnownDisease("Hypertension"), false);
});

test("doctor registration only allows diabetes and thyroid specialties", () => {
  assert.equal(isValidRegistrationSpecialty("diabetology"), true);
  assert.equal(isValidRegistrationSpecialty("endocrinology"), true);
  assert.equal(isValidRegistrationSpecialty("cardiology"), false);
});

test("doctor registration rejects a specialty outside the two supported areas", async () => {
  const res = responseRecorder();
  await register(
    {
      body: {
        email: "doctor@example.test",
        password: "password",
        role: "doctor",
        firstname: "Test",
        lastname: "Doctor",
        date_of_birth: "1980-01-01",
        address: "Test address",
        phone: "0000000000",
        doctor_type: "specialist",
        specialties: ["cardiology"],
      },
    },
    res,
  );

  assert.equal(res.statusCode, 400);
});

test("doctor search accepts doctor type filtering for patients", async () => {
  const originalExecute = dbStub.execute;
  dbStub.execute = async (sql, params) => {
    assert.ok(sql.includes("u.doctor_type = ?"));
    assert.deepEqual(params, ["%Ali%", "general_practitioner"]);
    return [[{ id: 7, name: "Ali", doctor_type: "general_practitioner", specialties: "diabetology" }]];
  };

  const res = responseRecorder();
  await getDoctors(
    { user: { role: "patient" }, query: { search: "Ali", doctor_type: "general_practitioner" } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.doctors[0].id, 7);
  dbStub.execute = originalExecute;
});

test("legacy patient identity resolves a missing JWT name from the user record", async () => {
  const queries = [];
  const connection = {
    execute: async (sql, params) => {
      queries.push({ sql, params });
      if (sql.includes("FROM patients WHERE user_id")) return [[]];
      if (sql.includes("SELECT name FROM users")) {
        return [[{ name: "Legacy Patient" }]];
      }
      if (sql.includes("FROM patients p")) return [[{ id: 38 }]];
      throw new Error(`Unexpected SQL in test: ${sql}`);
    },
  };

  const result = await findPatientForUser({ id: 12 }, connection);
  assert.deepEqual(result, { id: 38 });
  assert.deepEqual(queries[2].params, [
    "Legacy Patient",
    "Legacy Patient",
    "Legacy Patient",
  ]);
});

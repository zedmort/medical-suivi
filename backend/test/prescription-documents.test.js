const assert = require("node:assert/strict");
const { test } = require("node:test");

const dbPath = require.resolve("../config/db");
const notificationPath = require.resolve(
  "../controllers/notificationController",
);
const identityPath = require.resolve("../utils/patientIdentity");
const originals = new Map(
  [dbPath, notificationPath, identityPath].map((path) => [
    path,
    require.cache[path],
  ]),
);

const calls = [];
const documentRow = {
  id: 17,
  file_url: "/uploads/prescription-17.pdf",
  created_at: "2026-10-25T10:00:00.000Z",
};
const dbStub = {
  execute: async (sql, params) => {
    calls.push({ sql, params });
    return [[documentRow]];
  },
};

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: dbStub,
};
require.cache[notificationPath] = {
  id: notificationPath,
  filename: notificationPath,
  loaded: true,
  exports: { createNotification: async () => {} },
};
require.cache[identityPath] = {
  id: identityPath,
  filename: identityPath,
  loaded: true,
  exports: {
    findPatientForUser: async () => ({ id: 29 }),
    findUserIdForPatient: async () => 41,
  },
};

const {
  createPrescription,
  getPrescriptions,
} = require("../controllers/prescriptionController");
const { getMyRequests } = require("../controllers/analysisController");

for (const [path, original] of originals) {
  if (original) require.cache[path] = original;
  else delete require.cache[path];
}

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

test("patient prescription retrieval includes its saved document reference", async () => {
  calls.length = 0;
  const res = responseRecorder();
  await getPrescriptions({ user: { id: 41, role: "patient" } }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.prescriptions[0].file_url, documentRow.file_url);
  assert.match(calls[0].sql, /WHERE pr\.patient_id = \?/);
  assert.deepEqual(calls[0].params, [29]);
});

test("doctor prescription creation saves the uploaded document reference", async () => {
  calls.length = 0;
  dbStub.execute = async (sql, params) => {
    calls.push({ sql, params });
    if (sql.includes("FROM patients")) {
      return [[{
        id: 29,
        firstname: "Test",
        lastname: "Patient",
        address: "Test address",
        phone: "000",
        disease: "Diabetes",
      }]];
    }
    if (sql.includes("INSERT INTO prescriptions")) {
      return [{ insertId: 17 }];
    }
    throw new Error(`Unexpected SQL in prescription test: ${sql}`);
  };
  const res = responseRecorder();
  await createPrescription(
    {
      user: { id: 5, role: "doctor" },
      body: { patient_id: 29, pharmacy_id: 8, notes: "Take as directed" },
      file: { filename: "prescription-17.pdf" },
    },
    res,
  );

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.prescriptionId, 17);
  assert.equal(res.body.file_url, "/uploads/prescription-17.pdf");
  assert.equal(calls[1].params[4], "/uploads/prescription-17.pdf");
});

test("pharmacy prescription retrieval includes the doctor's saved document", async () => {
  calls.length = 0;
  dbStub.execute = async (sql, params) => {
    calls.push({ sql, params });
    return [[documentRow]];
  };
  const res = responseRecorder();
  await getPrescriptions({ user: { id: 8, role: "pharmacy" } }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.prescriptions[0].file_url, documentRow.file_url);
  assert.match(calls[0].sql, /WHERE pr\.pharmacy_id = \?/);
  assert.deepEqual(calls[0].params, [8]);
});

test("patient analysis retrieval returns request attachments and laboratory results", async () => {
  calls.length = 0;
  const analysisRow = {
    id: 31,
    file_url: "/uploads/doctor-attachment.png",
    result_url: "/uploads/lab-result.pdf",
  };
  dbStub.execute = async (sql, params) => {
    calls.push({ sql, params });
    return [[analysisRow]];
  };
  const res = responseRecorder();
  await getMyRequests({ user: { id: 41, role: "patient" } }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.requests[0].file_url, analysisRow.file_url);
  assert.equal(res.body.requests[0].result_url, analysisRow.result_url);
  assert.match(calls[0].sql, /LEFT JOIN analysis_results/);
  assert.match(calls[0].sql, /WHERE ar\.patient_id = \?/);
  assert.deepEqual(calls[0].params, [29]);
});

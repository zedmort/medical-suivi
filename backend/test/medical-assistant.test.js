const assert = require("node:assert/strict");
const { test } = require("node:test");

const dbPath = require.resolve("../config/db");
const notificationPath = require.resolve("../controllers/notificationController");
const originalDb = require.cache[dbPath];
const originalNotifications = require.cache[notificationPath];
const dbStub = { execute: async () => [[]] };
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

const {
  createConversation,
  getMessages,
  sendMessage,
  createConsultationRequest,
  getDoctorRequests,
  encryptText,
  decryptText,
  hasEmergencyRedFlag,
  requestAiResponse,
} = require("../controllers/medicalAssistantController");

if (originalDb) require.cache[dbPath] = originalDb;
else delete require.cache[dbPath];
if (originalNotifications) require.cache[notificationPath] = originalNotifications;
else delete require.cache[notificationPath];

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

test("only the configured Gemini free-tier model is accepted", async () => {
  await withEnvironment({
    AI_PROVIDER: "gemini",
    AI_API_KEY: "server-test-key",
    AI_MODEL: "gemini-4-carbon",
  }, async () => {
    await assert.rejects(
      requestAiResponse({ history: [], language: "fr", emergency: false }),
      (error) => {
        assert.equal(error.code, "medical_ai_model_unsupported");
        assert.equal(error.status, 503);
        return true;
      },
    );
  });
});

const withEnvironment = async (values, callback) => {
  const previous = new Map(
    Object.keys(values).map((key) => [key, process.env[key]]),
  );
  for (const [key, value] of Object.entries(values)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    await callback();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
};

const encryptionKey = Buffer.alloc(32, 7).toString("base64");

test("medical chat messages are authenticated-encrypted at rest", async () => {
  await withEnvironment({ MEDICAL_CHAT_ENCRYPTION_KEY: encryptionKey }, async () => {
    const encrypted = encryptText("Patient-reported headache");
    assert.notEqual(encrypted.ciphertext.toString(), "Patient-reported headache");
    assert.equal(decryptText({
      iv: encrypted.iv,
      auth_tag: encrypted.authTag,
      ciphertext: encrypted.ciphertext,
    }), "Patient-reported headache");
    assert.throws(() => decryptText({
      iv: encrypted.iv,
      auth_tag: Buffer.alloc(16),
      ciphertext: encrypted.ciphertext,
    }));
  });
});

test("only patient role can start a conversation and missing provider is explicit", async () => {
  const originalExecute = dbStub.execute;
  let queried = false;
  dbStub.execute = async () => {
    queried = true;
    return [[]];
  };
  await withEnvironment({
    MEDICAL_CHAT_ENCRYPTION_KEY: encryptionKey,
    AI_PROVIDER: "gemini",
    AI_API_KEY: undefined,
    AI_MODEL: undefined,
  }, async () => {
    const forbidden = responseRecorder();
    await createConversation({ user: { id: 8, role: "doctor" }, body: {} }, forbidden);
    assert.equal(forbidden.statusCode, 403);

    const unavailable = responseRecorder();
    await createConversation({ user: { id: 8, role: "patient" }, body: {} }, unavailable);
    assert.equal(unavailable.statusCode, 503);
    assert.equal(unavailable.body.code, "medical_ai_key_missing");
    assert.equal(queried, false);
  });
  dbStub.execute = originalExecute;
});

test("missing chat encryption key is diagnosed separately from provider config", async () => {
  await withEnvironment({
    MEDICAL_CHAT_ENCRYPTION_KEY: undefined,
    AI_PROVIDER: "gemini",
    AI_API_KEY: "test-key-not-logged",
    AI_MODEL: "gemini-3.5-flash-lite",
  }, async () => {
    const res = responseRecorder();
    await createConversation(
      { user: { id: 8, role: "patient" }, body: {} },
      res,
    );
    assert.equal(res.statusCode, 503);
    assert.equal(res.body.code, "medical_chat_key_missing");
    assert.doesNotMatch(JSON.stringify(res.body), /test-key-not-logged/);
  });
});

test("assistant uses patient conversation context and persists only ciphertext", async () => {
  const originalExecute = dbStub.execute;
  const originalGetConnection = dbStub.getConnection;
  const originalFetch = global.fetch;
  const priorEnv = new Map(
    ["MEDICAL_CHAT_ENCRYPTION_KEY", "AI_PROVIDER", "AI_API_KEY", "AI_MODEL"]
      .map((key) => [key, process.env[key]]),
  );
  process.env.MEDICAL_CHAT_ENCRYPTION_KEY = encryptionKey;
  process.env.AI_PROVIDER = "gemini";
  process.env.AI_API_KEY = "server-test-key";
  process.env.AI_MODEL = "gemini-3.5-flash-lite";
  const priorAssistant = encryptText("Bonjour, comment puis-je vous aider ?");
  const prior = encryptText("My name is Sophie and my headache began yesterday.");
  let providerBody;
  const inserts = [];
  dbStub.execute = async (sql, params = []) => {
    if (sql.includes("SELECT id FROM patients")) return [[{ id: 32 }]];
    if (sql.includes("SELECT id") && sql.includes("medical_chat_conversations")) {
      return [[{ id: 19 }]];
    }
    if (sql.includes("SELECT role, iv")) {
      return [[
        {
          role: "user",
          iv: prior.iv,
          auth_tag: prior.authTag,
          ciphertext: prior.ciphertext,
          created_at: new Date(),
        },
        {
          role: "assistant",
          iv: priorAssistant.iv,
          auth_tag: priorAssistant.authTag,
          ciphertext: priorAssistant.ciphertext,
          created_at: new Date(),
        },
      ]];
    }
    throw new Error(`Unexpected query: ${sql}`);
  };
  dbStub.getConnection = async () => ({
    beginTransaction: async () => {},
    commit: async () => {},
    rollback: async () => {},
    release: () => {},
    execute: async (sql, params = []) => {
      inserts.push({ sql, params });
      return [{ affectedRows: 1 }];
    },
  });
  global.fetch = async (url, options) => {
    const requestUrl = new URL(url);
    assert.equal(requestUrl.host, "generativelanguage.googleapis.com");
    assert.equal(requestUrl.pathname, "/v1/models/gemini-3.5-flash-lite:generateContent");
    assert.ok(options.headers.get("x-goog-api-key"));
    providerBody = JSON.parse(options.body);
    return new Response(JSON.stringify({
        candidates: [{
          content: {
            parts: [{ text: "Depuis quand ressentez-vous ce mal de tête ?" }],
            role: "model",
          },
        }],
      }), { status: 200, headers: { "Content-Type": "application/json" } });
  };

  try {
    const res = responseRecorder();
    await sendMessage(
      {
        user: { id: 71, role: "patient" },
        params: { id: "19" },
        body: {
          message: "My phone number is +33 6 12 34 56 78. I also feel dizzy.",
          language: "fr",
        },
      },
      res,
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.message.content, "Depuis quand ressentez-vous ce mal de tête ?");
    assert.equal(providerBody.contents[0].role, "model");
    assert.equal(
      providerBody.contents[0].parts[0].text,
      "Bonjour, comment puis-je vous aider ?",
    );
    assert.equal(
      providerBody.contents[1].parts[0].text,
      "[redacted name] and my headache began yesterday.",
    );
    assert.equal(
      providerBody.contents[2].parts[0].text,
      "My phone number is [redacted number]. I also feel dizzy.",
    );
    assert.equal(providerBody.contents[1].role, "user");
    assert.equal(providerBody.contents[2].role, "user");
    assert.equal(
      providerBody.systemInstruction.parts[0].text.includes("French"),
      true,
    );
    assert.ok(inserts.some(({ sql }) => sql.includes("INSERT INTO medical_chat_messages")));
    assert.ok(inserts.every(({ params }) => !params.includes("My phone number is")));
    assert.equal(res.body.emergency, false);
  } finally {
    dbStub.execute = originalExecute;
    dbStub.getConnection = originalGetConnection;
    global.fetch = originalFetch;
    for (const [key, value] of priorEnv) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test("patients cannot read a conversation owned by another patient", async () => {
  const originalExecute = dbStub.execute;
  let messagesQueried = false;
  dbStub.execute = async (sql) => {
    if (sql.includes("SELECT id FROM patients")) return [[{ id: 33 }]];
    if (sql.includes("medical_chat_conversations")) return [[]];
    if (sql.includes("medical_chat_messages")) messagesQueried = true;
    return [[]];
  };
  await withEnvironment({ MEDICAL_CHAT_ENCRYPTION_KEY: encryptionKey }, async () => {
    const res = responseRecorder();
    await getMessages(
      { user: { id: 88, role: "patient" }, params: { id: "19" } },
      res,
    );
    assert.equal(res.statusCode, 404);
    assert.equal(messagesQueried, false);
  });
  dbStub.execute = originalExecute;
});

test("AI provider authentication and service failures have safe distinct errors", async () => {
  const originalFetch = global.fetch;
  const originalConsoleError = console.error;
  const logged = [];
  console.error = (...args) => logged.push(args.join(" "));
  await withEnvironment({
    AI_PROVIDER: "gemini",
    AI_API_KEY: "server-test-key",
    AI_MODEL: "gemini-3.5-flash-lite",
  }, async () => {
    try {
      global.fetch = async () => new Response("{}", { status: 401 });
      await assert.rejects(
        requestAiResponse({ history: [], language: "fr", emergency: false }),
        (error) => {
          assert.equal(error.status, 502);
          assert.equal(error.code, "medical_ai_credentials_rejected");
          return true;
        },
      );

      global.fetch = async () => new Response(
        JSON.stringify({ error: { code: 404, status: "NOT_FOUND" } }),
        { status: 404 },
      );
      await assert.rejects(
        requestAiResponse({ history: [], language: "fr", emergency: false }),
        (error) => {
          assert.equal(error.status, 502);
          assert.equal(error.code, "medical_ai_model_unavailable");
          assert.match(error.message, /gemini-3\.5-flash-lite/);
          return true;
        },
      );

      global.fetch = async () => new Response("{}", {
        status: 429,
        headers: { "Retry-After": "0" },
      });
      await assert.rejects(
        requestAiResponse({ history: [], language: "ar", emergency: false }),
        (error) => {
          assert.equal(error.status, 503);
          assert.equal(error.code, "medical_ai_rate_limited");
          return true;
        },
      );

      global.fetch = async () => {
        const error = new Error("request failed with secret-bearing detail");
        error.name = "FetchError";
        throw error;
      };
      await assert.rejects(
        requestAiResponse({ history: [], language: "fr", emergency: false }),
        (error) => {
          assert.equal(error.code, "medical_ai_network_error");
          return true;
        },
      );
    } finally {
      global.fetch = originalFetch;
      console.error = originalConsoleError;
    }
  });
  assert.ok(logged.some((entry) => entry.includes("providerStatus")));
  assert.doesNotMatch(logged.join("\n"), /server-test-key|secret-bearing detail/);
});

test("patient identifiers are redacted before a request is sent to Gemini", () => {
  const { deidentifyMessage } = require("../controllers/medicalAssistantController");
  assert.equal(
    deidentifyMessage("Je m'appelle Nadia, mon adresse est 12 rue Centrale. Contact: patient@example.com"),
    "[nom supprimé], [adresse supprimée]. Contact: [redacted email]",
  );
  assert.equal(
    deidentifyMessage("اسمي فاطمة، أعاني من الصداع"),
    "[تم حذف الاسم]، أعاني من الصداع",
  );
});

test("consultation requests contain symptom details only after explicit consent", async () => {
  const originalExecute = dbStub.execute;
  let chatMessagesRead = false;
  let insertParams;
  dbStub.execute = async (sql, params = []) => {
    if (sql.includes("SELECT id FROM patients")) return [[{ id: 33 }]];
    if (sql.includes("medical_chat_conversations")) return [[{ id: 19 }]];
    if (sql.includes("FROM users WHERE id")) return [[{ id: 72 }]];
    if (sql.includes("medical_chat_messages")) chatMessagesRead = true;
    if (sql.includes("INSERT INTO medical_chat_consultation_requests")) {
      insertParams = params;
      return [{ insertId: 55 }];
    }
    throw new Error(`Unexpected query: ${sql}`);
  };
  await withEnvironment({ MEDICAL_CHAT_ENCRYPTION_KEY: encryptionKey }, async () => {
    const withoutConsent = responseRecorder();
    await createConsultationRequest(
      {
        user: { id: 88, role: "patient" },
        params: { id: "19" },
        body: { doctor_id: 72, share_summary: false },
      },
      withoutConsent,
    );
    assert.equal(withoutConsent.statusCode, 201);
    assert.equal(chatMessagesRead, false);
    assert.equal(insertParams[5], null);
    assert.equal(insertParams[6], null);

    const withConsent = responseRecorder();
    await createConsultationRequest(
      {
        user: { id: 88, role: "patient" },
        params: { id: "19" },
        body: {
          doctor_id: 72,
          share_summary: true,
          symptom_summary: "My symptoms started this morning.",
        },
      },
      withConsent,
    );
    assert.equal(withConsent.statusCode, 201);
    assert.equal(chatMessagesRead, false);
    assert.notEqual(
      insertParams[5].toString(),
      "My symptoms started this morning.",
    );
    assert.match(decryptText({
      iv: insertParams[3],
      auth_tag: insertParams[4],
      ciphertext: insertParams[5],
    }), /Patient-provided symptom summary:\nMy symptoms started this morning/);
  });
  dbStub.execute = originalExecute;
});

test("doctor request access is role-guarded and scoped to the authenticated doctor", async () => {
  const originalExecute = dbStub.execute;
  let queryParams;
  dbStub.execute = async (sql, params = []) => {
    assert.match(sql, /WHERE r\.doctor_id = \?/);
    queryParams = params;
    const encrypted = encryptText("Consented patient symptoms.");
    return [[{
      id: 9,
      status: "requested",
      consented_at: new Date(),
      summary_iv: encrypted.iv,
      summary_auth_tag: encrypted.authTag,
      summary_ciphertext: encrypted.ciphertext,
      firstname: "Test",
      lastname: "Patient",
      age: 38,
      sex: "F",
      created_at: new Date(),
    }]];
  };
  await withEnvironment({ MEDICAL_CHAT_ENCRYPTION_KEY: encryptionKey }, async () => {
    const denied = responseRecorder();
    await getDoctorRequests({ user: { id: 77, role: "patient" } }, denied);
    assert.equal(denied.statusCode, 403);

    const res = responseRecorder();
    await getDoctorRequests({ user: { id: 77, role: "doctor" } }, res);
    assert.deepEqual(queryParams, [77]);
    assert.equal(res.body.requests[0].summary, "Consented patient symptoms.");
  });
  dbStub.execute = originalExecute;
});

test("potential emergency symptoms are marked for urgent AI guidance", () => {
  assert.equal(hasEmergencyRedFlag("I have sudden chest pain"), true);
  assert.equal(hasEmergencyRedFlag("J’ai une forte douleur à la poitrine"), true);
  assert.equal(hasEmergencyRedFlag("I have no chest pain"), false);
  assert.equal(hasEmergencyRedFlag("Je n’ai pas de douleur à la poitrine"), false);
  assert.equal(hasEmergencyRedFlag("أعاني من صعوبة في التنفس"), true);
  assert.equal(hasEmergencyRedFlag("لا أعاني من صعوبة في التنفس"), false);
  assert.equal(hasEmergencyRedFlag("I have had a mild cough for two days"), false);
});

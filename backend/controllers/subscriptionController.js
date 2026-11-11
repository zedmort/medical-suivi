const db = require("../config/db");

const plansByRole = {
  doctor: [
    { key: "essential", priceDzd: 1200, features: ["patient_management", "consultations"] },
    { key: "professional", priceDzd: 2500, features: ["patient_management", "consultations", "analytics"] },
    { key: "clinic", priceDzd: 4500, features: ["patient_management", "consultations", "analytics", "team_tools"] },
  ],
  pharmacy: [
    { key: "essential", priceDzd: 1200, features: ["prescription_management", "patient_support"] },
    { key: "professional", priceDzd: 2500, features: ["prescription_management", "patient_support", "inventory_tools"] },
    { key: "clinic", priceDzd: 4500, features: ["prescription_management", "patient_support", "inventory_tools", "team_tools"] },
  ],
  labo: [
    { key: "essential", priceDzd: 1200, features: ["analysis_management", "result_delivery"] },
    { key: "professional", priceDzd: 2500, features: ["analysis_management", "result_delivery", "analytics"] },
    { key: "clinic", priceDzd: 4500, features: ["analysis_management", "result_delivery", "analytics", "team_tools"] },
  ],
};

const professionalRoles = Object.keys(plansByRole);

const getPlans = (req, res) => {
  const { role } = req.user;
  if (!professionalRoles.includes(role)) {
    return res.status(403).json({ message: "Subscriptions are only available to professionals." });
  }
  return res.status(200).json({ role, plans: plansByRole[role] });
};

const getMySubscription = async (req, res) => {
  const { id, role } = req.user;
  if (role === "patient") {
    return res.status(200).json({ subscription: null, exempt: true });
  }
  if (!professionalRoles.includes(role)) {
    return res.status(403).json({ message: "Subscriptions are only available to professionals." });
  }

  try {
    const [rows] = await db.execute(
      `SELECT plan_key, status, payment_mode, activated_at
       FROM professional_subscriptions
       WHERE user_id = ? AND role = ?
       LIMIT 1`,
      [id, role],
    );
    return res.status(200).json({ subscription: rows[0] || null, exempt: false });
  } catch (error) {
    console.error("Get subscription error:", error);
    return res.status(500).json({ message: "Could not load subscription." });
  }
};

const activateDemoSubscription = async (req, res) => {
  const { id, role } = req.user;
  if (!professionalRoles.includes(role)) {
    return res.status(403).json({ message: "Only professionals can activate a subscription." });
  }

  const planKey = typeof req.body.plan_key === "string"
    ? req.body.plan_key.trim()
    : "";
  const plan = plansByRole[role].find((item) => item.key === planKey);
  if (!plan) {
    return res.status(400).json({ message: "Select a valid subscription plan." });
  }

  try {
    const [existing] = await db.execute(
      `SELECT plan_key, status, payment_mode, activated_at
       FROM professional_subscriptions
       WHERE user_id = ? AND role = ?
       LIMIT 1`,
      [id, role],
    );
    if (existing[0]?.status === "active") {
      return res.status(200).json({
        message: "An active subscription already exists.",
        subscription: existing[0],
      });
    }

    await db.execute(
      `INSERT INTO professional_subscriptions
         (user_id, role, plan_key, status, payment_mode, activated_at)
       VALUES (?, ?, ?, 'active', 'demo', CURRENT_TIMESTAMP)
       ON DUPLICATE KEY UPDATE
         plan_key = VALUES(plan_key),
         status = 'active',
         payment_mode = 'demo',
         activated_at = CURRENT_TIMESTAMP`,
      [id, role, planKey],
    );
    const [rows] = await db.execute(
      `SELECT plan_key, status, payment_mode, activated_at
       FROM professional_subscriptions
       WHERE user_id = ? AND role = ?
       LIMIT 1`,
      [id, role],
    );
    if (!rows[0]) {
      throw new Error("Subscription activation did not persist.");
    }
    return res.status(201).json({
      message: "Demo subscription activated. No payment was collected.",
      subscription: rows[0],
    });
  } catch (error) {
    console.error("Activate subscription error:", error);
    return res.status(500).json({ message: "Could not activate demo subscription." });
  }
};

module.exports = {
  plansByRole,
  getPlans,
  getMySubscription,
  activateDemoSubscription,
};

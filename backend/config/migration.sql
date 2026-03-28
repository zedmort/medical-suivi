-- ═══════════════════════════════════════════════════════════════════════════
-- Medical Suivi — Migration to new schema
-- Run ONCE in your MySQL client:
--   mysql -u root -p medical_suivi < migration.sql
-- ═══════════════════════════════════════════════════════════════════════════

USE medical_suivi;

SET FOREIGN_KEY_CHECKS = 0;

-- Destructive reset:
-- This migration intentionally deletes all existing data on each run.
TRUNCATE TABLE notifications;
TRUNCATE TABLE analysis_results;
TRUNCATE TABLE analysis_requests;
TRUNCATE TABLE prescriptions;
TRUNCATE TABLE patients;
TRUNCATE TABLE users;

-- ── 1. Patients table (independent from users — patients don't log in) ───────
CREATE TABLE IF NOT EXISTS patients (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNIQUE,
  doctor_id  INT,
  firstname  VARCHAR(100) NOT NULL,
  lastname   VARCHAR(100) NOT NULL,
  address    TEXT         NOT NULL,
  age        INT          NOT NULL,
  sex        ENUM('M','F') NOT NULL,
  disease    VARCHAR(500) NOT NULL,
  phone      VARCHAR(30),
  next_analysis_date DATE,
  last_analysis_reminder_date DATE,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS specialty VARCHAR(100);
ALTER TABLE patients ADD COLUMN IF NOT EXISTS user_id INT UNIQUE;
ALTER TABLE patients MODIFY COLUMN doctor_id INT NULL;

ALTER TABLE patients ADD COLUMN IF NOT EXISTS next_analysis_date DATE;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS last_analysis_reminder_date DATE;

-- ── 2. Analysis requests (patient_id → patients.id) ─────────────────────────
CREATE TABLE IF NOT EXISTS analysis_requests (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id  INT         NOT NULL,
  patient_id INT         NOT NULL,
  labo_id    INT         NOT NULL,
  notes      TEXT,
  file_url   VARCHAR(500),
  status     ENUM('pending', 'completed') DEFAULT 'pending',
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id)  REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (patient_id) REFERENCES patients(id)  ON DELETE CASCADE,
  FOREIGN KEY (labo_id)    REFERENCES users(id)     ON DELETE CASCADE
);

ALTER TABLE analysis_requests ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE analysis_requests ADD COLUMN IF NOT EXISTS file_url VARCHAR(500);

-- ── 3. Analysis results ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS analysis_results (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT          NOT NULL,
  file_url   VARCHAR(500) NOT NULL,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (request_id) REFERENCES analysis_requests(id) ON DELETE CASCADE
);

-- ── 4. Prescriptions (patient_id → patients.id) ──────────────────────────────
CREATE TABLE IF NOT EXISTS prescriptions (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id   INT          NOT NULL,
  patient_id  INT          NOT NULL,
  pharmacy_id INT          NOT NULL,
  notes       TEXT,
  file_url    VARCHAR(500),
  status      ENUM('pending', 'dispensed') DEFAULT 'pending',
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id)   REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (patient_id)  REFERENCES patients(id)  ON DELETE CASCADE,
  FOREIGN KEY (pharmacy_id) REFERENCES users(id)    ON DELETE CASCADE
);

ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS file_url VARCHAR(500);

-- ── 5. Notifications ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT          NOT NULL,
  title      VARCHAR(255) NOT NULL,
  body       TEXT         NOT NULL,
  type       VARCHAR(50)  DEFAULT 'info',
  ref_id     INT,
  is_read    TINYINT(1)   DEFAULT 0,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Migration complete.' AS status;

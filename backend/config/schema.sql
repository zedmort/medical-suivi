-- Medical Suivi Database Schema
-- Run this against the target database connection you are using.
-- Railway exposes the database as the selected connection database (for example: railway).

CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(150)    NOT NULL,
  email         VARCHAR(255)    NOT NULL UNIQUE,
  password_hash VARCHAR(255)    NOT NULL,
  role          ENUM('doctor', 'patient', 'labo', 'pharmacy', 'admin') NOT NULL,
  specialty     VARCHAR(100),
  firstname     VARCHAR(100),
  lastname      VARCHAR(100),
  date_of_birth DATE,
  address       TEXT,
  phone         VARCHAR(30),
  doctor_type   ENUM('general_practitioner', 'specialist'),
  professional_info TEXT,
  created_at    TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS patients (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNIQUE,
  doctor_id  INT,
  firstname  VARCHAR(100) NOT NULL,
  lastname   VARCHAR(100) NOT NULL,
  address    TEXT         NOT NULL,
  age        INT          NOT NULL,
  date_of_birth DATE,
  sex        ENUM('M','F') NOT NULL,
  disease    VARCHAR(500) NOT NULL,
  phone      VARCHAR(30),
  next_analysis_date DATE,
  last_analysis_reminder_date DATE,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS analysis_requests (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id  INT         NOT NULL,
  patient_id INT         NOT NULL,
  labo_id    INT         NOT NULL,
  notes      TEXT,
  file_url   VARCHAR(500),
  status     ENUM('pending', 'completed') DEFAULT 'pending',
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id)  REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (labo_id)    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS analysis_results (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT         NOT NULL,
  file_url   VARCHAR(500) NOT NULL,
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (request_id) REFERENCES analysis_requests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS prescriptions (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id   INT         NOT NULL,
  patient_id  INT         NOT NULL,
  pharmacy_id INT         NOT NULL,
  notes       TEXT,
  file_url    VARCHAR(500),
  status      ENUM('pending', 'dispensed') DEFAULT 'pending',
  created_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id)   REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (patient_id)  REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (pharmacy_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS specialties (
  id   INT AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS doctor_specialties (
  doctor_id    INT NOT NULL,
  specialty_id INT NOT NULL,
  PRIMARY KEY (doctor_id, specialty_id),
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (specialty_id) REFERENCES specialties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medical_conditions (
  id   INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS condition_specialties (
  condition_id INT NOT NULL,
  specialty_id INT NOT NULL,
  PRIMARY KEY (condition_id, specialty_id),
  FOREIGN KEY (condition_id) REFERENCES medical_conditions(id) ON DELETE CASCADE,
  FOREIGN KEY (specialty_id) REFERENCES specialties(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS patient_conditions (
  patient_id   INT NOT NULL,
  condition_id INT NOT NULL,
  PRIMARY KEY (patient_id, condition_id),
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (condition_id) REFERENCES medical_conditions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(100) PRIMARY KEY,
  setting_value VARCHAR(500) NOT NULL,
  updated_by INT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS consultations (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT,
  symptoms TEXT NOT NULL,
  notes TEXT,
  status ENUM('paid', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'paid',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_consultations_doctor_status (doctor_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS simulated_transactions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  consultation_id BIGINT,
  amount DECIMAL(12, 2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'DZD',
  status ENUM('pending', 'succeeded', 'failed') NOT NULL,
  reference VARCHAR(64) NOT NULL UNIQUE,
  idempotency_key VARCHAR(64) NOT NULL UNIQUE,
  card_last_four CHAR(4),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (consultation_id) REFERENCES consultations(id) ON DELETE SET NULL,
  INDEX idx_demo_transactions_user_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS advertisements (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(180) NOT NULL,
  description TEXT,
  image_url VARCHAR(500),
  destination_url VARCHAR(1000),
  placement VARCHAR(50) NOT NULL DEFAULT 'dashboard',
  starts_at DATETIME,
  expires_at DATETIME,
  is_active TINYINT(1) NOT NULL DEFAULT 0,
  impressions BIGINT NOT NULL DEFAULT 0,
  clicks BIGINT NOT NULL DEFAULT 0,
  created_by INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_ads_active_schedule (is_active, starts_at, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS professional_subscriptions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  role ENUM('doctor', 'pharmacy', 'labo') NOT NULL,
  plan_key VARCHAR(40) NOT NULL,
  status ENUM('active') NOT NULL DEFAULT 'active',
  payment_mode ENUM('demo') NOT NULL DEFAULT 'demo',
  activated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_professional_subscription_user (user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medical_chat_conversations (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  INDEX idx_medical_chat_patient_updated (patient_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medical_chat_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_id BIGINT NOT NULL,
  role ENUM('user', 'assistant') NOT NULL,
  iv BINARY(12) NOT NULL,
  auth_tag BINARY(16) NOT NULL,
  ciphertext MEDIUMBLOB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id)
    REFERENCES medical_chat_conversations(id) ON DELETE CASCADE,
  INDEX idx_medical_chat_messages_history (conversation_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medical_chat_consultation_requests (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_id BIGINT NOT NULL,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  summary_iv BINARY(12),
  summary_auth_tag BINARY(16),
  summary_ciphertext MEDIUMBLOB,
  consented_at TIMESTAMP NULL,
  status ENUM('requested', 'accepted', 'declined') NOT NULL DEFAULT 'requested',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id)
    REFERENCES medical_chat_conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_medical_chat_doctor_requests (doctor_id, status, created_at),
  INDEX idx_medical_chat_patient_requests (patient_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

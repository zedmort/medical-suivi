-- Medical Suivi Database Schema
-- Run this in your MySQL client to set up the database.

CREATE DATABASE IF NOT EXISTS medical_suivi;
USE medical_suivi;

CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(150)    NOT NULL,
  email         VARCHAR(255)    NOT NULL UNIQUE,
  password_hash VARCHAR(255)    NOT NULL,
  role          ENUM('doctor', 'patient', 'labo', 'pharmacy') NOT NULL,
  specialty     VARCHAR(100),
  created_at    TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

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
);

CREATE TABLE IF NOT EXISTS analysis_results (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT         NOT NULL,
  file_url   VARCHAR(500) NOT NULL,
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (request_id) REFERENCES analysis_requests(id) ON DELETE CASCADE
);

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
);

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

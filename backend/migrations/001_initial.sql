CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) PRIMARY KEY,
  firebase_uid VARCHAR(128) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  role ENUM('student','super_admin') NOT NULL DEFAULT 'student',
  status ENUM('active','suspended') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS entries (
  id CHAR(36) PRIMARY KEY,
  owner_id CHAR(36) NOT NULL,
  kind ENUM('deadline','routine') NOT NULL,
  title VARCHAR(100) NOT NULL,
  description VARCHAR(2000) NULL,
  time_zone VARCHAR(64) NOT NULL DEFAULT 'Asia/Kuala_Lumpur',
  reminder_minutes SMALLINT NULL,
  location_facility_id VARCHAR(36) NULL,
  location_name VARCHAR(150) NULL,
  latitude DECIMAL(9,6) NULL,
  longitude DECIMAL(9,6) NULL,
  photo_id CHAR(36) NULL,
  due_at TIMESTAMP(3) NULL,
  is_completed BOOLEAN NULL,
  start_date DATE NULL,
  start_time TIME NULL,
  end_time TIME NULL,
  repeat_type ENUM('none','daily','weekly') NULL,
  weekdays JSON NULL,
  repeat_until DATE NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_entries_owner FOREIGN KEY (owner_id) REFERENCES users(id),
  INDEX idx_entries_owner_kind_due (owner_id, kind, due_at),
  INDEX idx_entries_owner_dates (owner_id, start_date, repeat_until)
);

CREATE TABLE IF NOT EXISTS routine_occurrences (
  id CHAR(36) PRIMARY KEY,
  entry_id CHAR(36) NOT NULL,
  occurrence_date DATE NOT NULL,
  start_at TIMESTAMP(3) NOT NULL,
  end_at TIMESTAMP(3) NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_occurrences_entry FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
  UNIQUE KEY uq_routine_occurrence (entry_id, occurrence_date)
);

CREATE TABLE IF NOT EXISTS photos (
  id CHAR(36) PRIMARY KEY,
  owner_id CHAR(36) NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  storage_path VARCHAR(500) NOT NULL,
  size_bytes INT UNSIGNED NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_photos_owner FOREIGN KEY (owner_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS facilities (
  id CHAR(36) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  latitude DECIMAL(9,6) NOT NULL,
  longitude DECIMAL(9,6) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_sample BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS admin_actions (
  id CHAR(36) PRIMARY KEY,
  acting_admin_id CHAR(36) NOT NULL,
  target_type VARCHAR(32) NOT NULL,
  target_id CHAR(36) NOT NULL,
  action VARCHAR(64) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_actions_admin FOREIGN KEY (acting_admin_id) REFERENCES users(id),
  INDEX idx_admin_actions_created (created_at)
);

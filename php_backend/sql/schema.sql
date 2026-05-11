CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uuid CHAR(36) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('student','lecturer','admin') NOT NULL DEFAULT 'student',
  matric_number VARCHAR(50) NULL,
  lecturer_reg_no VARCHAR(50) NULL UNIQUE,
  lecturer_status ENUM('active','rejected') NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS classes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uuid CHAR(36) NOT NULL UNIQUE,
  title VARCHAR(150) NOT NULL,
  room_name VARCHAR(120) NOT NULL,
  lecturer_user_id BIGINT UNSIGNED NOT NULL,
  join_code VARCHAR(12) NOT NULL UNIQUE,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  radius_meters INT NOT NULL DEFAULT 50,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (lecturer_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS class_enrollments (
  class_id BIGINT UNSIGNED NOT NULL,
  student_user_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (class_id, student_user_id),
  FOREIGN KEY (class_id) REFERENCES classes(id),
  FOREIGN KEY (student_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS sessions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uuid CHAR(36) NOT NULL UNIQUE,
  class_id BIGINT UNSIGNED NOT NULL,
  lecturer_user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  status ENUM('active','closed') NOT NULL DEFAULT 'active',
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NOT NULL,
  closed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (class_id) REFERENCES classes(id),
  FOREIGN KEY (lecturer_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS attendance (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT UNSIGNED NOT NULL,
  class_id BIGINT UNSIGNED NOT NULL,
  student_user_id BIGINT UNSIGNED NOT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  distance_meters DECIMAL(8,2) NOT NULL,
  verification_method ENUM('biometric') NOT NULL,
  status ENUM('present') NOT NULL,
  marked_at DATETIME NOT NULL,
  UNIQUE KEY uniq_session_student (session_id, student_user_id),
  FOREIGN KEY (session_id) REFERENCES sessions(id),
  FOREIGN KEY (class_id) REFERENCES classes(id),
  FOREIGN KEY (student_user_id) REFERENCES users(id)
);


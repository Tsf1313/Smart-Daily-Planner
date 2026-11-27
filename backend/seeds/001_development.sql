INSERT INTO users (id, firebase_uid, name, email, role, status)
VALUES
  ('00000000-0000-4000-8000-000000000001', 'dev-student-1', 'Development Student', 'student@example.test', 'student', 'active'),
  ('00000000-0000-4000-8000-000000000002', 'dev-admin-1', 'Development Admin', 'admin@example.test', 'super_admin', 'active')
ON DUPLICATE KEY UPDATE name = VALUES(name), status = VALUES(status);

INSERT INTO facilities (id, name, latitude, longitude, is_active, is_sample)
VALUES
  ('00000000-0000-4000-8000-100000000001', 'Sample Campus Library', 2.300000, 111.800000, TRUE, TRUE),
  ('00000000-0000-4000-8000-100000000002', 'Sample Student Centre', 2.305000, 111.805000, TRUE, TRUE)
ON DUPLICATE KEY UPDATE name = VALUES(name), is_active = VALUES(is_active);

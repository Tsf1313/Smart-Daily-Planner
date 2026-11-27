CREATE TABLE IF NOT EXISTS planner_deadlines (
  id CHAR(36) CHARACTER SET ascii PRIMARY KEY,
  owner_uid VARBINARY(512) NOT NULL,
  title VARCHAR(200) NOT NULL,
  due_date DATE NOT NULL,
  INDEX owner_schedule (owner_uid, due_date, id)
) CHARACTER SET utf8mb4;

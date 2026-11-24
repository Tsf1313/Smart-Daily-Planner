const mysql = require("mysql2/promise");
const { getApps, initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

async function verifyUser(token) {
  const app = getApps()[0] || initializeApp({ credential: applicationDefault() });
  return (await getAuth(app).verifyIdToken(token, true)).uid;
}

let pool;
function database() {
  if (!pool) {
    if (!process.env.MYSQL_URL) throw new Error("MYSQL_URL is required.");
    pool = mysql.createPool(process.env.MYSQL_URL);
  }
  return pool;
}

const store = {
  async create(uid, entry) {
    await database().execute(
      "INSERT INTO planner_deadlines (id, owner_uid, title, due_date) VALUES (?, ?, ?, ?)",
      [entry.id, uid, entry.title, entry.dueDate],
    );
  },

  async list(uid, from, to) {
    const [rows] = await database().execute(
      `SELECT id, 'deadline' AS kind, title, DATE_FORMAT(due_date, '%Y-%m-%d') AS dueDate
       FROM planner_deadlines
       WHERE owner_uid = ? AND due_date BETWEEN ? AND ?
       ORDER BY due_date, id`,
      [uid, from || "1000-01-01", to || "9999-12-31"],
    );
    return rows;
  },
};

module.exports = { verifyUser, store };

const fs = require("node:fs");
const path = require("node:path");
const mysql = require("mysql2/promise");

async function migrate() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });
  const migrations = fs.readdirSync(path.join(__dirname, "..", "migrations"))
    .filter((file) => file.endsWith(".sql"))
    .sort();
  for (const file of migrations) {
    const sql = fs.readFileSync(path.join(__dirname, "..", "migrations", file), "utf8");
    await connection.query(sql);
    console.log(`Applied ${file}`);
  }
  await connection.end();
}

migrate().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

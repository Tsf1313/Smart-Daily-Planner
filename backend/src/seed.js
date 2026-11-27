const fs = require("node:fs");
const path = require("node:path");
const mysql = require("mysql2/promise");

async function seed() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });
  const seeds = fs.readdirSync(path.join(__dirname, "..", "seeds"))
    .filter((file) => file.endsWith(".sql"))
    .sort();
  for (const file of seeds) {
    await connection.query(fs.readFileSync(path.join(__dirname, "..", "seeds", file), "utf8"));
    console.log(`Seeded ${file}`);
  }
  await connection.end();
}

seed().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

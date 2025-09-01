// Server/router/db.js
require("dotenv").config();
const mysql = require("mysql2/promise");

// 공용 커넥션 풀
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3307),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD || process.env.DB_PASS, // 변수명 혼용 대비
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  namedPlaceholders: true, // :name 플레이스홀더 사용 라우터(STR/IR) 대응
  timezone: "Z",
});

// 세션 타임아웃(8h) 연장
pool.on?.("connection", (conn) => {
  conn
    .promise()
    .query("SET SESSION wait_timeout=28800, interactive_timeout=28800")
    .catch(() => {});
});

// 주기적 keepalive
const PING_INTERVAL_MS = 30 * 1000;
setInterval(async () => {
  try {
    await pool.query("SELECT 1");
  } catch (e) {
    console.warn("[DB] keepalive ping failed:", e?.code || e?.message);
  }
}, PING_INTERVAL_MS);

console.log(
  "[DB] ready:",
  process.env.DB_HOST,
  process.env.DB_PORT || 3307,
  process.env.DB_NAME
);

module.exports = pool;

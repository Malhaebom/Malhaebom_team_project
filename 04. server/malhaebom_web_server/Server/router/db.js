// Server/router/db.js  (경로는 편한 곳으로, 예: Server/db.js 권장)
require("dotenv").config();
const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3307),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD || process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 8,          // ← PM2 프로세스 수 고려해 조정
  queueLimit: 0,
  connectTimeout: 10_000,      // ← 타임아웃 명시
  enableKeepAlive: true,
  keepAliveInitialDelay: 10_000, // ← 0보단 약간 딜레이 권장
  namedPlaceholders: true,     // STR/IR의 :name 플레이스홀더 대응
  timezone: "Z",               // UTC 보관/파싱 기준
  decimalNumbers: true,     // (선택) 숫자 문자열 방지
});

// 세션 타임아웃(8h) 연장
pool.on?.("connection", (conn) => {
  conn.promise()
    .query("SET SESSION wait_timeout=28800, interactive_timeout=28800")
    .catch(() => {});
});

// 주기적 keepalive (간격 완화 or 필요없으면 제거)
const PING_INTERVAL_MS = 60 * 1000;  // ← 30초 → 60초(또는 5분) 권장
setInterval(async () => {
  try { await pool.query("SELECT 1"); }
  catch (e) { console.warn("[DB] keepalive ping failed:", e?.code || e?.message); }
}, PING_INTERVAL_MS);

console.log("[DB] ready:", process.env.DB_HOST, process.env.DB_PORT || 3307, process.env.DB_NAME);
module.exports = pool;

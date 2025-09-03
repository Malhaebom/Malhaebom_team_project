const express = require("express");
const mysql = require("mysql2/promise");

const router = express.Router();

const DB_CONFIG = {
  host    : process.env.DB_HOST     || "project-db-campus.smhrd.com",
  port    : Number(process.env.DB_PORT || 3307),
  user    : process.env.DB_USER     || "campus_25SW_BD_p3_3",
  password: process.env.DB_PASSWORD || "smhrd3",
  database: process.env.DB_NAME     || "campus_25SW_BD_p3_3",
};
const pool = mysql.createPool({
  ...DB_CONFIG,
  waitForConnections: true,
  connectionLimit: 10,
});

function safeParseJSON(jsonStr, fallback = null) {
  try {
    if (jsonStr == null) return fallback;
    if (typeof jsonStr === "object") return jsonStr;
    return JSON.parse(jsonStr);
  } catch {
    return fallback;
  }
}
const toNumber = (n, d = 0) => (Number.isFinite(Number(n)) ? Number(n) : d);
const toStrOrNull = (s) => {
  if (s === undefined || s === null) return null;
  const v = String(s).trim();
  return v.length ? v : null;
};

router.use((req, _res, next) => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`[STR] ${req.method} ${req.originalUrl}`);
  }
  next();
});

// 결과 저장 (POST)
router.post("/attempt", async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const {
      storyTitle,
      storyKey,
      attemptTime,
      clientKst,
      score,
      total,
      byCategory = {},
      byType = {},
      riskBars = {},
      riskBarsByType = {},
      user_key: bodyUserKey
    } = req.body || {};

    const user_key = (req.query.user_key || bodyUserKey || "guest").trim();

    if (!storyKey || !attemptTime || !user_key) {
      return res.status(400).json({ ok: false, error: "missing storyKey or attemptTime or user_key" });
    }

    const [r] = await conn.query(
      `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?) AND story_key=?`,
      [user_key, storyKey]
    );
    const nextAttempt = Number(r?.[0]?.last_order || 0) + 1;

    const utc = new Date(attemptTime);
    const pad = (n) => String(n).padStart(2, "0");
    const client_utc =
      isNaN(utc.getTime())
        ? null
        : `${utc.getUTCFullYear()}-${pad(utc.getUTCMonth() + 1)}-${pad(utc.getUTCDate())} ${pad(utc.getUTCHours())}:${pad(utc.getUTCMinutes())}:${pad(utc.getUTCSeconds())}`;

    const story_title = storyTitle || storyKey;

    await conn.query(
      `INSERT INTO tb_story_result
       (user_key, story_key, story_title, client_attempt_order, score, total, client_utc, client_kst,
        by_category, by_type, risk_bars, risk_bars_by_type)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        user_key,
        storyKey,
        story_title,
        nextAttempt,
        toNumber(score, 0),
        toNumber(total, 40),
        client_utc,
        toStrOrNull(clientKst),
        JSON.stringify(byCategory || {}),
        JSON.stringify(byType || {}),
        JSON.stringify(riskBars || {}),
        JSON.stringify(riskBarsByType || {})
      ]
    );

    return res.json({ ok: true, user_key, story_key: storyKey, attempt_order: nextAttempt });
  } catch (err) {
    console.error("[/str/attempt] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  } finally {
    conn.release();
  }
});

// ====== 유저 전체 히스토리(동화별 그룹) ======
router.get("/history/all", async (req, res) => {
  const { user_key } = req.query;
  if (!user_key) return res.status(400).json({ ok: false, error: "missing user_key" });
  try {
    const sql = `
      SELECT id, user_key, story_key, story_title,
             client_attempt_order, score, total,
             client_utc, client_kst, by_category, risk_bars
        FROM tb_story_result
       WHERE TRIM(user_key)=TRIM(?)
       ORDER BY story_key ASC, client_utc DESC, id DESC
    `;
    const [rows] = await pool.query(sql, [user_key]);

    const map = new Map();
    for (const r of rows) {
      const sk = r.story_key || "(unknown)";
      if (!map.has(sk)) {
        map.set(sk, {
          story_key: r.story_key,
          story_title: toStrOrNull(r.story_title),
          records: [],
        });
      }
      map.get(sk).records.push({
        id: r.id,
        client_kst: toStrOrNull(r.client_kst),
        client_utc: toStrOrNull(r.client_utc),
        client_attempt_order: r.client_attempt_order === null ? null : toNumber(r.client_attempt_order, null),
        score: toNumber(r.score, 0),
        total: toNumber(r.total, 0),
        by_category: safeParseJSON(r.by_category, {}),
        risk_bars: safeParseJSON(r.risk_bars, {})
      });
    }
    return res.json({ ok: true, data: Array.from(map.values()) });
  } catch (err) {
    console.error("[/str/history/all] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

module.exports = router;
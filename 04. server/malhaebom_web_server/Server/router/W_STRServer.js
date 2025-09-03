// Server/router/W_STRServer.js
const express = require("express");
const mysql = require("mysql2/promise");

const router = express.Router();

// ====== DB 연결 (환경변수 사용) ======
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

// ====== 헬퍼 ======
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

// 🔎 쿼리 로깅 미들웨어(개발용)
router.use((req, _res, next) => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`[STR] ${req.method} ${req.originalUrl}`);
  }
  next();
});

// ============ 디버그 엔드포인트(빠른 진단용) ============
// 1) ping
router.get("/debug/ping", (_req, res) => res.json({ ok: true, msg: "pong" }));

// 2) 해당 user_key의 총 행수
router.get("/debug/count_by_user", async (req, res) => {
  const { user_key } = req.query;
  if (!user_key) return res.status(400).json({ ok: false, error: "missing user_key" });
  try {
    const [r] = await pool.query(
      `SELECT COUNT(*) AS cnt FROM tb_story_result WHERE TRIM(user_key)=TRIM(?)`,
      [user_key]
    );
    return res.json({ ok: true, user_key, count: r[0]?.cnt ?? 0 });
  } catch (err) {
    console.error("[/str/debug/count_by_user] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

// 3) 해당 user_key의 story_key 목록(최신순)
router.get("/debug/distinct_stories", async (req, res) => {
  const { user_key } = req.query;
  if (!user_key) return res.status(400).json({ ok: false, error: "missing user_key" });
  try {
    const [rows] = await pool.query(
      `SELECT story_key, MAX(client_utc) AS last_utc, MAX(id) AS last_id
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?)
        GROUP BY story_key
        ORDER BY last_utc DESC, last_id DESC`,
      [user_key]
    );
    return res.json({ ok: true, data: rows });
  } catch (err) {
    console.error("[/str/debug/distinct_stories] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});
// =======================================================

// ====== 결과 저장 (POST) ======
// body: { user_key?, storyTitle, storyKey, attemptTime(ISO), clientKst, score, total, byCategory, byType, riskBars, riskBarsByType }
// query: ?user_key=... (URL이 body보다 우선)
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

    if (!storyKey || !attemptTime) {
      return res.status(400).json({ ok: false, error: "missing storyKey or attemptTime" });
    }

    // 회차 계산 (동일 user_key + story_key)
    const [r] = await conn.query(
      `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?) AND story_key=?`,
      [user_key, storyKey]
    );
    const nextAttempt = Number(r?.[0]?.last_order || 0) + 1;

    // client_utc는 DATETIME(초 단위)로 저장
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

// ====== 특정 동화 전체 이력 ======
router.get("/history", async (req, res) => {
  const { user_key, story_key } = req.query;
  if (!user_key || !story_key) {
    return res.status(400).json({ ok: false, error: "missing user_key or story_key" });
  }
  try {
    const sql = `
      SELECT id, user_key, story_key, story_title,
             client_attempt_order, score, total,
             client_utc, client_kst, by_category, risk_bars
        FROM tb_story_result
       WHERE TRIM(user_key)=TRIM(?) AND story_key=?
       ORDER BY client_utc DESC, id DESC
    `;
    const [rows] = await pool.query(sql, [user_key, story_key]);

    const normalized = rows.map((r) => ({
      id: r.id,
      user_key: r.user_key,
      story_key: r.story_key,
      story_title: toStrOrNull(r.story_title),
      client_attempt_order: r.client_attempt_order === null ? null : toNumber(r.client_attempt_order, null),
      score: toNumber(r.score, 0),
      total: toNumber(r.total, 0),
      client_utc: toStrOrNull(r.client_utc),
      client_kst: toStrOrNull(r.client_kst),
      by_category: safeParseJSON(r.by_category, {}),
      risk_bars: safeParseJSON(r.risk_bars, {})
    }));
    return res.json({ ok: true, data: normalized });
  } catch (err) {
    console.error("[/str/history] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
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

// ====== 특정 동화 최신 1건 ======
router.get("/latest", async (req, res) => {
  const { user_key, story_key } = req.query;
  if (!user_key || !story_key) {
    return res.status(400).json({ ok: false, error: "missing user_key or story_key" });
  }
  try {
    const sql = `
      SELECT *
        FROM tb_story_result
       WHERE TRIM(user_key)=TRIM(?) AND story_key=?
       ORDER BY client_utc DESC, id DESC
       LIMIT 1
    `;
    const [rows] = await pool.query(sql, [user_key, story_key]);
    if (rows.length === 0) return res.json({ ok: true, data: null });

    const row = rows[0];
    row.by_category = safeParseJSON(row.by_category, {});
    row.by_type = safeParseJSON(row.by_type, {});
    row.risk_bars = safeParseJSON(row.risk_bars, {});
    row.risk_bars_by_type = safeParseJSON(row.risk_bars_by_type, {});
    row.score = toNumber(row.score, 0);
    row.total = toNumber(row.total, 0);
    row.client_kst = toStrOrNull(row.client_kst);
    row.client_utc = toStrOrNull(row.client_utc);
    row.client_attempt_order = row.client_attempt_order === null ? null : toNumber(row.client_attempt_order, null);

    return res.json({ ok: true, data: row });
  } catch (err) {
    console.error("[/str/latest] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

// ====== 단일 결과 조회(id) ======
router.get("/:id", async (req, res) => {
  const { id } = req.params;
  if (!id) return res.status(400).json({ ok: false, error: "missing id" });
  try {
    const [rows] = await pool.query(`SELECT * FROM tb_story_result WHERE id=? LIMIT 1`, [id]);
    if (rows.length === 0) return res.status(404).json({ ok: false, error: "not_found" });

    const row = rows[0];
    row.by_category = safeParseJSON(row.by_category, {});
    row.by_type = safeParseJSON(row.by_type, {});
    row.risk_bars = safeParseJSON(row.risk_bars, {});
    row.risk_bars_by_type = safeParseJSON(row.risk_bars_by_type, {});
    row.score = toNumber(row.score, 0);
    row.total = toNumber(row.total, 0);
    row.client_kst = toStrOrNull(row.client_kst);
    row.client_utc = toStrOrNull(row.client_utc);
    row.client_attempt_order = row.client_attempt_order === null ? null : toNumber(row.client_attempt_order, null);

    return res.json({ ok: true, data: row });
  } catch (err) {
    console.error("[/str/:id] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

module.exports = router;

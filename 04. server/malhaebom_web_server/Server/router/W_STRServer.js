// Server/router/STRouter.js
const express = require("express");
const mysql = require("mysql2/promise");
const jwt = require("jsonwebtoken");

const router = express.Router();

/* ==== 공통 ENV / DB ==== */
const JWT_SECRET  = process.env.JWT_SECRET  || "malhaebom_sns";
const COOKIE_NAME = process.env.COOKIE_NAME || "mb_access";

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

/* ==== 유틸 ==== */
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
function pad(n) { return String(n).padStart(2, "0"); }

function composeUserKey(login_type, login_id) {
  if (!login_type || !login_id) return null;
  return login_type === "local" ? String(login_id) : `${login_type}:${login_id}`;
}

async function deriveUserKeyFromAuth(req) {
  try {
    const token = req.cookies?.[COOKIE_NAME];
    if (!token) return null;
    const decoded = jwt.verify(token, JWT_SECRET);
    const [rows] = await pool.query(
      `SELECT login_id, login_type
         FROM tb_user
        WHERE user_id = ?
        LIMIT 1`,
      [decoded.uid]
    );
    if (!rows.length) return null;
    const { login_id, login_type } = rows[0];
    return composeUserKey(login_type, login_id);
  } catch (e) {
    return null;
  }
}

router.use((req, _res, next) => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`[STR] ${req.method} ${req.originalUrl}`);
  }
  next();
});

/* ==== 결과 저장 ==== */
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
      user_key: bodyUserKey,
    } = req.body || {};

    // 1) 인증 쿠키로 우선 도출
    const authedKey = await deriveUserKeyFromAuth(req);

    // 2) 하위호환: 쿼리/바디에 온 값 (하지만 authedKey가 있으면 반드시 같아야 함)
    const claimedKey = (req.query.user_key || bodyUserKey || "").trim() || null;

    let user_key = authedKey || claimedKey;

    if (!user_key || user_key === "guest") {
      return res.status(401).json({ ok: false, error: "not_authed", detail: "로그인된 사용자만 저장 가능합니다." });
    }
    if (authedKey && claimedKey && authedKey !== claimedKey) {
      return res.status(403).json({ ok: false, error: "mismatched_user_key" });
    }
    if (!storyKey || !attemptTime) {
      return res.status(400).json({ ok: false, error: "missing storyKey or attemptTime" });
    }

    const [r] = await conn.query(
      `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?) AND story_key=?`,
      [user_key, storyKey]
    );
    const nextAttempt = Number(r?.[0]?.last_order || 0) + 1;

    const utc = new Date(attemptTime);
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
        client_utc,                          // DATETIME 'YYYY-MM-DD HH:mm:ss'
        toStrOrNull(clientKst),              // 문자열(KST 표기 저장 원하면 여기 사용)
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

/* ==== 유저 전체 히스토리(동화별 그룹) ==== */
router.get("/history/all", async (req, res) => {
  try {
    // 1) 쿼리 우선(관리용), 없으면 2) 인증 쿠키에서 도출
    let user_key = (req.query.user_key || "").trim();
    if (!user_key) {
      user_key = await deriveUserKeyFromAuth(req);
    }
    if (!user_key) {
      return res.status(401).json({ ok: false, error: "not_authed" });
    }

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
  
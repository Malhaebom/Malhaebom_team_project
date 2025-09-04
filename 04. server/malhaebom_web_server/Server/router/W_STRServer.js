// Server/router/W_STRServer.js
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
const pad2 = (n) => String(n).padStart(2, "0");
const isGuestKey = (k) => !!k && String(k).trim().toLowerCase() === "guest";

/** Date → 'YYYY-MM-DD HH:mm:ss' (UTC 기준) */
function toUtcSqlDatetime(date) {
  const y = date.getUTCFullYear();
  const m = pad2(date.getUTCMonth() + 1);
  const d = pad2(date.getUTCDate());
  const hh = pad2(date.getUTCHours());
  const mm = pad2(date.getUTCMinutes());
  const ss = pad2(date.getUTCSeconds());
  return `${y}-${m}-${d} ${hh}:${mm}:${ss}`;
}

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
  } catch (_e) {
    return null;
  }
}

router.use((req, _res, next) => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`[W_STR] ${req.method} ${req.originalUrl}`);
  }
  next();
});

/* 디버그: 내가 인식한 user_key */
router.get("/whoami", async (req, res) => {
  const authedKey = await deriveUserKeyFromAuth(req);
  const claimedKey = (req.query.user_key || req.headers["x-user-key"] || req.body?.user_key || "").trim();
  res.json({
    ok: true,
    authedKey: authedKey || null,
    claimedKey: claimedKey || null,
    used: authedKey || (!isGuestKey(claimedKey) ? claimedKey || null : null),
  });
});

/* ==== 결과 저장 ==== */
router.post("/attempt", async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();

    const {
      storyTitle,
      storyKey,
      attemptTime,     // ISO string 기대 (없을 수 있음)
      clientKst,       // 표시용 문자열 (선택)
      score,
      total,
      byCategory = {},
      byType = {},
      riskBars = {},
      riskBarsByType = {},
      user_key: bodyUserKey,
    } = req.body || {};

    // 1) 인증 쿠키 우선
    const authedKey = await deriveUserKeyFromAuth(req);
    // 2) 쿼리/헤더/바디 주장값
    const claimedKey = (req.query.user_key || req.headers["x-user-key"] || bodyUserKey || "").trim() || null;

    // ★ 규칙: 쿠키가 있으면 무조건 쿠키 사용. 쿼리가 'guest'면 무시.
    //         쿠키가 없을 때만 claimedKey(단, guest 금지) 허용.
    let user_key = null;
    if (authedKey) {
      if (claimedKey && !isGuestKey(claimedKey) && claimedKey !== authedKey) {
        // 같은 사람이어야 함
        return res.status(403).json({ ok: false, error: "mismatched_user_key" });
      }
      user_key = authedKey;
    } else {
      if (!claimedKey || isGuestKey(claimedKey)) {
        return res.status(401).json({ ok: false, error: "not_authed", detail: "로그인된 사용자만 저장 가능합니다." });
      }
      user_key = claimedKey;
    }

    if (!storyKey) {
      return res.status(400).json({ ok: false, error: "missing_storyKey" });
    }

    // client_utc(NOT NULL) 보정
    let clientUtcStr;
    if (attemptTime) {
      const utc = new Date(attemptTime);
      clientUtcStr = isNaN(utc.getTime()) ? toUtcSqlDatetime(new Date()) : toUtcSqlDatetime(utc);
    } else {
      clientUtcStr = toUtcSqlDatetime(new Date());
    }

    // 다음 회차 계산
    const [lastRows] = await conn.query(
      `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?) AND story_key=?`,
      [user_key, storyKey]
    );
    const nextAttempt = Number(lastRows?.[0]?.last_order || 0) + 1;

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
        clientUtcStr,
        toStrOrNull(clientKst),
        JSON.stringify(byCategory || {}),
        JSON.stringify(byType || {}),
        JSON.stringify(riskBars || {}),
        JSON.stringify(riskBarsByType || {}),
      ]
    );

    return res.json({ ok: true, user_key, story_key: storyKey, attempt_order: nextAttempt });
  } catch (err) {
    console.error("[/str/attempt] error:", err);
    return res.status(500).json({
      ok: false,
      error: err.code || "db_error",
      detail: err.sqlMessage || String(err),
    });
  } finally {
    if (conn) conn.release();
  }
});

/* ==== 유저 전체 히스토리 ==== */
router.get("/history/all", async (req, res) => {
  try {
    let user_key = (req.query.user_key || req.headers["x-user-key"] || "").trim();
    if (!user_key || isGuestKey(user_key)) {
      user_key = await deriveUserKeyFromAuth(req);
    }
    if (!user_key) return res.status(401).json({ ok: false, error: "not_authed" });

    const sql = `
      SELECT id, user_key, story_key, story_title,
             client_attempt_order, score, total,
             client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type
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
        client_attempt_order: r.client_attempt_order == null ? null : toNumber(r.client_attempt_order, null),
        score: toNumber(r.score, 0),
        total: toNumber(r.total, 0),
        by_category: safeParseJSON(r.by_category, {}),
        by_type: safeParseJSON(r.by_type, {}),
        risk_bars: safeParseJSON(r.risk_bars, {}),
        risk_bars_by_type: safeParseJSON(r.risk_bars_by_type, {}),
      });
    }
    return res.json({ ok: true, data: Array.from(map.values()) });
  } catch (err) {
    console.error("[/str/history/all] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

module.exports = router;

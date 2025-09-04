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
const pad2 = (n) => String(n).padStart(2, "0");

function toUtcSqlDatetime(date) {
  const d = date instanceof Date ? date : new Date(date);
  const y = d.getUTCFullYear();
  const m = pad2(d.getUTCMonth() + 1);
  const da = pad2(d.getUTCDate());
  const hh = pad2(d.getUTCHours());
  const mm = pad2(d.getUTCMinutes());
  const ss = pad2(d.getUTCSeconds());
  return `${y}-${m}-${da} ${hh}:${mm}:${ss}`;
}

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

// ── 제목 정규화 & 별칭 매핑 ───────────────────────────────────────────
// 공백만 정리
function normalizeTitle(s) {
  return String(s || "").replace(/\s+/g, " ").trim();
}

// 흔한 오타/변형 + 영문 키 → 표준 한글 제목으로 통일
const TITLE_ALIASES = {
  // 영문 키 → 한글
  "mother_gloves": "어머니의 벙어리 장갑",
  "father_wedding": "아버지와 결혼식",
  "sons_bread": "아들의 호빵",
  "grandma_banana": "할머니와 바나나",
  "kkongdang_boribap": "꽁당 보리밥",

  // 오타/띄어쓰기 변형 → 표준
  "어머니와 벙어리장갑": "어머니의 벙어리 장갑",
  "어머니와 벙어리 장갑": "어머니의 벙어리 장갑",
  "공동보리밥": "꽁당 보리밥",
  "꽁당보리밥": "꽁당 보리밥",
};

function canonicalStoryKey(storyKey, storyTitle) {
  const raw = normalizeTitle(storyKey || storyTitle || "");
  if (!raw) return null;
  const aliased = TITLE_ALIASES[raw] || raw;
  return normalizeTitle(aliased);
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

// 요청에서 user_key 추출: 쿼리, 헤더, 쿠키 인증 순
async function resolveUserKey(req) {
  const fromQuery = (req.query.user_key || req.query.userKey || "").trim();
  const fromHeader = (req.headers["x-user-key"] || req.headers["x-userkey"] || "").toString().trim();
  const authed = await deriveUserKeyFromAuth(req);
  const k = fromQuery || fromHeader || authed || "";
  if (k === "guest" || !k) return null;
  return k;
}

router.use((req, _res, next) => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`[W_STR] ${req.method} ${req.originalUrl}`);
  }
  next();
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
    } = req.body || {};

    // 1) user_key
    const user_key = await resolveUserKey(req);
    if (!user_key) {
      return res.status(401).json({ ok: false, error: "not_authed", detail: "로그인된 사용자만 저장 가능합니다." });
    }

    // 2) story_key 정규화(앱과 동일한 규칙)
    const canonKey = canonicalStoryKey(storyKey, storyTitle);
    if (!canonKey) {
      return res.status(400).json({ ok: false, error: "missing_storyKey" });
    }
    const story_title = normalizeTitle(storyTitle || canonKey);

    // 3) client_utc (NOT NULL 보정)
    let clientUtcStr;
    if (attemptTime) {
      const utc = new Date(attemptTime);
      clientUtcStr = isNaN(utc.getTime()) ? toUtcSqlDatetime(new Date()) : toUtcSqlDatetime(utc);
    } else {
      clientUtcStr = toUtcSqlDatetime(new Date());
    }

    // 4) 다음 회차 계산: user_key + canonical story_key
    const [lastRows] = await conn.query(
      `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?) AND TRIM(story_key)=TRIM(?)`,
      [user_key, canonKey]
    );
    const nextAttempt = Number(lastRows?.[0]?.last_order || 0) + 1;

    // 5) INSERT
    await conn.query(
      `INSERT INTO tb_story_result
       (user_key, story_key, story_title, client_attempt_order, score, total, client_utc, client_kst,
        by_category, by_type, risk_bars, risk_bars_by_type)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        user_key,
        canonKey,
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

    return res.json({ ok: true, user_key, story_key: canonKey, attempt_order: nextAttempt });
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

/* ==== 유저 전체 히스토리(동화별 그룹) ==== */
router.get("/history/all", async (req, res) => {
  try {
    let user_key = await resolveUserKey(req);
    if (!user_key) {
      return res.status(401).json({ ok: false, error: "not_authed" });
    }

    const sql = `
      SELECT id, user_key, story_key, story_title,
             client_attempt_order, score, total,
             client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type
        FROM tb_story_result
       WHERE TRIM(user_key)=TRIM(?)
       ORDER BY story_key ASC, client_utc DESC, id DESC
    `;
    const [rows] = await pool.query(sql, [user_key]);

    const toNumOrNull = (v) => (v === null || v === undefined ? null : toNumber(v, null));

    const map = new Map();
    for (const r of rows) {
      const sk = r.story_key || "(unknown)";
      if (!map.has(sk)) {
        map.set(sk, {
          story_key: sk,
          story_title: toStrOrNull(r.story_title) || sk,
          records: [],
        });
      }
      map.get(sk).records.push({
        id: r.id,
        client_kst: toStrOrNull(r.client_kst),
        client_utc: toStrOrNull(r.client_utc),
        client_attempt_order: toNumOrNull(r.client_attempt_order),
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
    return res.status(500).json({
      ok: false,
      error: err.code || "db_error",
      detail: err.sqlMessage || String(err),
    });
  }
});

module.exports = router;

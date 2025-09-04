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

/* ───── (중요) story_key/제목 정규화: 슬러그 표준화 ───── */
function nspace(s){ return String(s||"").replace(/\s+/g," ").trim(); }
function ntitle(s){
  let x = nspace(s);
  x = x.replaceAll("병어리","벙어리");
  x = x.replaceAll("어머니와","어머니의");
  x = x.replaceAll("벙어리장갑","벙어리 장갑");
  x = x.replaceAll("꽁당보리밥","꽁당 보리밥");
  x = x.replaceAll("할머니와바나나","할머니와 바나나");
  return x;
}
const BASE_STORIES = [
  { key: "mother_gloves",     title: "어머니의 벙어리 장갑" },
  { key: "father_wedding",    title: "아버지와 결혼식" },
  { key: "sons_bread",        title: "아들의 호빵" },
  { key: "grandma_banana",    title: "할머니와 바나나" },
  { key: "kkongdang_boribap", title: "꽁당 보리밥" },
];
const TITLE_TO_SLUG = new Map(BASE_STORIES.map(b => [ntitle(b.title), b.key]));
const SLUG_TO_TITLE = new Map(BASE_STORIES.map(b => [b.key, b.title]));
function toSlugFromAny(story_key_or_title, story_title_fallback=""){
  if (SLUG_TO_TITLE.has(story_key_or_title)) return story_key_or_title; // 이미 슬러그
  const t1 = ntitle(story_key_or_title);
  const t2 = ntitle(story_title_fallback);
  return TITLE_TO_SLUG.get(t1) || TITLE_TO_SLUG.get(t2) || story_key_or_title;
}

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

/* 테스트 데이터 추가 (개발용) 그대로 사용 가능 */
router.post("/test-data", async (req, res) => {
  try {
    const { user_key = "test_user" } = req.body;

    const testData = [
      {
        user_key,
        story_key: "mother_gloves",
        story_title: "어머니의 벙어리 장갑",
        client_attempt_order: 1,
        score: 32,
        total: 40,
        client_utc: toUtcSqlDatetime(new Date()),
        client_kst: "2024-01-15 14:30:00",
        by_category: JSON.stringify({ B: { correct: 3 }, C: { correct: 4 }, D: { correct: 4 } }),
        by_type: JSON.stringify({ "직접화행": { correct: 4 }, "간접화행": { correct: 4 } }),
        risk_bars: JSON.stringify({ A: 8, AI: 8, B: 6, C: 8, D: 8 }),
        risk_bars_by_type: JSON.stringify({ "직접화행": 0.2, "간접화행": 0.2 })
      },
      {
        user_key,
        story_key: "father_wedding",
        story_title: "아버지와 결혼식",
        client_attempt_order: 1,
        score: 28,
        total: 40,
        client_utc: toUtcSqlDatetime(new Date(Date.now() - 86400000)),
        client_kst: "2024-01-14 10:15:00",
        by_category: JSON.stringify({ B: { correct: 3 }, C: { correct: 3 }, D: { correct: 4 } }),
        by_type: JSON.stringify({ "직접화행": { correct: 4 }, "간접화행": { correct: 3 } }),
        risk_bars: JSON.stringify({ A: 8, AI: 6, B: 6, C: 6, D: 8 }),
        risk_bars_by_type: JSON.stringify({ "직접화행": 0.2, "간접화행": 0.4 })
      }
    ];

    for (const data of testData) {
      await pool.query(
        `INSERT INTO tb_story_result
         (user_key, story_key, story_title, client_attempt_order, score, total, client_utc, client_kst,
          by_category, by_type, risk_bars, risk_bars_by_type)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          data.user_key,
          data.story_key,
          data.story_title,
          data.client_attempt_order,
          data.score,
          data.total,
          data.client_utc,
          data.client_kst,
          data.by_category,
          data.by_type,
          data.risk_bars,
          data.risk_bars_by_type,
        ]
      );
    }

    res.json({ ok: true, message: "테스트 데이터가 추가되었습니다.", user_key });
  } catch (err) {
    console.error("[/str/test-data] error:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* ==== 결과 저장 ==== */
router.post("/attempt", async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();

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

    // 1) 인증 쿠키 우선
    const authedKey = await deriveUserKeyFromAuth(req);
    // 2) 쿼리/헤더/바디 주장값
    const claimedKey = (req.query.user_key || req.headers["x-user-key"] || bodyUserKey || "").trim() || null;

    // 규칙: 쿠키 있으면 쿠키 사용(다르면 403), 없으면 claimedKey(guest 금지) 사용
    let user_key = null;
    if (authedKey) {
      if (claimedKey && !isGuestKey(claimedKey) && claimedKey !== authedKey) {
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

    // ★ 입력값을 표준화: 슬러그/제목 확정
    const slug = toSlugFromAny(storyKey, storyTitle);
    const canonicalTitle = SLUG_TO_TITLE.get(slug) || ntitle(storyTitle || storyKey);

    // client_utc(NOT NULL) 보정
    let clientUtcStr;
    if (attemptTime) {
      const utc = new Date(attemptTime);
      clientUtcStr = isNaN(utc.getTime()) ? toUtcSqlDatetime(new Date()) : toUtcSqlDatetime(utc);
    } else {
      clientUtcStr = toUtcSqlDatetime(new Date());
    }

    // ★ 다음 회차: 유저의 모든 결과 중 slug로 환산해 비교(과거 한글키 포함)
    const [rows] = await conn.query(
      `SELECT story_key, story_title, client_attempt_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?)`,
      [user_key]
    );
    let last_order = 0;
    for (const r of rows) {
      const rslug = toSlugFromAny(r.story_key, r.story_title);
      if (rslug === slug) {
        last_order = Math.max(last_order, Number(r.client_attempt_order || 0));
      }
    }
    const nextAttempt = last_order + 1;

    await conn.query(
      `INSERT INTO tb_story_result
       (user_key, story_key, story_title, client_attempt_order, score, total, client_utc, client_kst,
        by_category, by_type, risk_bars, risk_bars_by_type)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        user_key,
        slug,                       // ← 슬러그로 저장
        canonicalTitle,             // ← 표준 제목으로 저장
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

    return res.json({ ok: true, user_key, story_key: slug, attempt_order: nextAttempt });
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
       ORDER BY client_utc DESC, id DESC
    `;
    const [rows] = await pool.query(sql, [user_key]);

    // ★ 서버에서 슬러그로 그룹핑(과거 한글키도 흡수)
    const map = new Map(); // slug -> group
    for (const r of rows) {
      const slug  = toSlugFromAny(r.story_key, r.story_title);
      const title = SLUG_TO_TITLE.get(slug) || ntitle(r.story_title || slug);

      if (!map.has(slug)) {
        map.set(slug, { story_key: slug, story_title: title, records: [] });
      }
      map.get(slug).records.push({
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

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
// Buffer/문자열/객체 안전 파싱
function safeParseJSON(jsonVal, fallback = null) {
  try {
    if (jsonVal == null) return fallback;
    if (Buffer.isBuffer(jsonVal)) {
      const s = jsonVal.toString("utf8");
      return s ? JSON.parse(s) : fallback;
    }
    if (typeof jsonVal === "object") return jsonVal;
    const s = String(jsonVal).trim();
    return s ? JSON.parse(s) : fallback;
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

// UTC Date → 'YYYY년 MM월 DD일 HH:MM' (KST 라벨)
function toKstLabelFromUtcDate(utcDate) {
  const k = new Date(utcDate.getTime() + 9 * 60 * 60 * 1000);
  const pad = (n) => String(n).padStart(2, "0");
  const Y = k.getFullYear();
  const M = pad(k.getMonth() + 1);
  const D = pad(k.getDate());
  const h = pad(k.getHours());
  const m = pad(k.getMinutes());
  return `${Y}년 ${M}월 ${D}일 ${h}:${m}`;
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

/* ───── 제목/슬러그 정규화 ───── */
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

// 표준 슬러그(짧은 키) 사용
const BASE_STORIES = [
  { key: "mother_gloves",  title: "어머니의 벙어리 장갑" },
  { key: "father_wedding", title: "아버지와 결혼식" },
  { key: "sons_bread",     title: "아들의 호빵" },
  { key: "grandma_banana", title: "할머니와 바나나" },
  { key: "kkong_boribap",  title: "꽁당 보리밥" },
];
const TITLE_TO_SLUG = new Map(BASE_STORIES.map(b => [ntitle(b.title), b.key]));
const SLUG_TO_TITLE = new Map(BASE_STORIES.map(b => [b.key, b.title]));
// 레거시 → 표준
const LEGACY_SLUG_MAP = new Map([
  ["kkongdang_boribap", "kkong_boribap"],
]);
// 저장 전용: 표준 → 레거시(ENUM 호환)
const STORAGE_SLUG_MAP = new Map([
  ["kkong_boribap", "kkongdang_boribap"],
]);

function toSlugFromAny(story_key_or_title, story_title_fallback=""){
  const raw = String(story_key_or_title || "").trim();
  if (LEGACY_SLUG_MAP.has(raw)) return LEGACY_SLUG_MAP.get(raw); // old→new
  if (SLUG_TO_TITLE.has(raw)) return raw;                         // already new
  const t1 = ntitle(story_key_or_title);
  const t2 = ntitle(story_title_fallback);
  const byTitle = TITLE_TO_SLUG.get(t1) || TITLE_TO_SLUG.get(t2);
  if (byTitle) return byTitle;
  if (LEGACY_SLUG_MAP.has(t1)) return LEGACY_SLUG_MAP.get(t1);
  if (LEGACY_SLUG_MAP.has(t2)) return LEGACY_SLUG_MAP.get(t2);
  return raw;
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

/* ==== 결과 저장 ==== */
router.post("/attempt", async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();

    const {
      storyTitle,
      storyKey,
      attemptTime,
      score,
      total,
      byCategory = {},
      byType = {},
      riskBars = {},
      riskBarsByType = {},
      user_key: bodyUserKey,
    } = req.body || {};

    // 인증 키 결정
    const authedKey = await deriveUserKeyFromAuth(req);
    const claimedKey = (req.query.user_key || req.headers["x-user-key"] || bodyUserKey || "").trim() || null;

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

    // storyKey/Title 최소 한쪽은 필요
    if (!storyKey && !storyTitle) {
      return res.status(400).json({ ok: false, error: "missing_storyKey_and_title" });
    }

    // 표준화(표시는 표준), 저장은 ENUM 호환용 레거시 키로
    const slug = toSlugFromAny(storyKey || "", storyTitle || "");
    const canonicalTitle = SLUG_TO_TITLE.get(slug) || ntitle(storyTitle || storyKey || slug);
    const dbSlug = STORAGE_SLUG_MAP.get(slug) || slug; // ← 저장용

    // 시간
    const utcDate = (() => {
      if (attemptTime) {
        const t = new Date(attemptTime);
        return isNaN(t.getTime()) ? new Date() : t;
      }
      return new Date();
    })();
    const clientUtcStr   = toUtcSqlDatetime(utcDate);
    const clientKstLabel = toKstLabelFromUtcDate(utcDate);

    // 다음 회차 계산
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
        dbSlug,                // ← 저장은 레거시 키
        canonicalTitle,
        nextAttempt,
        toNumber(score, 0),
        toNumber(total, 40),
        clientUtcStr,
        clientKstLabel,
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

    const map = new Map(); // slug -> group
    for (const r of rows) {
      const slug  = toSlugFromAny(r.story_key, r.story_title); // old→new 정규화
      const title = SLUG_TO_TITLE.get(slug) || ntitle(r.story_title || slug);

      if (!map.has(slug)) {
        map.set(slug, { story_key: slug, story_title: title, records: [] });
      }
      map.get(slug).records.push({
        id: r.id,
        client_kst: toStrOrNull(r.client_kst),
        client_utc: toStrOrNull(r.client_utc),
        client_attempt_order: r.client_attempt_order == null ? null : toNumber(r.client_attempt_order, null),
        by_category: safeParseJSON(r.by_category, {}),
        by_type: safeParseJSON(r.by_type, {}),
        risk_bars: safeParseJSON(r.risk_bars, {}),
        risk_bars_by_type: safeParseJSON(r.risk_bars_by_type, {}),
        score: toNumber(r.score, 0),
        total: toNumber(r.total, 0),
      });
    }
    return res.json({ ok: true, data: Array.from(map.values()) });
  } catch (err) {
    console.error("[/str/history/all] error:", err);
    return res.status(500).json({ ok: false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

module.exports = router;

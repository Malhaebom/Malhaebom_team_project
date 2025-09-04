// routes/str.js
const express = require("express");
const mysql = require("mysql2/promise");
const jwt = require("jsonwebtoken");
const cookie = require("cookie");

const router = express.Router();

const JWT_SECRET  = process.env.JWT_SECRET  || "malhaebom_sns";
const COOKIE_NAME = process.env.COOKIE_NAME || "mb_access";

const DB_CONFIG = {
  host    : process.env.DB_HOST     || "project-db-campus.smhrd.com",
  port    : Number(process.env.DB_PORT || 3307),
  user    : process.env.DB_USER     || "campus_25SW_BD_p3_3",
  password: process.env.DB_PASSWORD || "smhrd3",
  database: process.env.DB_NAME     || "campus_25SW_BD_p3_3",
};
const pool = mysql.createPool({ ...DB_CONFIG, waitForConnections:true, connectionLimit:10 });

// ───────── 공통 로그 미들웨어
router.use((req, _res, next) => {
  const ts = new Date().toISOString();
  console.groupCollapsed(`[STR] ${ts} ${req.method} ${req.originalUrl}`);
  console.log("headers:", {
    host: req.headers.host,
    cookie: req.headers.cookie ? "(present)" : "(none)",
    "x-user-key": req.headers["x-user-key"] || "(none)",
    authorization: req.headers.authorization ? "(present)" : "(none)",
  });
  if (req.method !== "GET") {
    try { console.log("body:", JSON.stringify(req.body, null, 2)); } catch { console.log("body:(unprintable)"); }
  }
  console.groupEnd();
  next();
});

// ───────── 유틸
function safeParseJSON(jsonVal, fallback = null) {
  try {
    if (jsonVal == null) return fallback;
    if (typeof jsonVal === "object") return jsonVal;
    const s = String(jsonVal).trim();
    if (!s) return fallback;
    const once = JSON.parse(s);
    if (typeof once === "string") {
      try { return JSON.parse(once); } catch { return fallback; }
    }
    return once ?? fallback;
  } catch {
    return fallback;
  }
}
const toNumber = (n, d = 0) => (Number.isFinite(Number(n)) ? Number(n) : d);
const toStrOrNull = (s) => {
  if (s == null) return null;
  const t = String(s).trim();
  return t ? t : null;
};
const pad2 = (n) => String(n).padStart(2, "0");
const isGuestKey = (k) => !!k && String(k).trim().toLowerCase() === "guest";

function toUtcSqlDatetime(date) {
  const d = (date instanceof Date) ? date : new Date(date);
  if (isNaN(d.getTime())) return null;
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth()+1)}-${pad2(d.getUTCDate())} ${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}:${pad2(d.getUTCSeconds())}`;
}
function toKstLabelFromUtcDate(utcDate) {
  const d = (utcDate instanceof Date) ? utcDate : new Date(utcDate);
  if (isNaN(d.getTime())) return "";
  const k = new Date(d.getTime() + 9*60*60*1000);
  return `${k.getFullYear()}년 ${pad2(k.getMonth()+1)}월 ${pad2(k.getDate())}일 ${pad2(k.getHours())}:${pad2(k.getMinutes())}`;
}
function composeUserKey(login_type, login_id) {
  if (!login_type || !login_id) return null;
  return `${String(login_type).toLowerCase()}:${String(login_id)}`;
}

// Authorization: Bearer <jwt> 또는 쿠키의 JWT, 또는 헤더/쿼리의 x-user-key / user_key
async function deriveUserKeyFromAuth(req) {
  // 1) Authorization Bearer
  try {
    const h = req.headers.authorization || "";
    if (h.startsWith("Bearer ")) {
      const token = h.slice(7);
      const p = jwt.verify(token, JWT_SECRET);
      const { login_type, login_id, uid } = p || {};
      const keyByType = composeUserKey(login_type, login_id);
      if (keyByType) return keyByType;
      if (uid != null) return `uid:${uid}`;
    }
  } catch (_e) {}

  // 2) Cookie JWT
  try {
    const raw = req.headers.cookie || "";
    const ck = cookie.parse(raw || "");
    const t = ck[COOKIE_NAME];
    if (t) {
      const p = jwt.verify(t, JWT_SECRET);
      const { login_type, login_id, uid } = p || {};
      const keyByType = composeUserKey(login_type, login_id);
      if (keyByType) return keyByType;
      if (uid != null) return `uid:${uid}`;
    }
  } catch (_e) {}

  // 3) 헤더/쿼리 바디 직접키 (여기까지 오면 신뢰도 보조)
  const direct = (req.headers["x-user-key"] || req.query.user_key || req.body?.user_key || "").trim();
  if (direct && direct.toLowerCase() !== "guest") return direct;

  return null;
}

// ───────── 제목/슬러그 정규화
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
function squashSpaces(s="") { return String(s||"").replace(/\s+/g," ").trim(); }
function normalizeKoTitleCore(s="") { return ntitle(s).replace(/\s+/g,""); }

const BASE_STORIES = [
  { key: "mother_gloves",  title: "어머니의 벙어리 장갑" },
  { key: "father_wedding", title: "아버지와 결혼식" },
  { key: "sons_bread",     title: "아들의 호빵" },
  { key: "grandma_banana", title: "할머니와 바나나" },
  { key: "kkong_boribap",  title: "꽁당 보리밥" },
];
const TITLE_TO_SLUG = new Map(BASE_STORIES.map(b => [ntitle(b.title), b.key]));
const SLUG_TO_TITLE = new Map(BASE_STORIES.map(b => [b.key, b.title]));
const KOCORE_TO_SLUG = new Map(BASE_STORIES.map(b => [normalizeKoTitleCore(b.title), b.key]));
const LEGACY_SLUG_MAP = new Map([
  ["kkongdang_boribap","kkong_boribap"],
  ["kkong boribap","kkong_boribap"],
  ["kkongboribap","kkong_boribap"],
]);

function toSlugFromAny(story_key_or_title, story_title_fallback=""){
  const raw = String(story_key_or_title || "").trim();
  const fall = String(story_title_fallback || "").trim();
  if (LEGACY_SLUG_MAP.has(raw)) return LEGACY_SLUG_MAP.get(raw);
  if (SLUG_TO_TITLE.has(raw)) return raw;
  const title = ntitle(raw || fall);
  const exact = TITLE_TO_SLUG.get(title);
  if (exact) return exact;
  const core = normalizeKoTitleCore(title);
  const byCore = KOCORE_TO_SLUG.get(core);
  if (byCore) return byCore;
  return nspace(raw || fall || "story");
}

// ───────── whoami (서버 기준만 신뢰)
router.get("/whoami", async (req, res) => {
  try {
    const authedKey = await deriveUserKeyFromAuth(req);
    const claimedKey = (req.query.user_key || req.headers["x-user-key"] || "").trim() || null;
    const used = authedKey || claimedKey || null;
    return res.json({ ok:true, isAuthed:!!authedKey, authedKey, claimedKey, used, identity: { user_key: used } });
  } catch (e) {
    return res.status(500).json({ ok:false, error:"whoami_error", detail:String(e) });
  }
});

// ───────── 결과 저장  (story_key=slug 로 고정)
router.post("/attempt", async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();

    const {
      storyTitle, storyKey, attemptTime, score, total,
      byCategory = {}, byType = {}, riskBars = {}, riskBarsByType = {},
      user_key: bodyUserKey,
    } = req.body || {};

    const authedKey = await deriveUserKeyFromAuth(req);
    const claimedKey = (req.query.user_key || req.headers["x-user-key"] || bodyUserKey || "").trim() || null;
    const user_key = authedKey || claimedKey;

    console.groupCollapsed("[attempt] keys");
    console.log("authedKey:", authedKey);
    console.log("claimedKey:", claimedKey);
    console.log("=> used user_key:", user_key);
    console.groupEnd();

    if (!user_key || isGuestKey(user_key)) {
      return res.status(401).json({ ok:false, error:"not_authed" });
    }
    if (!storyKey && !storyTitle) {
      return res.status(400).json({ ok:false, error:"missing_storyKey_and_title" });
    }

    const slug = toSlugFromAny(storyKey || "", storyTitle || "");
    const titleKo = SLUG_TO_TITLE.get(slug) || ntitle(storyTitle || storyKey || slug);

    const dbStoryKey   = slug;     // 핵심: slug
    const dbStoryTitle = titleKo;  // 한글 제목

    const utcDate = attemptTime && !isNaN(new Date(attemptTime).getTime())
      ? new Date(attemptTime) : new Date();
    const clientUtcStr   = toUtcSqlDatetime(utcDate);
    const clientKstLabel = toKstLabelFromUtcDate(utcDate);

    const [rows] = await conn.query(
      `SELECT story_key, story_title, client_attempt_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?)`, [user_key]
    );

    let last_order = 0;
    for (const r of rows) {
      const rslug = toSlugFromAny(r.story_key, r.story_title);
      if (rslug === slug) last_order = Math.max(last_order, Number(r.client_attempt_order || 0));
    }
    const nextAttempt = last_order + 1;

    const payload = [
      user_key, dbStoryKey, dbStoryTitle, nextAttempt,
      toNumber(score, 0), toNumber(total, 40),
      clientUtcStr, clientKstLabel,
      JSON.stringify(byCategory || {}), JSON.stringify(byType || {}),
      JSON.stringify(riskBars || {}), JSON.stringify(riskBarsByType || {}),
    ];

    await conn.query(
      `INSERT INTO tb_story_result
       (user_key, story_key, story_title, client_attempt_order, score, total, client_utc, client_kst,
        by_category, by_type, risk_bars, risk_bars_by_type)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      payload
    );

    const debug = req.query.debug === "1";
    const resp = { ok:true, user_key, story_key: slug, attempt_order: nextAttempt };
    if (debug) resp.__debug = { insert_payload: payload };
    return res.json(resp);
  } catch (err) {
    console.error("[/str/attempt] error:", err);
    return res.status(500).json({ ok:false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  } finally {
    if (conn) conn.release();
  }
});

// ───────── 히스토리 조회
router.get("/history/all", async (req, res) => {
  try {
    const claimedKeyRaw = (req.query.user_key || req.headers["x-user-key"] || "").trim();
    const claimedKey = claimedKeyRaw && !isGuestKey(claimedKeyRaw) ? claimedKeyRaw : null;
    const authedKey  = await deriveUserKeyFromAuth(req);
    const primaryKey = claimedKey || authedKey || null;

    console.groupCollapsed("[history/all] keys");
    console.log("claimedKeyRaw:", claimedKeyRaw);
    console.log("authedKey:", authedKey);
    console.log("=> primaryKey:", primaryKey);
    console.groupEnd();

    if (!primaryKey) return res.status(401).json({ ok:false, error:"not_authed" });

    const SQL = `
      SELECT id, user_key, story_key, story_title,
             client_attempt_order, score, total,
             client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type
        FROM tb_story_result
       WHERE TRIM(user_key)=TRIM(?)
       ORDER BY client_utc DESC, id DESC
    `;
    let [rows] = await pool.query(SQL, [primaryKey]);

    console.groupCollapsed("[history/all] raw rows");
    console.log("rowCount:", rows.length);
    console.log("sample[0..2]:", rows.slice(0,3));
    console.groupEnd();

    // 컬럼 타입 확인 로그
    if (rows[0]) {
      const r = rows[0];
      const types = Object.fromEntries(Object.entries(r).map(([k,v]) => [k, v===null?"null":typeof v]));
      console.log("[history/all] typeof first row:", types);
    }

    if ((!rows || rows.length === 0) && authedKey && claimedKey && authedKey !== claimedKey) {
      console.warn("[history/all] 0 rows with primaryKey, retry authedKey");
      const [rows2] = await pool.query(SQL, [authedKey]);
      if (rows2 && rows2.length) rows = rows2;
    }

    const map = new Map();
    for (const r of rows) {
      const slug  = toSlugFromAny(r.story_key, r.story_title);
      const title = SLUG_TO_TITLE.get(slug) || ntitle(r.story_title || slug);
      if (!map.has(slug)) map.set(slug, { story_key: slug, story_title: title, records: [] });
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

    const data = Array.from(map.values());
    return res.json({ ok:true, data });
  } catch (err) {
    console.error("[/str/history/all] error:", err);
    return res.status(500).json({ ok:false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

module.exports = router;

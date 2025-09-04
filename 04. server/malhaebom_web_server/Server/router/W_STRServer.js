// routes/str.js
const express = require("express");
const mysql = require("mysql2/promise");
const jwt = require("jsonwebtoken");

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
  });
  if (req.method !== "GET") {
    try { console.log("body:", JSON.stringify(req.body, null, 2)); } catch { console.log("body:(unprintable)"); }
  }
  console.groupEnd();
  next();
});

// ───────── 유틸 (동일)
function safeParseJSON(jsonVal, fallback = null) { /* 생략: 기존 그대로 */ }
const toNumber = (n, d = 0) => (Number.isFinite(Number(n)) ? Number(n) : d);
const toStrOrNull = (s) => { /* 생략 */ };
const pad2 = (n) => String(n).padStart(2, "0");
const isGuestKey = (k) => !!k && String(k).trim().toLowerCase() === "guest";
function toUtcSqlDatetime(date) { /* 생략 */ }
function toKstLabelFromUtcDate(utcDate) { /* 생략 */ }
function composeUserKey(login_type, login_id) { /* 생략 */ }
async function deriveUserKeyFromAuth(req) { /* 생략 */ }

// ───────── 제목/슬러그 정규화 (동일)
function nspace(s){ /* 생략 */ }
function ntitle(s){ /* 생략 */ }
function squashSpaces(s="") { /* 생략 */ }
function normalizeKoTitleCore(s="") { /* 생략 */ }
const BASE_STORIES = [ /* 생략 */ ];
const TITLE_TO_SLUG = new Map(BASE_STORIES.map(b => [ntitle(b.title), b.key]));
const SLUG_TO_TITLE = new Map(BASE_STORIES.map(b => [b.key, b.title]));
const KOCORE_TO_SLUG = new Map(BASE_STORIES.map(b => [normalizeKoTitleCore(b.title), b.key]));
const LEGACY_SLUG_MAP = new Map([
  ["kkongdang_boribap","kkong_boribap"],["kkong boribap","kkong_boribap"],["kkongboribap","kkong_boribap"],
]);
function toSlugFromAny(story_key_or_title, story_title_fallback=""){ /* 생략 */ }

// ───────── whoami
router.get("/whoami", async (req, res) => {
  try {
    const authedKey = await deriveUserKeyFromAuth(req);
    const claimedKey = (req.query.user_key || req.headers["x-user-key"] || "").trim() || null;
    const used = authedKey || claimedKey || null;
    console.log("[whoami] authedKey:", authedKey, "claimedKey:", claimedKey, "=> used:", used);
    return res.json({ ok:true, isAuthed:!!authedKey, authedKey, claimedKey, used });
  } catch (e) {
    console.error("[whoami] error:", e);
    return res.status(500).json({ ok:false, error:"whoami_error", detail:String(e) });
  }
});

// ───────── 결과 저장
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
      console.warn("[attempt] reject: not_authed");
      return res.status(401).json({ ok:false, error:"not_authed" });
    }

    if (!storyKey && !storyTitle) {
      console.warn("[attempt] reject: missing_storyKey_and_title");
      return res.status(400).json({ ok:false, error:"missing_storyKey_and_title" });
    }

    const slug = toSlugFromAny(storyKey || "", storyTitle || "");
    const canonicalTitle = SLUG_TO_SLUG_TO_TITLE_LOG("attempt", slug) || ntitle(storyTitle || storyKey || slug);
    function SLUG_TO_SLUG_TO_TITLE_LOG(tag, s){
      const t = SLUG_TO_TITLE.get(s);
      console.log(`[${tag}] slug:${s} -> title:`, t || "(fallback)");
      return t;
    }

    const dbStoryKey = canonicalTitle;

    const utcDate = attemptTime && !isNaN(new Date(attemptTime).getTime())
      ? new Date(attemptTime) : new Date();
    const clientUtcStr   = toUtcSqlDatetime(utcDate);
    const clientKstLabel = toKstLabelFromUtcDate(utcDate);

    const [rows] = await conn.query(
      `SELECT story_key, story_title, client_attempt_order
         FROM tb_story_result
        WHERE TRIM(user_key)=TRIM(?)`, [user_key]
    );
    console.log("[attempt] existing rows for user:", rows.length);

    let last_order = 0;
    for (const r of rows) {
      const rslug = toSlugFromAny(r.story_key, r.story_title);
      if (rslug === slug) last_order = Math.max(last_order, Number(r.client_attempt_order || 0));
    }
    const nextAttempt = last_order + 1;

    const payload = [
      user_key, dbStoryKey, canonicalTitle, nextAttempt,
      toNumber(score, 0), toNumber(total, 40),
      clientUtcStr, clientKstLabel,
      JSON.stringify(byCategory || {}), JSON.stringify(byType || {}),
      JSON.stringify(riskBars || {}), JSON.stringify(riskBarsByType || {}),
    ];
    console.groupCollapsed("[attempt] INSERT values");
    console.log({
      user_key, dbStoryKey, canonicalTitle, nextAttempt,
      score: toNumber(score,0), total: toNumber(total,40),
      clientUtcStr, clientKstLabel,
      byCategory, byType, riskBars, riskBarsByType,
    });
    console.groupEnd();

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

    const debug = req.query.debug === "1";
    const data = Array.from(map.values());
    const resp = { ok:true, data };
    if (debug) {
      resp.__debug = {
        input_primaryKey: primaryKey,
        raw_rowCount: rows.length,
        raw_rows_sample: rows.slice(0,5),
      };
    }
    return res.json(resp);
  } catch (err) {
    console.error("[/str/history/all] error:", err);
    return res.status(500).json({ ok:false, error: err.code || "db_error", detail: err.sqlMessage || String(err) });
  }
});

module.exports = router;

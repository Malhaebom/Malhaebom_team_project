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
  // 웹/쿠키는 local 접두사 없이도 들어오므로 서버는 두 포맷을 모두 인식하도록만 하고
  // 캐논은 "원본 그대로" 사용
  return login_type === "local" ? String(login_id) : `${login_type}:${login_id}`;
}

/** user_key 동등성(포맷 차이 허용) 비교: 'abc' ≡ 'local:abc' */
function sameUserKey(a, b) {
  if (!a || !b) return false;
  const A = String(a).trim();
  const B = String(b).trim();
  if (A === B) return true;
  // local: 접두사만 다르면 같은 사용자로 간주
  const stripLocal = (s) => s.startsWith("local:") ? s.slice(6) : s;
  return stripLocal(A) === stripLocal(B);
}

/** DB 조회/집계용으로 변형 후보 2개 생성: ['abc', 'local:abc'] 또는 그대로 2개 */
function keyVariants(k) {
  const s = String(k || "").trim();
  if (!s) return [];
  if (s.includes(":")) {
    if (s.startsWith("local:")) return [s, s.slice(6)];
    return [s]; // kakao:, naver:, google: 등은 그대로 1개만
  }
  return [s, `local:${s}`];
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

/** 쿼리/바디/헤더 어디서든 user_key/userKey 읽기 */
function readClaimedKey(req) {
  const q = req.query || {};
  const b = req.body || {};
  const h = Object.fromEntries(
    Object.entries(req.headers || {}).map(([k, v]) => [String(k).toLowerCase(), v])
  );
  const pick = (...keys) => {
    for (const k of keys) {
      const v = (q[k] ?? b[k] ?? h[k]) ?? null;
      if (v != null) {
        const s = String(v).trim();
        if (s) return s;
      }
    }
    return null;
  };
  return pick("user_key", "userKey", "x-user-key", "x-userkey");
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
      user_key: bodyUserKey, // 호환
      userKey: bodyUserKey2, // 호환
    } = req.body || {};

    // 1) 인증 쿠키 우선
    const authedKey = await deriveUserKeyFromAuth(req);

    // 2) 쿼리/바디/헤더에서 주장된 키 (guest/빈 문자열은 무시)
    const claimedAny = readClaimedKey(req) || bodyUserKey || bodyUserKey2 || "";
    const claimedKey = (claimedAny && claimedAny !== "guest") ? claimedAny : null;

    // 최종 user_key 결정 (둘 다 있으면 authedKey를 우선 사용)
    let user_key = authedKey || claimedKey;
    if (!user_key) {
      return res.status(401).json({ ok: false, error: "not_authed", detail: "로그인된 사용자만 저장 가능합니다." });
    }

    // 포맷 차이(local: 접두사)로 인한 403 방지
    if (authedKey && claimedKey && !sameUserKey(authedKey, claimedKey)) {
      return res.status(403).json({ ok: false, error: "mismatched_user_key" });
    }

    if (!storyKey) {
      return res.status(400).json({ ok: false, error: "missing_storyKey" });
    }

    // client_utc (NOT NULL) 보정
    let clientUtcStr;
    if (attemptTime) {
      const utc = new Date(attemptTime);
      clientUtcStr = isNaN(utc.getTime()) ? toUtcSqlDatetime(new Date()) : toUtcSqlDatetime(utc);
    } else {
      clientUtcStr = toUtcSqlDatetime(new Date());
    }

    // 동일 story_key의 다음 회차 계산: user_key의 두 포맷 모두 매칭
    const vars = keyVariants(user_key);
    let lastOrder = 0;
    if (vars.length === 1) {
      const [r] = await conn.query(
        `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
           FROM tb_story_result
          WHERE TRIM(user_key)=TRIM(?) AND story_key=?`,
        [vars[0], storyKey]
      );
      lastOrder = Number(r?.[0]?.last_order || 0);
    } else {
      const [r] = await conn.query(
        `SELECT COALESCE(MAX(client_attempt_order), 0) AS last_order
           FROM tb_story_result
          WHERE story_key=?
            AND (TRIM(user_key)=TRIM(?) OR TRIM(user_key)=TRIM(?))`,
        [storyKey, vars[0], vars[1]]
      );
      lastOrder = Number(r?.[0]?.last_order || 0);
    }
    const nextAttempt = lastOrder + 1;

    const story_title = storyTitle || storyKey;

    // INSERT
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

    // 디버그 로그
    if (process.env.NODE_ENV !== "production") {
      console.log("[W_STR/attempt] saved:", { user_key, storyKey, nextAttempt, clientUtcStr });
    }

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

/* ==== 유저 전체 히스토리(동화별 그룹) ==== */
router.get("/history/all", async (req, res) => {
  let conn;
  try {
    conn = await pool.getConnection();

    // 1) 쿼리 우선(관리용), 없으면 2) 인증 쿠키에서 도출
    let claimed = readClaimedKey(req) || (req.query.user_key || "").trim();
    if (claimed === "guest") claimed = "";
    let user_key = claimed || (await deriveUserKeyFromAuth(req)) || "";
    if (!user_key) {
      return res.status(401).json({ ok: false, error: "not_authed" });
    }

    const vars = keyVariants(user_key);
    let sql;
    let args;
    if (vars.length === 1) {
      sql = `
        SELECT id, user_key, story_key, story_title,
               client_attempt_order, score, total,
               client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type
          FROM tb_story_result
         WHERE TRIM(user_key)=TRIM(?)
         ORDER BY story_key ASC, client_utc DESC, id DESC`;
      args = [vars[0]];
    } else {
      sql = `
        SELECT id, user_key, story_key, story_title,
               client_attempt_order, score, total,
               client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type
          FROM tb_story_result
         WHERE TRIM(user_key)=TRIM(?) OR TRIM(user_key)=TRIM(?)
         ORDER BY story_key ASC, client_utc DESC, id DESC`;
      args = vars;
    }

    const [rows] = await conn.query(sql, args);

    const toNumOrNull = (v) => (v === null || v === undefined ? null : toNumber(v, null));

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
  } finally {
    if (conn) conn.release();
  }
});

module.exports = router;

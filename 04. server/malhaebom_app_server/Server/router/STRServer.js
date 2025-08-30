// routes/STRServer.js
require("dotenv").config();

const express = require("express");
const router = express.Router();
const mysql = require("mysql2/promise");

// ── 설정 ─────────────────────────────────────────────────────────────────────
const {
  DB_HOST = "127.0.0.1",
  DB_PORT = "3306",
  DB_USER = "root",
  DB_PASSWORD = "",
  DB_NAME = "appdb",
  STR_ALLOW_GUEST = "false", // true면 user_key 없이도 저장(디버깅용)
} = process.env;

const ALLOW_GUEST = String(STR_ALLOW_GUEST).toLowerCase() === "true";

// ── DB Pool ──────────────────────────────────────────────────────────────────
const pool = mysql.createPool({
  host: DB_HOST,
  port: Number(DB_PORT),
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  namedPlaceholders: true,
});

// ── 유틸 ──────────────────────────────────────────────────────────────────────
function normalizeTitle(s) {
  return String(s || "").replace(/\s+/g, " ").trim();
}
function computeRiskBars(by) {
  if (!by || typeof by !== "object") return {};
  const out = {};
  for (const k of Object.keys(by)) {
    const v = by[k] || {};
    const correct = Number(v.correct || 0);
    const total   = Number(v.total   || 0);
    out[k] = total > 0 ? 1 - correct / total : 0.5;
  }
  return out;
}
function isoToMysqlDatetime(iso) {
  // 'YYYY-MM-DD HH:MM:SS'
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth()+1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}

// user_key 생성기: 로컬(userId) 또는 SNS(snsUserId+snsLoginType) → user_key
function buildUserKey({ userId, snsUserId, snsLoginType } = {}) {
  if (userId && String(userId).trim()) return String(userId).trim();
  if (snsUserId && snsLoginType) {
    const t = String(snsLoginType).toLowerCase();
    if (["kakao", "google", "naver"].includes(t)) {
      return `${t}:${String(snsUserId).trim()}`;
    }
  }
  return null;
}

/**
 * 클라에서 보낼 수 있는 위치:
 *  - body.userKey  또는 body.userId / body.snsUserId+snsLoginType
 *  - headers['x-user-key'] 또는 x-user-id / x-sns-user-id + x-sns-login-type
 *  - query 동일 키
 */
// routes/STRServer.js 안의 resolveIdentity() 함수만 이걸로 교체
function resolveIdentity(req) {
  const b = req.body  || {};
  const q = req.query || {};
  const h = Object.fromEntries(
    Object.entries(req.headers || {}).map(([k, v]) => [String(k).toLowerCase(), v])
  );

  const readAny = (obj, keys) => {
    for (const k of keys) {
      if (obj[k] == null) continue;
      const s = String(obj[k]).trim();
      if (s) return s;
    }
    return null;
  };

  // 0) userKey 직접
  const directKey = readAny(
    { ...b, ...q, ...h },
    ["userKey","user_key","x-user-key","x-userkey"]
  );
  if (directKey) return { ok: true, user_key: directKey, from: "userKey" };

  // 0-1) Authorization: "UserKey <키값>" 허용
  const auth = h["authorization"];
  if (auth && /userkey\s+(.+)/i.test(String(auth))) {
    const m = String(auth).match(/userkey\s+(.+)/i);
    if (m && m[1]) return { ok: true, user_key: m[1].trim(), from: "authorization" };
  }

  // 공통 후보(스네이크/카멜 + 별칭 모두 지원)
  const localUserId =
    readAny(b, ["userId","user_id","userid","phone","phoneNumber","phone_number"]) ||
    readAny(h, ["x-user-id","x-userid","x-phone","x-phone-number"]) ||
    readAny(q, ["userId","user_id","userid","phone","phoneNumber","phone_number"]);

  const snsId =
    readAny(b, ["snsUserId","sns_user_id","oauth_id","kakao_user_id","google_user_id","naver_user_id"]) ||
    readAny(h, ["x-sns-user-id"]) ||
    readAny(q, ["snsUserId","sns_user_id","oauth_id","kakao_user_id","google_user_id","naver_user_id"]);

  let snsType =
    readAny(b, ["snsLoginType","sns_login_type","login_provider","provider","social_type","loginType"]) ||
    readAny(h, ["x-sns-login-type"]) ||
    readAny(q, ["snsLoginType","sns_login_type","login_provider","provider","social_type","loginType"]);
  if (snsType) snsType = String(snsType).toLowerCase();

  // 1) 로컬 유저
  if (localUserId) {
    return { ok: true, user_key: String(localUserId), from: "local" };
  }
  // 2) SNS 유저
  if (snsId && ["kakao","google","naver"].includes(snsType || "")) {
    return { ok: true, user_key: `${snsType}:${String(snsId)}`, from: "sns" };
  }

  return { ok: false, error: "missing user identity (userKey OR userId OR snsUserId+snsLoginType)" };
}


// ── 테이블 보장(최초 1회) ─────────────────────────────────────────────────────
async function ensureTable() {
  const sql = `
  CREATE TABLE IF NOT EXISTS tb_story_result (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_key VARCHAR(120) NOT NULL COMMENT '로컬: phone / SNS: <type>:<id>',
    story_key VARCHAR(200) NOT NULL,
    story_title VARCHAR(200) NULL,
    client_attempt_order INT NULL,
    score INT NOT NULL DEFAULT 0,
    total INT NOT NULL DEFAULT 0,
    client_utc DATETIME NOT NULL,
    client_kst VARCHAR(32) NULL,
    by_category JSON NOT NULL,
    by_type JSON NOT NULL,
    risk_bars JSON NOT NULL,
    risk_bars_by_type JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_user_story_time (user_key, story_key, client_utc)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `;
  const conn = await pool.getConnection();
  try {
    await conn.query(sql);
  } finally {
    conn.release();
  }
}
ensureTable().catch((e) => {
  console.error("[STR] ensureTable error:", e?.message || e);
});

// ── 헬스체크 ───────────────────────────────────────────────────────────────────
router.get("/health", (_req, res) => res.json({ ok: true, db: DB_HOST + "/" + DB_NAME }));

// 디버그용: 내가 인식한 아이덴티티 보기
router.get("/whoami", (req, res) => {
  const idn = resolveIdentity(req);
  res.json({ identity: idn, headers: req.headers, query: req.query });
});

// ── 저장: POST /str/attempt ──────────────────────────────────────────────────
router.post("/attempt", async (req, res) => {
  console.log("==== [/str/attempt] ====");
  console.log("headers.x-user-key/x-user-id/x-sns-user-id:",
    req.headers["x-user-key"], req.headers["x-user-id"], req.headers["x-sns-user-id"]);
  console.log("query.userKey/userId/snsUserId:", req.query?.userKey, req.query?.userId, req.query?.snsUserId);

  const idn = resolveIdentity(req);
  console.log("identity ->", idn);
  if (!idn.ok && !ALLOW_GUEST) {
    return res.status(400).json(idn); // { ok:false, error: ... }
  }

  try {
    const {
      storyTitle, storyKey, attemptOrder,
      attemptTime, clientKst,
      score, total,
      byCategory, byType,
      riskBars, riskBarsByType,
    } = req.body || {};

    if (!attemptTime) {
      return res.status(400).json({ ok:false, error:"missing attemptTime" });
    }
    const clientUtc = new Date(attemptTime);
    if (isNaN(clientUtc.getTime())) {
      return res.status(400).json({ ok:false, error:"invalid attemptTime" });
    }

    const key   = normalizeTitle(storyKey || storyTitle || "동화");
    const rbCat = riskBars       || computeRiskBars(byCategory);
    const rbTyp = riskBarsByType || computeRiskBars(byType);
    const mysqlClientUtc = isoToMysqlDatetime(clientUtc.toISOString());
    if (!mysqlClientUtc) {
      return res.status(400).json({ ok:false, error:"invalid attemptTime (to mysql)" });
    }

    const sql = `
      INSERT INTO tb_story_result
      (user_key,
       story_key, story_title, client_attempt_order, score, total,
       client_utc, client_kst,
       by_category, by_type, risk_bars, risk_bars_by_type)
      VALUES
      (:user_key,
       :story_key, :story_title, :client_attempt_order, :score, :total,
       :client_utc, :client_kst,
       CAST(:by_category AS JSON), CAST(:by_type AS JSON),
       CAST(:risk_bars AS JSON), CAST(:risk_bars_by_type AS JSON))
    `;

    const params = {
      user_key: idn.ok ? idn.user_key : "guest", // ALLOW_GUEST일 때만 guest로
      story_key: key,
      story_title: storyTitle || null,
      client_attempt_order: attemptOrder ?? null,
      score: Number(score ?? 0),
      total: Number(total ?? 0),
      client_utc: mysqlClientUtc,
      client_kst: clientKst || null,
      by_category: JSON.stringify(byCategory || {}),
      by_type: JSON.stringify(byType || {}),
      risk_bars: JSON.stringify(rbCat || {}),
      risk_bars_by_type: JSON.stringify(rbTyp || {}),
    };

    const conn = await pool.getConnection();
    try {
      const [ret] = await conn.execute(sql, params);
      const insertedId = ret.insertId;

      const [rows] = await conn.execute(
        `SELECT id, user_key,
                story_key, story_title, client_attempt_order, score, total,
                client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type, created_at
           FROM tb_story_result
          WHERE id = ?
          LIMIT 1`, [insertedId]
      );
      const row = rows[0];

      const saved = {
        storyTitle: row.story_title,
        score: row.score,
        total: row.total,
        byCategory: JSON.parse(row.by_category || "{}"),
        byType: JSON.parse(row.by_type || "{}"),
        attemptTime: new Date(row.client_utc).toISOString(),
        clientKst: row.client_kst,
        storyKey: row.story_key,
        clientAttemptOrder: row.client_attempt_order,
        riskBars: JSON.parse(row.risk_bars || "{}"),
        riskBarsByType: JSON.parse(row.risk_bars_by_type || "{}"),
      };

      return res.json({ ok:true, saved });
    } catch (e) {
      console.error("[STR] INSERT error:", e?.message || e);
      return res.status(500).json({ ok:false, error:"db_insert_error", detail: String(e?.message || e) });
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[STR] server error:", e);
    return res.status(500).json({ ok:false, error:"server_error", detail: String(e?.message || e) });
  }
});

// ── 최신 1건 조회: GET /str/latest ───────────────────────────────────────────
router.get("/latest", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok) return res.status(400).json(idn);

  try {
    const storyKey = normalizeTitle(req.query.storyKey || "");
    if (!storyKey) return res.status(400).json({ ok:false, error:"missing storyKey" });

    const sql = `
      SELECT id, user_key,
             story_key, story_title, client_attempt_order, score, total,
             client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type, created_at
        FROM tb_story_result
       WHERE user_key = :user_key
         AND story_key = :story_key
       ORDER BY client_utc DESC, id DESC
       LIMIT 1
    `;
    const p = { user_key: idn.user_key, story_key: storyKey };

    const conn = await pool.getConnection();
    try {
      const [rows] = await conn.execute(sql, p);
      if (!rows.length) return res.json({ ok:true, latest: null });
      const row = rows[0];
      const latest = {
        storyTitle: row.story_title,
        score: row.score,
        total: row.total,
        byCategory: JSON.parse(row.by_category || "{}"),
        byType: JSON.parse(row.by_type || "{}"),
        attemptTime: new Date(row.client_utc).toISOString(),
        clientKst: row.client_kst,
        storyKey: row.story_key,
        clientAttemptOrder: row.client_attempt_order,
        riskBars: JSON.parse(row.risk_bars || "{}"),
        riskBarsByType: JSON.parse(row.risk_bars_by_type || "{}"),
      };
      return res.json({ ok:true, latest });
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[STR] latest error:", e?.message || e);
    return res.status(500).json({ ok:false, error:"server_error", detail: String(e?.message || e) });
  }
});

module.exports = router;

// ==========================================
// File: Server/router/str.js
// 동화 결과 저장/조회 (MySQL) - JSON 응답 강제(safeJson)
// 서버 기본값을 캠퍼스 DB/개발 환경에 맞춤
// ==========================================
require("dotenv").config();
const express = require("express");
const router = express.Router();
const mysql = require("mysql2/promise");

// ── 설정 ─────────────────────────────────────────────────────────────────────
// 캠퍼스 DB를 기본값으로 둡니다(배포/개발에 맞게 .env 로 오버라이드 가능)
const {
  DB_HOST = "project-db-campus.smhrd.com",
  DB_PORT = "3307",
  DB_USER = "campus_25SW_BD_p3_3",
  DB_PASSWORD = "smhrd3",
  DB_NAME = "campus_25SW_BD_p3_3",
  // 개발 단계에서 게스트 허용 기본값 true (필요 시 .env에서 STR_ALLOW_GUEST=false)
  STR_ALLOW_GUEST = "true",
} = process.env;

const ALLOW_GUEST = String(STR_ALLOW_GUEST).toLowerCase() === "true";

// ── DB Pool (named placeholders 사용 안함) ────────────────────────────────────
const pool = mysql.createPool({
  host: DB_HOST,
  port: Number(DB_PORT),
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

// ── 공통 유틸 ─────────────────────────────────────────────────────────────────
function normalizeTitle(s) {
  return String(s || "").replace(/\s+/g, " ").trim();
}
function stripQuotes(s) {
  return String(s || "").trim().replace(/["'“”]/g, "");
}
function computeRiskBars(by) {
  if (!by || typeof by !== "object") return {};
  const out = {};
  for (const k of Object.keys(by)) {
    const v = by[k] || {};
    const c = Number(v.correct || 0);
    const t = Number(v.total || 0);
    out[k] = t > 0 ? 1 - c / t : 0.5;
  }
  return out;
}
function isoToMysqlDatetime(iso) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}

// ✅ 항상 JSON으로 내려보내기 (어떤 상황에서도 문자열 "[object Object]" 방지)
function safeJson(res, obj, status = 200) {
  try {
    const body = JSON.stringify(obj);
    res.status(status).set("Content-Type", "application/json; charset=utf-8").send(body);
  } catch (e) {
    res
      .status(500)
      .set("Content-Type", "application/json; charset=utf-8")
      .send(JSON.stringify({ ok: false, error: "json_stringify_error", detail: String(e?.message || e) }));
  }
}

// ── 유저 식별 ────────────────────────────────────────────────────────────────
function resolveIdentity(req) {
  const b = req.body || {};
  const q = req.query || {};
  const h = Object.fromEntries(Object.entries(req.headers || {}).map(([k, v]) => [String(k).toLowerCase(), v]));

  const readAny = (obj, keys) => {
    for (const k of keys) {
      if (obj[k] == null) continue;
      const s = String(obj[k]).trim();
      if (s) return s;
    }
    return null;
  };

  // 직접 키(userKey/x-user-key/쿼리/바디/헤더)
  const directKey = readAny({ ...b, ...q, ...h }, ["userKey", "user_key", "x-user-key", "x-userkey"]);
  if (directKey) return { ok: true, user_key: directKey, from: "userKey" };

  // Authorization: UserKey <value>
  const auth = h["authorization"];
  if (auth && /userkey\s+(.+)/i.test(String(auth))) {
    const m = String(auth).match(/userkey\s+(.+)/i);
    if (m && m[1]) return { ok: true, user_key: m[1].trim(), from: "authorization" };
  }

  // 로컬 ID(phone 등)
  const localUserId =
    readAny(b, ["userId", "user_id", "userid", "phone", "phoneNumber", "phone_number"]) ||
    readAny(h, ["x-user-id", "x-userid", "x-phone", "x-phone-number"]) ||
    readAny(q, ["userId", "user_id", "userid", "phone", "phoneNumber", "phone_number"]);
  if (localUserId) return { ok: true, user_key: String(localUserId), from: "local" };

  // SNS ID + 타입
  const snsId =
    readAny(b, ["snsUserId", "sns_user_id", "oauth_id", "kakao_user_id", "google_user_id", "naver_user_id"]) ||
    readAny(h, ["x-sns-user-id"]) ||
    readAny(q, ["snsUserId", "sns_user_id", "oauth_id", "kakao_user_id", "google_user_id", "naver_user_id"]);
  let snsType =
    readAny(b, ["snsLoginType", "sns_login_type", "login_provider", "provider", "social_type", "loginType"]) ||
    readAny(h, ["x-sns-login-type"]) ||
    readAny(q, ["snsLoginType", "sns_login_type", "login_provider", "provider", "social_type", "loginType"]);
  if (snsType) snsType = String(snsType).toLowerCase();

  if (snsId && ["kakao", "google", "naver"].includes(snsType || "")) {
    return { ok: true, user_key: `${snsType}:${String(snsId)}`, from: "sns" };
  }
  return { ok: false, error: "missing user identity (userKey OR userId OR snsUserId+snsLoginType)" };
}

// ── 테이블 보장 ───────────────────────────────────────────────────────────────
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
ensureTable().catch((e) => console.error("[STR] ensureTable error:", e?.message || e));

// ── 라우트 ───────────────────────────────────────────────────────────────────
router.get("/health", (_req, res) => safeJson(res, { ok: true, db: DB_HOST + "/" + DB_NAME }));
router.get("/whoami", (req, res) => {
  const idn = resolveIdentity(req);
  safeJson(res, { identity: idn, headers: req.headers, query: req.query });
});

// 저장: POST /str/attempt
router.post("/attempt", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok && !ALLOW_GUEST) return safeJson(res, idn, 400);

  try {
    const {
      storyTitle, storyKey,
      attemptTime, clientKst,
      score, total,
      byCategory, byType,
      riskBars, riskBarsByType,
    } = req.body || {};

    if (!storyTitle && !storyKey) return safeJson(res, { ok:false, error:"missing storyTitle/storyKey" }, 400);
    if (!attemptTime) return safeJson(res, { ok:false, error:"missing attemptTime" }, 400);

    const dt = new Date(attemptTime);
    if (isNaN(dt.getTime())) return safeJson(res, { ok:false, error:"invalid attemptTime" }, 400);

    const key = normalizeTitle(storyKey || storyTitle);
    const rbCat = riskBars || computeRiskBars(byCategory);
    const rbTyp = riskBarsByType || computeRiskBars(byType);
    const mysqlClientUtc = isoToMysqlDatetime(dt.toISOString());
    if (!mysqlClientUtc) return safeJson(res, { ok:false, error:"invalid attemptTime (to mysql)" }, 400);

    const conn = await pool.getConnection();
    try {
      // 직전 회차 계산: 이 유저-책으로 저장된 마지막 회차 + 1
      const [prevRows] = await conn.execute(
        `SELECT client_attempt_order AS ord
           FROM tb_story_result
          WHERE user_key = ? AND story_key = ?
          ORDER BY client_utc DESC, id DESC
          LIMIT 1`, [idn.ok ? idn.user_key : "guest", key]
      );
      const prevOrd = (prevRows[0] && Number(prevRows[0].ord)) || 0;
      const nextOrd = prevOrd + 1;

      // 저장
      const [ret] = await conn.execute(
        `INSERT INTO tb_story_result
           (user_key, story_key, story_title, client_attempt_order, score, total,
            client_utc, client_kst, by_category, by_type, risk_bars, risk_bars_by_type)
         VALUES (?,?,?,?,?,?, ?,?, CAST(? AS JSON), CAST(? AS JSON), CAST(? AS JSON), CAST(? AS JSON))`,
        [
          idn.ok ? idn.user_key : "guest",
          key,
          storyTitle || null,
          nextOrd,
          Number(score ?? 0),
          Number(total ?? 0),
          mysqlClientUtc,
          clientKst || null,
          JSON.stringify(byCategory || {}),
          JSON.stringify(byType || {}),
          JSON.stringify(rbCat || {}),
          JSON.stringify(rbTyp || {}),
        ]
      );
      const insertedId = ret.insertId;

      const [rows] = await conn.execute(
        `SELECT story_title, score, total, story_key,
                client_attempt_order, client_kst, client_utc,
                by_category, by_type, risk_bars, risk_bars_by_type
           FROM tb_story_result
          WHERE id = ? LIMIT 1`, [insertedId]
      );
      const r = rows[0];
      const saved = {
        storyTitle: r.story_title,
        score: r.score,
        total: r.total,
        byCategory: JSON.parse(r.by_category || "{}"),
        byType: JSON.parse(r.by_type || "{}"),
        attemptTime: new Date(r.client_utc).toISOString(),
        clientKst: r.client_kst,
        storyKey: r.story_key,
        clientAttemptOrder: r.client_attempt_order,
        riskBars: JSON.parse(r.risk_bars || "{}"),
        riskBarsByType: JSON.parse(r.risk_bars_by_type || "{}"),
      };
      return safeJson(res, { ok: true, saved });
    } catch (e) {
      console.error("[STR] INSERT error:", e?.message || e);
      return safeJson(res, { ok:false, error:"db_insert_error", detail:String(e?.message || e) }, 500);
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[STR] server error:", e);
    return safeJson(res, { ok:false, error:"server_error", detail:String(e?.message || e) }, 500);
  }
});

// 조회: GET /str/latest
router.get("/latest", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok) return safeJson(res, idn, 400);

  try {
    const storyKeyRaw = normalizeTitle(req.query.storyKey || "");
    const storyTitleRaw = normalizeTitle(req.query.storyTitle || "");
    if (!storyKeyRaw && !storyTitleRaw) {
      return safeJson(res, { ok:false, error:"missing storyKey or storyTitle" }, 400);
    }

    const norm_key_param   = stripQuotes(storyKeyRaw);
    const norm_title_param = stripQuotes(storyTitleRaw);

    const normalizeSql = (col) => `
      REPLACE(REPLACE(REPLACE(REPLACE(TRIM(${col}), '"', ''), '''', ''), '“',''), '”','')
    `;

    const conds = [];
    const params = [idn.user_key];
    if (storyKeyRaw)   { conds.push(`${normalizeSql("story_key")} = ?`);   params.push(norm_key_param); }
    if (storyTitleRaw) { conds.push(`${normalizeSql("story_title")} = ?`); params.push(norm_title_param); }

    const condSql = conds.length ? conds.join(" OR ") : "0";

    const conn = await pool.getConnection();
    try {
      const [rows] = await conn.execute(
        `
        SELECT story_title, score, total, story_key,
               client_attempt_order, client_kst, client_utc,
               by_category, by_type, risk_bars, risk_bars_by_type
          FROM tb_story_result
         WHERE user_key = ?
           AND (${condSql})
         ORDER BY client_utc DESC, id DESC
         LIMIT 1
        `, params
      );
      if (!rows.length) return safeJson(res, { ok:true, latest:null });

      const r = rows[0];
      const latest = {
        storyTitle: r.story_title,
        score: r.score,
        total: r.total,
        byCategory: JSON.parse(r.by_category || "{}"),
        byType: JSON.parse(r.by_type || "{}"),
        attemptTime: new Date(r.client_utc).toISOString(),
        clientKst: r.client_kst,
        storyKey: r.story_key,
        clientAttemptOrder: r.client_attempt_order,
        riskBars: JSON.parse(r.risk_bars || "{}"),
        riskBarsByType: JSON.parse(r.risk_bars_by_type || "{}"),
      };
      return safeJson(res, { ok:true, latest });
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[STR] latest error:", e?.message || e);
    return safeJson(res, { ok:false, error:"server_error", detail:String(e?.message || e) }, 500);
  }
});

module.exports = router;

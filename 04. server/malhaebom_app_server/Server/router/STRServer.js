// File: src/Server/router/STRServer.js
require("dotenv").config();

const express = require("express");
const router = express.Router();
// ✅ 공용 DB 풀만 사용 (개별 풀 생성 금지)
const pool = require("./db");
const jwt = require("jsonwebtoken");

// ── 설정 ─────────────────────────────────────────────────────────────────────
const {
  STR_ALLOW_GUEST = "false",                // true면 user_key 없이도 저장(디버깅용)
  JWT_SECRET = "malhaebom_sns",             // ★ Auther/Login과 통일
  JWT_ISS,                                  // 선택: 토큰 발급자
  JWT_AUD,                                  // 선택: 토큰 대상자
} = process.env;

const ALLOW_GUEST = String(STR_ALLOW_GUEST).toLowerCase() === "true";

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
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth()+1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}

// 표준 user_key: `${login_type}:${login_id}`
function buildUserKeyFromLogin({ login_id, login_type }) {
  if (!login_id || !login_type) return null;
  return `${String(login_type).toLowerCase()}:${String(login_id)}`;
}

// ── JWT 옵션 ─────────────────────────────────────────────────────────────────
function jwtVerifyWithOpts(token) {
  const opts = {};
  if (JWT_ISS) opts.issuer = JWT_ISS;
  if (JWT_AUD) opts.audience = JWT_AUD;
  return jwt.verify(token, JWT_SECRET, opts);
}

/**
 * Authorization Bearer 토큰 → user_key 복원
 *  - JWT 페이로드: { uid, login_id, login_type, nick }
 */
function resolveFromBearer(req) {
  try {
    const h = req.headers.authorization || "";
    if (!h.startsWith("Bearer ")) return null;
    const token = h.slice(7);
    const p = jwtVerifyWithOpts(token);
    // 우선순위: login_id + login_type → user_key
    const key = buildUserKeyFromLogin({ login_id: p.login_id, login_type: p.login_type });
    if (key) return { ok: true, user_key: key, from: "bearer" };
    if (p.uid) return { ok: true, user_key: `uid:${p.uid}`, from: "bearer-uid" };
    return null;
  } catch {
    return null;
  }
}

// (과거 호환) 다양한 헤더/쿼리/바디에서 신원 추출
function resolveIdentity(req) {
  // 0) 먼저 Bearer JWT
  const fromBearer = resolveFromBearer(req);
  if (fromBearer) return fromBearer;

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

  // 직접 주는 userKey
  const directKey = readAny({ ...b, ...q, ...h }, ["userkey","user_key","x-user-key","x-userkey"]);
  if (directKey) return { ok: true, user_key: directKey, from: "userKey" };

  // (구) 로컬 방식: user_id/phone
  const localLoginId =
    readAny(b, ["login_id","userId","user_id","userid","phone","phoneNumber","phone_number"]) ||
    readAny(h, ["x-login-id","x-user-id","x-userid","x-phone","x-phone-number"]) ||
    readAny(q, ["login_id","userId","user_id","userid","phone","phoneNumber","phone_number"]);

  // SNS: id + type
  const snsLoginId =
    readAny(b, ["login_id","snsUserId","sns_user_id","oauth_id","kakao_user_id","google_user_id","naver_user_id"]) ||
    readAny(h, ["x-login-id","x-sns-user-id"]) ||
    readAny(q, ["login_id","snsUserId","sns_user_id","oauth_id","kakao_user_id","google_user_id","naver_user_id"]);

  let loginType =
    readAny(b, ["login_type","snsLoginType","sns_login_type","login_provider","provider","social_type","loginType"]) ||
    readAny(h, ["x-login-type","x-sns-login-type"]) ||
    readAny(q, ["login_type","snsLoginType","sns_login_type","login_provider","provider","social_type","loginType"]);
  if (loginType) loginType = String(loginType).toLowerCase();

  // 1) login_id + login_type → 표준 user_key
  if (localLoginId && loginType === "local") {
    return { ok: true, user_key: buildUserKeyFromLogin({ login_id: localLoginId, login_type: "local" }), from: "local" };
  }
  if (snsLoginId && ["kakao","google","naver"].includes(loginType || "")) {
    return { ok: true, user_key: buildUserKeyFromLogin({ login_id: snsLoginId, login_type: loginType }), from: "sns" };
  }

  return { ok: false, error: "missing user identity (Authorization Bearer OR userKey OR login_id+login_type)" };
}

// --- JSON 안전 파서 & risk_bars → byCategory 복원 --- //
function safeParseJSON(v, fallback = {}) {
  try {
    if (v && typeof v === "object") return v;
    return JSON.parse(v ?? "{}") || fallback;
  } catch {
    return fallback;
  }
}

// risk = 1 - correct/total  →  correct = (1 - risk) * BASE
function barsToCategoryStats(bars, baseTotal = 100) {
  const out = {};
  for (const k of Object.keys(bars || {})) {
    const risk = Math.max(0, Math.min(1, Number(bars[k] ?? 0)));
    const total = baseTotal;
    const correct = Math.round((1 - risk) * total);
    out[k] = { correct, total };
  }
  return out;
}

// ── 테이블 보장(최초 1회) ─────────────────────────────────────────────────────
async function ensureTable() {
  const sql = `
  CREATE TABLE IF NOT EXISTS tb_story_result (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_key VARCHAR(120) NOT NULL COMMENT 'login_type:login_id',
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
  try { await conn.query(sql); } finally { conn.release(); }
}
ensureTable().catch((e) => console.error("[STR] ensureTable error:", e?.message || e));

// ── 헬스체크 ───────────────────────────────────────────────────────────────────
router.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ ok: false, error: "db_unreachable", detail: String(e?.message || e) });
  }
});

// 디버그용: 내가 인식한 아이덴티티 보기
router.get("/whoami", (req, res) => {
  const idn = resolveIdentity(req);
  res.json({ identity: idn, headers: req.headers, query: req.query });
});

// ── 저장: POST /str/attempt ──────────────────────────────────────────────────
router.post("/attempt", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok && !ALLOW_GUEST) {
    return res.status(400).json(idn);
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
      user_key: idn.ok ? idn.user_key : "guest",
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
        byCategory: safeParseJSON(row.by_category, {}),
        byType: safeParseJSON(row.by_type, {}),
        attemptTime: new Date(row.client_utc).toISOString(),
        clientKst: row.client_kst,
        storyKey: row.story_key,
        clientAttemptOrder: row.client_attempt_order,
        riskBars: safeParseJSON(row.risk_bars, {}),
        riskBarsByType: safeParseJSON(row.risk_bars_by_type, {}),
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

      const riskBars = safeParseJSON(row.risk_bars, {});
      const parsedByCategory = safeParseJSON(row.by_category, {});
      const byCategory =
        (parsedByCategory && Object.keys(parsedByCategory).length)
          ? parsedByCategory
          : barsToCategoryStats(riskBars);

      const latest = {
        storyTitle: row.story_title,
        score: Number(row.score ?? 0),
        total: Number(row.total ?? 0),
        byCategory,
        byType: safeParseJSON(row.by_type, {}),
        attemptTime: new Date(row.client_utc).toISOString(),
        clientKst: row.client_kst,
        storyKey: row.story_key,
        clientAttemptOrder: row.client_attempt_order,
        riskBars,
        riskBarsByType: safeParseJSON(row.risk_bars_by_type, {}),

        scoreText: `${row.score}/${row.total}`,
        serverAttemptOrder: 1,
        debugText:
`=============== [STR Attempt] ===============
동화 키      : ${row.story_key}
표시 제목    : ${row.story_title ?? row.story_key}
클라 회차    : ${row.client_attempt_order ?? ""}
서버 회차    : 1
점수/총점    : ${row.score}/${row.total}
Client KST   : ${row.client_kst ?? ""}
riskBars(cat): ${JSON.stringify(riskBars)}
=============================================`,
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

// ── 목록 조회: GET /str/story/attempt/list ───────────────────────────────────
router.get("/story/attempt/list", async (req, res) => {
  try {
    const idn = resolveIdentity(req);
    if (!idn.ok && !ALLOW_GUEST) {
      return res.status(400).json(idn);
    }

    const storyKey = normalizeTitle(req.query.storyKey || req.query.title || "");
    if (!storyKey) {
      return res.status(400).json({ ok: false, error: "missing storyKey/title" });
    }

    const userKey = idn.ok ? idn.user_key : "guest";
    const limit = Math.min(Math.max(parseInt(String(req.query.limit || "30"), 10) || 30, 1), 200);

    const sql = `
      SELECT user_key,
             story_key, story_title, client_attempt_order, score, total,
             client_kst, risk_bars, risk_bars_by_type
        FROM tb_story_result
       WHERE user_key = :user_key
         AND story_key = :story_key
       ORDER BY client_utc DESC, id DESC
       LIMIT ${limit}
    `;
    const params = { user_key: userKey, story_key: storyKey };

    const conn = await pool.getConnection();
    try {
      const [rows] = await conn.execute(sql, params);

      const list = rows.map((row, idx) => {
        const riskBars = safeParseJSON(row.risk_bars, {});
        const riskBarsByType = safeParseJSON(row.risk_bars_by_type, {});
        const byCategory = barsToCategoryStats(riskBars);

        const score = Number(row.score ?? 0);
        const total = Number(row.total ?? 0);
        const scoreText = `${score}/${total}`;

        return {
          storyTitle: row.story_title,
          score,
          total,
          byCategory,
          byType: {},
          clientKst: row.client_kst,
          storyKey: row.story_key,
          clientAttemptOrder: row.client_attempt_order,
          riskBars,
          riskBarsByType,

          scoreText,
          serverAttemptOrder: idx + 1,
          debugText:
`=============== [STR Attempt] ===============
동화 키      : ${row.story_key}
표시 제목    : ${row.story_title ?? row.story_key}
클라 회차    : ${row.client_attempt_order ?? ""}
서버 회차    : ${idx + 1}
점수/총점    : ${scoreText}
Client KST   : ${row.client_kst ?? ""}
riskBars(cat): ${JSON.stringify(riskBars)}
=============================================`,
        };
      });

      return res.json({ ok: true, list });
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[STR] list error:", e?.message || e);
    return res.status(500).json({ ok: false, error: "server_error", detail: String(e?.message || e) });
  }
});

module.exports = router;

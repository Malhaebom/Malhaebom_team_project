// routes/IRServer.js
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
  IR_ALLOW_GUEST = "false", // true면 user_key 없이도 저장(디버깅용)
} = process.env;


const ALLOW_GUEST = String(IR_ALLOW_GUEST).toLowerCase() === "true";

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
    const total = Number(v.total || 0);
    out[k] = total > 0 ? 1 - correct / total : 0.5;
  }
  return out;
}
function isoToMysqlDatetime(iso) {
  // 'YYYY-MM-DD HH:MM:SS' (UTC 저장)
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}
function safeParseJSON(v, fallback = {}) {
  try {
    if (v && typeof v === "object") return v;
    return JSON.parse(v ?? "{}") || fallback;
  } catch {
    return fallback;
  }
}
// risk = 1 - correct/total → correct = (1 - risk) * BASE
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

// KST 포맷 (YYYY년 MM월 DD일 HH:MM)
function formatKst(dt) {
  if (!(dt instanceof Date) || isNaN(dt.getTime())) return "";
  const kst = new Date(dt.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kst.getUTCDate()).padStart(2, "0");
  const hh = String(kst.getUTCHours()).padStart(2, "0");
  const mm = String(kst.getUTCMinutes()).padStart(2, "0");
  return `${y}년 ${m}월 ${d}일 ${hh}:${mm}`;
}

// riskBars 예쁘게(샘플처럼 단일따옴표/줄바꿈)
function prettyRiskBars(obj) {
  const entries = Object.entries(obj || {});
  if (!entries.length) return "{}";
  const lines = entries.map(([k, v]) => `  '${k}': ${Number(v)}`);
  return `{\n${lines.join(",\n")}\n}`;
}

/**
 * 클라에서 보낼 수 있는 위치:
 *  - body.userKey  또는 body.userId / body.snsUserId+snsLoginType
 *  - headers['x-user-key'] 또는 x-user-id / x-sns-user-id + x-sns-login-type
 *  - query 동일 키
 */
function resolveIdentity(req) {
  const b = req.body || {};
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
  const directKey = readAny({ ...b, ...q, ...h },
    ["userKey", "user_key", "x-user-key", "x-userkey"]
  );
  if (directKey) return { ok: true, user_key: directKey, from: "userKey" };

  // 0-0) login_id 계열을 user_key로 간주 (값은 login_id)
  const loginId =
    readAny({ ...b, ...q, ...h }, ["login_id", "loginId", "x-login-id"]);
  if (loginId) return { ok: true, user_key: String(loginId), from: "login_id" };


  // 0-1) Authorization: "UserKey <키값>" 허용
  const auth = h["authorization"];
  if (auth && /userkey\s+(.+)/i.test(String(auth))) {
    const m = String(auth).match(/userkey\s+(.+)/i);
    if (m && m[1]) return { ok: true, user_key: m[1].trim(), from: "authorization" };
  }

  // 공통 후보
  const localUserId =
    readAny(b, ["userId", "user_id", "userid", "phone", "phoneNumber", "phone_number"]) ||
    readAny(h, ["x-user-id", "x-userid", "x-phone", "x-phone-number"]) ||
    readAny(q, ["userId", "user_id", "userid", "phone", "phoneNumber", "phone_number"]);

  const snsId =
    readAny(b, ["snsUserId", "sns_user_id", "oauth_id", "kakao_user_id", "google_user_id", "naver_user_id"]) ||
    readAny(h, ["x-sns-user-id"]) ||
    readAny(q, ["snsUserId", "sns_user_id", "oauth_id", "kakao_user_id", "google_user_id", "naver_user_id"]);

  let snsType =
    readAny(b, ["snsLoginType", "sns_login_type", "login_provider", "provider", "social_type", "loginType"]) ||
    readAny(h, ["x-sns-login-type"]) ||
    readAny(q, ["snsLoginType", "sns_login_type", "login_provider", "provider", "social_type", "loginType"]);
  if (snsType) snsType = String(snsType).toLowerCase();

  if (localUserId) {
    return { ok: true, user_key: String(localUserId), from: "local" };
  }
  if (snsId && ["kakao", "google", "naver"].includes(snsType || "")) {
    return { ok: true, user_key: `${snsType}:${String(snsId)}`, from: "sns" };
  }

  return { ok: false, error: "missing user identity (userKey OR userId OR snsUserId+snsLoginType)" };
}

// ── 헬스/디버그 ────────────────────────────────────────────────────────────────
router.get("/health", (_req, res) => res.json({ ok: true, db: DB_HOST + "/" + DB_NAME }));
router.get("/whoami", (req, res) => {
  const idn = resolveIdentity(req);
  res.json({ identity: idn, headers: req.headers, query: req.query });
});

// 특정 저장행의 "서버 회차(최신=1)" 계산
async function computeServerOrder(conn, { user_key, client_utc, id }) {
  const sql = `
    SELECT COUNT(*) AS higher
      FROM tb_interview_result
     WHERE user_key = :user_key
       AND (client_utc > :client_utc OR (client_utc = :client_utc AND id > :id))
  `;
  const params = { user_key, client_utc, id };
  const [rows] = await conn.execute(sql, params);
  const higher = Number(rows?.[0]?.higher ?? 0);
  return higher + 1;
}

// ── 저장: POST /ir/attempt ───────────────────────────────────────────────────
router.post("/attempt", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok && !ALLOW_GUEST) {
    return res.status(400).json(idn);
  }

  try {
    const {
      attemptTime, clientKst,
      interviewTitle, title,
      score, total,
      byCategory,
      riskBars,
    } = req.body || {};

    if (!attemptTime) return res.status(400).json({ ok: false, error: "missing attemptTime" });

    const clientUtc = new Date(attemptTime);
    if (isNaN(clientUtc.getTime())) return res.status(400).json({ ok: false, error: "invalid attemptTime" });

    const normalizedTitle = normalizeTitle(interviewTitle || title || "");
    const rb = riskBars || computeRiskBars(byCategory || {});
    const mysqlClientUtc = isoToMysqlDatetime(clientUtc.toISOString());
    if (!mysqlClientUtc) return res.status(400).json({ ok: false, error: "invalid attemptTime (to mysql)" });

    const user_key = idn.ok ? idn.user_key : "guest";

    const conn = await pool.getConnection();
    try {
      // ➊ 동일 시도 존재하면 그대로 반환 (idempotent)
      const [dupRows] = await conn.execute(
        `SELECT id, user_key, client_round, title, score, total,
                client_utc, client_kst, risk_bars, created_at
           FROM tb_interview_result
          WHERE user_key = :user_key
            AND title    = :title
            AND client_utc = :client_utc
          LIMIT 1`,
        { user_key, title: normalizedTitle, client_utc: mysqlClientUtc }
      );

      if (dupRows.length) {
        const row = dupRows[0];
        const risk = safeParseJSON(row.risk_bars, {});
        const byCatRestored = barsToCategoryStats(risk);
        const serverOrder = await computeServerOrder(conn, {
          user_key: row.user_key,
          client_utc: row.client_utc,
          id: row.id,
        });
        const saved = {
          title: row.title,
          interviewTitle: row.title,
          clientRound: row.client_round,
          clientAttemptOrder: row.client_round,
          score: Number(row.score ?? 0),
          total: Number(row.total ?? 0),
          attemptTime: new Date(row.client_utc).toISOString(),
          clientKst: row.client_kst || formatKst(new Date(row.client_utc)),
          riskBars: risk,
          byCategory: byCatRestored,
          serverAttemptOrder: serverOrder,
          createdAt: row.created_at,
          deduped: true, // ★ 중복 차단됨 표시
        };
        return res.json({ ok: true, saved });
      }

      // ➋ 회차는 서버가 결정 (클라 값 무시)
      const [nextRows] = await conn.execute(
        `SELECT COALESCE(MAX(client_round), 0) + 1 AS next
           FROM tb_interview_result
          WHERE user_key = :user_key AND title = :title`,
        { user_key, title: normalizedTitle }
      );
      const nextRound = Number(nextRows?.[0]?.next ?? 1);

      // ➌ INSERT
      const [ret] = await conn.execute(
        `INSERT INTO tb_interview_result
           (user_key, client_round, title, score, total, client_utc, client_kst, risk_bars)
         VALUES
           (:user_key, :client_round, :title, :score, :total, :client_utc, :client_kst, :risk_bars)`,
        {
          user_key,
          client_round: nextRound,
          title: normalizedTitle,
          score: Number(score ?? 0),
          total: Number(total ?? 0),
          client_utc: mysqlClientUtc,
          client_kst: clientKst || formatKst(clientUtc),
          risk_bars: JSON.stringify(rb || {}),
        }
      );

      const insertedId = ret.insertId;

      const [rows] = await conn.execute(
        `SELECT id, user_key, client_round, title, score, total,
                client_utc, client_kst, risk_bars, created_at
           FROM tb_interview_result
          WHERE id = ?
          LIMIT 1`,
        [insertedId]
      );
      const row = rows[0];

      const serverOrder = await computeServerOrder(conn, {
        user_key: row.user_key,
        client_utc: row.client_utc,
        id: row.id,
      });
      const risk = safeParseJSON(row.risk_bars, {});
      const byCatRestored = barsToCategoryStats(risk);

      const saved = {
        title: row.title,
        interviewTitle: row.title,
        clientRound: row.client_round,
        clientAttemptOrder: row.client_round,
        score: Number(row.score ?? 0),
        total: Number(row.total ?? 0),
        attemptTime: new Date(row.client_utc).toISOString(),
        clientKst: row.client_kst || formatKst(new Date(row.client_utc)),
        riskBars: risk,
        byCategory: byCatRestored,
        serverAttemptOrder: serverOrder,
        createdAt: row.created_at,
      };

      return res.json({ ok: true, saved });
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[IR] /attempt error:", e?.message || e);
    return res.status(500).json({ ok: false, error: "server_error", detail: String(e?.message || e) });
  }
});

// ── 최신 1건: GET /ir/latest  (옵션: ?title=...) ─────────────────────────────
router.get("/latest", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok) return res.status(400).json(idn);

  const qTitle = normalizeTitle(req.query.title || "");
  const whereTitle = qTitle ? "AND title = :title" : "";

  const sql = `
    SELECT id, user_key, client_round, title, score, total,
           client_utc, client_kst, risk_bars, created_at
      FROM tb_interview_result
     WHERE user_key = :user_key
       ${whereTitle}
     ORDER BY client_utc DESC, id DESC
     LIMIT 1
  `;
  const params = { user_key: idn.user_key };
  if (whereTitle) params.title = qTitle;

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(sql, params);
    if (!rows.length) return res.json({ ok: true, latest: null });

    const row = rows[0];
    const risk = safeParseJSON(row.risk_bars, {});
    const byCategory = barsToCategoryStats(risk);
    const clientKst = row.client_kst || formatKst(new Date(row.client_utc));

    const debugText = [
      "=============== [IR Attempt] ===============",
      `서버 회차    : 1회차`,
      `클라 회차    : ${row.client_round ?? ""}`,
      `제목         : ${row.title || "(없음)"}`,
      `점수/총점    : ${Number(row.score ?? 0)}/${Number(row.total ?? 0)}`,
      `Client KST   : ${clientKst}`,
      `riskBars     : ${prettyRiskBars(risk)}`,
      "============================================",
    ].join("\n");

    const latest = {
      title: row.title,
      interviewTitle: row.title,
      clientRound: row.client_round,
      clientAttemptOrder: row.client_round,
      score: Number(row.score ?? 0),
      total: Number(row.total ?? 0),
      attemptTime: new Date(row.client_utc).toISOString(),
      clientKst,
      riskBars: risk,
      byCategory,
      serverAttemptOrder: 1, // 최신 1건이므로 1회차
      debugText,
      createdAt: row.created_at,
    };
    return res.json({ ok: true, latest });
  } catch (e) {
    console.error("[IR] /latest error:", e?.message || e);
    return res.status(500).json({ ok: false, error: "server_error", detail: String(e?.message || e) });
  } finally {
    conn.release();
  }
});

// ── 전체 목록: GET /ir/attempt/list (?limit=30) ──────────────────────────────
router.get("/attempt/list", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok && !ALLOW_GUEST) {
    return res.status(400).json(idn);
  }

  const userKey = idn.ok ? idn.user_key : "guest";
  const limit = Math.min(Math.max(parseInt(String(req.query.limit || "30"), 10) || 30, 1), 200);

  const sql = `
    SELECT id, title, client_round, score, total,
           client_utc, client_kst, risk_bars, created_at
      FROM tb_interview_result
     WHERE user_key = :user_key
     ORDER BY client_utc DESC, id DESC
     LIMIT ${limit}
  `;
  const params = { user_key: userKey };

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(sql, params);

    const list = rows.map((row, idx) => {
      const risk = safeParseJSON(row.risk_bars, {});
      const byCategory = barsToCategoryStats(risk);
      const score = Number(row.score ?? 0);
      const total = Number(row.total ?? 0);
      const clientKst = row.client_kst || (row.client_utc ? formatKst(new Date(row.client_utc)) : "");
      const attemptIso = row.client_utc ? new Date(row.client_utc).toISOString() : null;
      const serverOrder = idx + 1; // 최신이 1

      const debugText = [
        "=============== [IR Attempt] ===============",
        `서버 회차    : ${serverOrder}회차`,
        `클라 회차    : ${row.client_round ?? ""}`,
        `제목         : ${row.title || "(없음)"}`,
        `점수/총점    : ${score}/${total}`,
        `Client KST   : ${clientKst}`,
        `riskBars     : ${prettyRiskBars(risk)}`,
        "============================================",
      ].join("\n");

      return {
        title: row.title,
        interviewTitle: row.title,
        clientRound: row.client_round,
        clientAttemptOrder: row.client_round,
        score,
        total,
        attemptTime: attemptIso,
        clientKst,
        riskBars: risk,
        byCategory,                  // UI가 correct/total을 쓰므로 복원본 제공
        scoreText: `${score}/${total}`,
        serverAttemptOrder: serverOrder,
        debugText,
        createdAt: row.created_at,
      };
    });

    return res.json({ ok: true, list });
  } catch (e) {
    console.error("[IR] /attempt/list error:", e?.message || e);
    return res.status(500).json({ ok: false, error: "server_error", detail: String(e?.message || e) });
  } finally {
    conn.release();
  }
});

/** 최근 시도 n개 조회 (메모리, 디버그용) */
router.get("/attempts", (req, res) => {
  const n = Math.min(Math.max(parseInt(String(req.query.limit || "30"), 10) || 30, 1), 200);
  res.json({ ok: true, list: attempts.slice(0, n) });
});

/** (주의) 메모리 기록 초기화 (디버그용) */
router.post("/reset", (_req, res) => {
  attempts.length = 0;
  attemptIndex = 0;
  res.json({ ok: true, message: "reset done" });
});

module.exports = router;

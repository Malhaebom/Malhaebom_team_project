require("dotenv").config();

const express = require("express");
const router = express.Router();
const mysql = require("mysql2/promise");

const {
  DB_HOST = "127.0.0.1",
  DB_PORT = "3306",
  DB_USER = "root",
  DB_PASSWORD = "",
  DB_NAME = "appdb",
  IR_ALLOW_GUEST = "false",
} = process.env;

const ALLOW_GUEST = String(IR_ALLOW_GUEST).toLowerCase() === "true";

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

// ── 유틸 ─────────────────
function normalizeTitle(s) { return String(s || "").replace(/\s+/g, " ").trim(); }
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
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth()+1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}
function safeParseJSON(v, fallback = {}) {
  try { if (v && typeof v === "object") return v; return JSON.parse(v ?? "{}") || fallback; }
  catch { return fallback; }
}
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
function prettyRiskBars(obj) {
  const entries = Object.entries(obj || {});
  if (!entries.length) return "{}";
  const lines = entries.map(([k, v]) => `  '${k}': ${Number(v)}`);
  return `{\n${lines.join(",\n")}\n}`;
}
function resolveIdentity(req) {
  const b = req.body || {}, q = req.query || {};
  const h = Object.fromEntries(Object.entries(req.headers || {}).map(([k, v]) => [String(k).toLowerCase(), v]));
  const readAny = (obj, keys) => { for (const k of keys) { if (obj[k] == null) continue; const s = String(obj[k]).trim(); if (s) return s; } return null; };

  const directKey = readAny({ ...b, ...q, ...h }, ["userKey", "user_key", "x-user-key", "x-userkey"]);
  if (directKey) return { ok: true, user_key: directKey, from: "userKey" };

  const loginId = readAny({ ...b, ...q, ...h }, ["login_id", "loginId", "x-login-id"]);
  if (loginId) return { ok: true, user_key: String(loginId), from: "login_id" };

  const auth = h["authorization"];
  if (auth && /userkey\s+(.+)/i.test(String(auth))) {
    const m = String(auth).match(/userkey\s+(.+)/i);
    if (m && m[1]) return { ok: true, user_key: m[1].trim(), from: "authorization" };
  }

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

  if (localUserId) return { ok: true, user_key: String(localUserId), from: "local" };
  if (snsId && ["kakao","google","naver"].includes(snsType || "")) return { ok: true, user_key: `${snsType}:${String(snsId)}`, from: "sns" };

  return { ok: false, error: "missing user identity (userKey OR userId OR snsUserId+snsLoginType)" };
}

router.get("/health", (_req, res)=> res.json({ ok:true, db: DB_HOST + "/" + DB_NAME }));
router.get("/whoami", (req, res)=> res.json({ identity: resolveIdentity(req), headers: req.headers, query: req.query }));

async function computeServerOrder(conn, { user_key, client_utc, id }) {
  const sql = `
    SELECT COUNT(*) AS higher
      FROM tb_interview_result
     WHERE user_key = :user_key
       AND (client_utc > :client_utc OR (client_utc = :client_utc AND id > :id))
  `;
  const [rows] = await conn.execute(sql, { user_key, client_utc, id });
  const higher = Number(rows?.[0]?.higher ?? 0);
  return higher + 1;
}

router.post("/attempt", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok && !ALLOW_GUEST) return res.status(400).json(idn);

  try {
    const { attemptTime, clientKst, interviewTitle, title, attemptOrder, clientRound, score, total, byCategory, riskBars } = req.body || {};
    if (!attemptTime) return res.status(400).json({ ok:false, error:"missing attemptTime" });

    const clientUtc = new Date(attemptTime);
    if (isNaN(clientUtc.getTime())) return res.status(400).json({ ok:false, error:"invalid attemptTime" });

    const rb = riskBars || computeRiskBars(byCategory || {});
    const mysqlClientUtc = isoToMysqlDatetime(clientUtc.toISOString());
    if (!mysqlClientUtc) return res.status(400).json({ ok:false, error:"invalid attemptTime (to mysql)" });

    const sql = `
      INSERT INTO tb_interview_result
      (user_key, client_round, title, score, total, client_utc, client_kst, risk_bars)
      VALUES
      (:user_key, :client_round, :title, :score, :total, :client_utc, :client_kst, :risk_bars)
    `;
    const params = {
      user_key: idn.ok ? idn.user_key : "guest",
      client_round: (attemptOrder ?? clientRound) ?? null,
      title: normalizeTitle(interviewTitle || title || ""),
      score: Number(score ?? 0),
      total: Number(total ?? 0),
      client_utc: mysqlClientUtc,
      client_kst: clientKst || formatKst(clientUtc),
      risk_bars: JSON.stringify(rb || {}),
    };

    const conn = await pool.getConnection();
    try {
      const [ret] = await conn.execute(sql, params);
      const insertedId = ret.insertId;

      const [rows] = await conn.execute(
        `SELECT id, user_key, client_round, title, score, total, client_utc, client_kst, risk_bars, created_at
           FROM tb_interview_result
          WHERE id = ?
          LIMIT 1`,
        [insertedId]
      );
      const row = rows[0];
      const serverOrder = await computeServerOrder(conn, { user_key: row.user_key, client_utc: row.client_utc, id: row.id });

      const risk = safeParseJSON(row.risk_bars, {});
      const byCatRestored = barsToCategoryStats(risk);

      const debugText = [
        "=============== [IR Attempt] ===============",
        `서버 회차    : ${serverOrder}회차`,
        `클라 회차    : ${row.client_round ?? ""}`,
        `제목         : ${row.title || "(없음)"}`,
        `점수/총점    : ${Number(row.score ?? 0)}/${Number(row.total ?? 0)}`,
        `Client KST   : ${row.client_kst || formatKst(new Date(row.client_utc))}`,
        `riskBars     : ${prettyRiskBars(risk)}`,
        "============================================",
      ].join("\n");

      return res.json({
        ok: true,
        saved: {
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
          debugText,
          createdAt: row.created_at,
        },
      });
    } finally {
      conn.release();
    }
  } catch (e) {
    console.error("[IR] /attempt error:", e?.message || e);
    return res.status(500).json({ ok:false, error:"server_error", detail:String(e?.message || e) });
  }
});

router.get("/latest", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok) return res.status(400).json(idn);

  const qTitle = normalizeTitle(req.query.title || "");
  const whereTitle = qTitle ? "AND title = :title" : "";

  const sql = `
    SELECT id, user_key, client_round, title, score, total, client_utc, client_kst, risk_bars, created_at
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
    if (!rows.length) return res.json({ ok:true, latest:null });

    const row = rows[0];
    const risk = safeParseJSON(row.risk_bars, {});
    const byCategory = barsToCategoryStats(risk);
    const clientKst = row.client_kst || (row.client_utc ? formatKst(new Date(row.client_utc)) : "");

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

    return res.json({
      ok: true,
      latest: {
        title: row.title,
        interviewTitle: row.title,
        clientRound: row.client_round,
        clientAttemptOrder: row.client_round,
        score: Number(row.score ?? 0),
        total: Number(row.total ?? 0),
        attemptTime: row.client_utc ? new Date(row.client_utc).toISOString() : null,
        clientKst,
        riskBars: risk,
        byCategory,
        serverAttemptOrder: 1,
        debugText,
        createdAt: row.created_at,
      },
    });
  } catch (e) {
    console.error("[IR] /latest error:", e?.message || e);
    return res.status(500).json({ ok:false, error:"server_error", detail:String(e?.message || e) });
  } finally {
    conn.release();
  }
});

router.get("/attempt/list", async (req, res) => {
  const idn = resolveIdentity(req);
  if (!idn.ok && !ALLOW_GUEST) return res.status(400).json(idn);

  const userKey = idn.ok ? idn.user_key : "guest";
  const limit = Math.min(Math.max(parseInt(String(req.query.limit || "30"), 10) || 30, 1), 200);

  const sql = `
    SELECT id, title, client_round, score, total, client_utc, client_kst, risk_bars, created_at
      FROM tb_interview_result
     WHERE user_key = :user_key
     ORDER BY client_utc DESC, id DESC
     LIMIT ${limit}
  `;
  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(sql, { user_key: userKey });
    const list = rows.map((row, idx) => {
      const risk = safeParseJSON(row.risk_bars, {});
      const byCategory = barsToCategoryStats(risk);
      const score = Number(row.score ?? 0);
      const total = Number(row.total ?? 0);
      const clientKst = row.client_kst || (row.client_utc ? formatKst(new Date(row.client_utc)) : "");
      const attemptIso = row.client_utc ? new Date(row.client_utc).toISOString() : null;
      const serverOrder = idx + 1;

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
        score, total,
        attemptTime: attemptIso,
        clientKst,
        riskBars: risk,
        byCategory,
        scoreText: `${score}/${total}`,
        serverAttemptOrder: serverOrder,
        debugText,
        createdAt: row.created_at,
      };
    });

    return res.json({ ok:true, list });
  } catch (e) {
    console.error("[IR] /attempt/list error:", e?.message || e);
    return res.status(500).json({ ok:false, error:"server_error", detail:String(e?.message || e) });
  } finally {
    conn.release();
  }
});

module.exports = router;

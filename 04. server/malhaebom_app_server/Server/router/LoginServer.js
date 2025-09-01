// File: src/Server/router/LoginServer.js
require("dotenv").config();

const express = require("express");
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const router = express.Router();

/* =========================
 * DB 설정
 * ========================= */
const DB_CONFIG = {
  host: process.env.DB_HOST || "project-db-campus.smhrd.com",
  port: Number(process.env.DB_PORT || 3307),
  user: process.env.DB_USER || "campus_25SW_BD_p3_3",
  password: process.env.DB_PASSWORD || "smhrd3",
  database: process.env.DB_NAME || "campus_25SW_BD_p3_3",
  connectTimeout: 10000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 10000,
  multipleStatements: false,
  timezone: "Z",
};

const pool = mysql.createPool({
  ...DB_CONFIG,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

pool.on?.("connection", (conn) => {
  // 세션 타임아웃(8h) 연장
  conn.promise().query("SET SESSION wait_timeout=28800, interactive_timeout=28800").catch(() => {});
});

// DB keepalive ping
const PING_INTERVAL_MS = 30 * 1000;
setInterval(async () => {
  try { await pool.query("SELECT 1"); }
  catch (e) { console.warn("[DB] keepalive ping failed:", e?.code || e?.message); }
}, PING_INTERVAL_MS);

// 재시도 래퍼
async function execWithRetry(sql, params = [], { tries = 3, label = "" } = {}) {
  let lastErr;
  for (let i = 1; i <= tries; i++) {
    try {
      const [rows] = await pool.execute(sql, params);
      return rows;
    } catch (err) {
      lastErr = err;
      const transient =
        err?.code === "ECONNRESET" ||
        err?.code === "PROTOCOL_CONNECTION_LOST" ||
        err?.code === "ETIMEDOUT";
      console.warn(
        `[DB] query failed${label ? " (" + label + ")" : ""}, try ${i}/${tries}:`,
        err?.code || err?.message
      );
      if (!transient || i === tries) break;
      await new Promise((r) => setTimeout(r, 300 * i));
    }
  }
  throw lastErr;
}

/* =========================
 * JWT (Auther/STR와 통일)
 * ========================= */
const JWT_SECRET = process.env.JWT_SECRET || "malhaebom_sns";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";
const JWT_ISS = process.env.JWT_ISS || undefined; // 예: 'malhaebom-auth'
const JWT_AUD = process.env.JWT_AUD || undefined; // 예: 'malhaebom-app'

function sign(payload) {
  const opts = { expiresIn: JWT_EXPIRES_IN };
  if (JWT_ISS) opts.issuer = JWT_ISS;
  if (JWT_AUD) opts.audience = JWT_AUD;
  return jwt.sign(payload, JWT_SECRET, opts);
}

function auth(req, res, next) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ message: "토큰 필요" });
  try {
    const opts = {};
    if (JWT_ISS) opts.issuer = JWT_ISS;
    if (JWT_AUD) opts.audience = JWT_AUD;
    req.user = jwt.verify(token, JWT_SECRET, opts);
    next();
  } catch (e) {
    return res.status(401).json({ message: "유효하지 않은 토큰", code: e?.name || "" });
  }
}

/* =========================
 * 로그인 (local)
 *  POST /userLogin/login
 *  body: { login_id(or user_id), pwd }
 * ========================= */
router.post("/login", async (req, res) => {
  try {
    // 호환: user_id → login_id
    const login_id = String(req.body.login_id ?? req.body.user_id ?? "").trim();
    const pwd = String(req.body.pwd ?? "");
    if (!login_id || !pwd) {
      return res.status(400).json({ message: "login_id, pwd가 필요합니다." });
    }

    const rows = await execWithRetry(
      "SELECT user_id AS uid, login_id, login_type, pwd, nick, birthyear, gender FROM tb_user WHERE login_id = ? AND login_type='local' LIMIT 1",
      [login_id],
      { label: "login select" }
    );
    if (!rows.length) {
      return res.status(401).json({ message: "아이디 또는 비밀번호 오류" });
    }

    const user = rows[0];
    const ok = await bcrypt.compare(pwd, user.pwd || "");
    if (!ok) {
      return res.status(401).json({ message: "아이디 또는 비밀번호 오류" });
    }

    const token = sign({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "local",
      nick: user.nick,
    });

    return res.json({
      token,
      user: {
        uid: user.uid,
        login_id: user.login_id,
        login_type: "local",
        nick: user.nick,
        birthyear: user.birthyear,
        gender: user.gender,
      },
    });
  } catch (err) {
    console.error("[/login] error:", err);
    return res.status(500).json({ message: "서버 오류", code: err?.code || "" });
  }
});

/* =========================
 * 내 정보 조회 (JWT 필요)
 * ========================= */
router.get("/me", auth, async (req, res) => {
  try {
    const uid = Number(req.user.uid);
    if (!uid) return res.status(400).json({ message: "잘못된 토큰" });

    const rows = await execWithRetry(
      "SELECT user_id AS uid, login_id, login_type, nick, birthyear, gender FROM tb_user WHERE user_id = ? LIMIT 1",
      [uid],
      { label: "me select" }
    );
    if (!rows.length) return res.status(404).json({ message: "사용자 없음" });
    return res.json({ user: rows[0] });
  } catch (err) {
    console.error("[/me] error:", err);
    return res.status(500).json({ message: "서버 오류", code: err?.code || "" });
  }
});

/* 헬스체크 */
router.get("/healthz", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, db: `${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}` });
  } catch (e) {
    res.status(500).json({ ok: false, code: e?.code || e?.message });
  }
});

module.exports = router;

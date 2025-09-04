// Server/router/LoginServer.js
const express = require("express");
const router = express.Router();
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

/* =========================
 * 환경변수
 * ========================= */
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://127.0.0.1:3001";
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || process.env.PUBLIC_BASE_URL || "https://malhaebom.smhrd.com";
const JWT_SECRET        = process.env.JWT_SECRET        || "malhaebom_sns";
const COOKIE_NAME       = process.env.COOKIE_NAME       || "mb_access";

// 현재 배포는 HTTP(80) → 반드시 false (HTTPS 전환 시 true)
const SECURE_COOKIE = /^https:\/\//i.test(
  process.env.FRONTEND_BASE_URL || process.env.PUBLIC_BASE_URL || ""
);

/* =========================
 * DB 풀
 * ========================= */
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
  connectionLimit  : 10,
});

/* =========================
 * 캐시 방지(이 라우터 전역)
 * ========================= */
router.use((req, res, next) => {
  res.set({
    "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
    "Pragma": "no-cache",
    "Expires": "0",
    "Surrogate-Control": "no-store",
    "Vary": "Cookie",
  });
  next();
});

/* =========================
 * 유틸
 * ========================= */
function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}
function setAuthCookie(res, token) {
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure  : SECURE_COOKIE,
    sameSite: "lax",
    maxAge  : 7 * 24 * 60 * 60 * 1000,
    path    : "/",
  });
}
function clearAuthCookie(res) {
  res.clearCookie(COOKIE_NAME, {
    httpOnly: true,
    secure  : SECURE_COOKIE,
    sameSite: "lax",
    path    : "/",
  });
}
function composeUserKey(login_type, login_id) {
  if (!login_type || !login_id) return null;
  return login_type === "local" ? String(login_id) : `${login_type}:${login_id}`;
}

/* =========================
 * 로컬 로그인
 * ========================= */
router.post("/login", async (req, res) => {
  try {
    const { login_id, user_id, phone, pwd } = req.body || {};
    const id = (login_id || user_id || phone || "").trim();

    if (!id || !pwd) {
      return res.status(400).json({ ok: false, msg: "아이디/비밀번호를 입력하세요." });
    }

    const [rows] = await pool.query(
      `SELECT user_id, login_id, pwd, nick
         FROM tb_user
        WHERE login_id = ? AND login_type = 'local'
        LIMIT 1`,
      [id]
    );
    if (!rows.length) return res.status(401).json({ ok: false, msg: "존재하지 않는 계정입니다." });

    const u = rows[0];
    const ok = await bcrypt.compare(String(pwd), String(u.pwd || ""));
    if (!ok) return res.status(401).json({ ok: false, msg: "비밀번호가 올바르지 않습니다." });

    console.log("[LOGIN SUCCESS] user:", {
      user_id: u.user_id,
      login_id: u.login_id,
      nick: u.nick,
    });

    const token = sign({ uid: u.user_id, typ: "local" });
    setAuthCookie(res, token);

    return res.json({
      ok: true,
      userId: u.user_id,
      loginId: u.login_id,
      nick: u.nick,
      loginType: "local",
      userKey: composeUserKey("local", u.login_id),
      cookie: { name: COOKIE_NAME, secure: SECURE_COOKIE, sameSite: "lax" },
    });
  } catch (err) {
    console.error("[/userLogin/login] error:", err);
    return res.status(500).json({ ok: false, msg: "로그인 중 오류가 발생했습니다." });
  }
});

/* 로그아웃 */
router.post("/logout", async (_req, res) => {
  try {
    clearAuthCookie(res);
    return res.json({ ok: true });
  } catch (err) {
    console.error("[/userLogin/logout] error:", err);
    return res.status(500).json({ ok: false });
  }
});

/* 내 정보 */
router.get("/me", async (req, res) => {
  try {
    const token = req.cookies?.[COOKIE_NAME];

    if (!token) {
      return res.json({ ok: false, isAuthed: false });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (_e) {
      clearAuthCookie(res);
      return res.json({ ok: false, isAuthed: false });
    }

    const [rows] = await pool.query(
      `SELECT user_id, login_id, login_type, nick
         FROM tb_user
        WHERE user_id = ? AND login_type = ?
        LIMIT 1`,
      [decoded.uid, decoded.typ]
    );
    if (!rows.length) {
      clearAuthCookie(res);
      return res.json({ ok: false, isAuthed: false });
    }

    const u = rows[0];
    const userKey = composeUserKey(u.login_type, u.login_id);
    return res.json({
      ok: true,
      isAuthed: true,
      loginType: u.login_type,
      userId: u.user_id,
      loginId: u.login_id,
      nick: u.nick,
      userKey,
    });
  } catch (err) {
    console.error("[/userLogin/me] error:", err);
    return res.status(500).json({ ok: false, isAuthed: false });
  }
});

module.exports = router;

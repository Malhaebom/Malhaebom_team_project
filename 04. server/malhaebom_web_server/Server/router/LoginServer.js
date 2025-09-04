// Server/router/LoginServer.js
const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("./db");

/* =========================
 * ENV
 * ========================= */
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://127.0.0.1:3001";
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || process.env.PUBLIC_BASE_URL || "https://malhaebom.smhrd.com";
const JWT_SECRET        = process.env.JWT_SECRET        || "malhaebom_sns";
const COOKIE_NAME       = process.env.COOKIE_NAME       || "mb_access";

/* =========================
 * Cache bust
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
 * Utils
 * ========================= */
function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}
function isSecureReq(req) {
  return !!(req?.secure || String(req?.headers?.["x-forwarded-proto"] || "").toLowerCase() === "https");
}
function setAuthCookie(req, res, token) {
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure  : isSecureReq(req),
    sameSite: "lax",
    maxAge  : 7 * 24 * 60 * 60 * 1000,
    path    : "/",
  });
}
function clearAuthCookie(req, res) {
  res.clearCookie(COOKIE_NAME, {
    httpOnly: true,
    secure  : isSecureReq(req),
    sameSite: "lax",
    path    : "/",
  });
}
function composeUserKey(login_type, login_id) {
  if (!login_type || !login_id) return null;
  return login_type === "local" ? String(login_id) : `${login_type}:${login_id}`;
}

/* =========================
 * Local login
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

    // typ(하위호환) + login_type + login_id 모두 포함
    const token = sign({ uid: u.user_id, typ: "local", login_id: u.login_id, login_type: "local" });
    setAuthCookie(req, res, token);

    return res.json({
      ok: true,
      userId: u.user_id,
      loginId: u.login_id,
      nick: u.nick,
      loginType: "local",
      userKey: u.login_id,                               // 표준 user_key
      userKeyFull: composeUserKey("local", u.login_id),  // 참조용
      cookie: { name: COOKIE_NAME, secure: isSecureReq(req), sameSite: "lax" },
    });
  } catch (err) {
    console.error("[/userLogin/login] error:", err);
    return res.status(500).json({ ok: false, msg: "로그인 중 오류가 발생했습니다." });
  }
});

/* 로그아웃 */
router.post("/logout", async (req, res) => {
  try {
    clearAuthCookie(req, res);
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
    if (!token) return res.json({ ok: false, isAuthed: false });

    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (_e) {
      clearAuthCookie(req, res);
      return res.json({ ok: false, isAuthed: false });
    }

    const loginType = decoded.login_type || decoded.typ; // 하위호환
    const [rows] = await pool.query(
      `SELECT user_id, login_id, login_type, nick
         FROM tb_user
        WHERE user_id = ? AND login_type = ?
        LIMIT 1`,
      [decoded.uid, loginType]
    );
    if (!rows.length) {
      clearAuthCookie(req, res);
      return res.json({ ok: false, isAuthed: false });
    }

    const u = rows[0];
    const userKey = u.login_id;
    return res.json({
      ok: true,
      isAuthed: true,
      loginType: u.login_type,
      userId: u.user_id,
      loginId: u.login_id,
      nick: u.nick,
      userKey,                               // 예: "01012345678"
      userKeyFull: `${u.login_type}:${u.login_id}`,
    });
  } catch (err) {
    console.error("[/userLogin/me] error:", err);
    return res.status(500).json({ ok: false, isAuthed: false });
  }
});

module.exports = router;

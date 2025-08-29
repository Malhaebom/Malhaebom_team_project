// Server/router/LoginServer.js
const express = require("express");
const router = express.Router();
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

/* =========================
 * 하드코딩 설정
 * ========================= */
const DB_CONFIG = {
  host: "project-db-campus.smhrd.com",
  port: 3307,
  user: "campus_25SW_BD_p3_3",
  password: "smhrd3",
  database: "campus_25SW_BD_p3_3",
};

const JWT_SECRET = "malhaebom_sns"; // 데모/로컬용
const COOKIE_NAME = "mb_access";
const pool = mysql.createPool({ ...DB_CONFIG, waitForConnections: true, connectionLimit: 10 });

/* =========================
 * 유틸
 * ========================= */
function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}

function setAuthCookie(res, token) {
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure: false,     // 로컬 개발
    sameSite: "lax",
    maxAge: 7 * 24 * 60 * 60 * 1000,
    path: "/",
  });
}

function clearAuthCookie(res) {
  res.clearCookie(COOKIE_NAME, {
    httpOnly: true,
    secure: false,
    sameSite: "lax",
    path: "/",
  });
}

/* =========================
 * 로컬 로그인
 * ========================= */
/**
 * POST /userLogin/login
 * body: { user_id | phone, pwd }
 */
router.post("/login", async (req, res) => {
  try {
    const { user_id, phone, pwd } = req.body || {};
    const loginId = user_id || phone;

    if (!loginId || !pwd) {
      return res.status(400).json({ ok: false, msg: "아이디/비밀번호를 입력하세요." });
    }

    const [rows] = await pool.query(
      "SELECT user_id, pwd, nick FROM tb_user WHERE user_id = ?",
      [loginId]
    );
    if (!rows.length) return res.status(401).json({ ok: false, msg: "존재하지 않는 계정입니다." });

    const user = rows[0];
    const ok = await bcrypt.compare(String(pwd), String(user.pwd));
    if (!ok) return res.status(401).json({ ok: false, msg: "비밀번호가 올바르지 않습니다." });

    const token = sign({ sub: user.user_id, typ: "local" });
    setAuthCookie(res, token);

    return res.json({ ok: true, nick: user.nick, userId: user.user_id, loginType: "local" });
  } catch (err) {
    console.error("[/userLogin/login] error:", err);
    return res.status(500).json({ ok: false, msg: "로그인 중 오류가 발생했습니다." });
  }
});

/* 로그아웃 */
router.post("/logout", async (req, res) => {
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
    const token = req.cookies[COOKIE_NAME];
    if (!token) return res.json({ ok: false, isAuthed: false });

    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (e) {
      clearAuthCookie(res);
      return res.json({ ok: false, isAuthed: false });
    }

    if (decoded.typ === "local") {
      const [rows] = await pool.query(
        "SELECT user_id, nick FROM tb_user WHERE user_id = ?",
        [decoded.sub]
      );
      if (!rows.length) {
        clearAuthCookie(res);
        return res.json({ ok: false, isAuthed: false });
      }
      const u = rows[0];
      return res.json({
        ok: true,
        isAuthed: true,
        loginType: "local",
        userId: u.user_id,
        nick: u.nick,
      });
    } else if (decoded.typ === "sns") {
      const [rows] = await pool.query(
        "SELECT sns_user_id, sns_nick, sns_login_type FROM tb_sns_user WHERE sns_user_id = ?",
        [decoded.sub]
      );
      if (!rows.length) {
        clearAuthCookie(res);
        return res.json({ ok: false, isAuthed: false });
      }
      const s = rows[0];
      return res.json({
        ok: true,
        isAuthed: true,
        loginType: s.sns_login_type,
        userId: s.sns_user_id,
        nick: s.sns_nick,
      });
    }

    clearAuthCookie(res);
    return res.json({ ok: false, isAuthed: false });
  } catch (err) {
    console.error("[/userLogin/me] error:", err);
    return res.status(500).json({ ok: false, isAuthed: false });
  }
});

module.exports = router;

// src/Server/router/LoginServer.js
const express = require("express");
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const router = express.Router();

/* =========================
 * DB 설정 (주신 값 적용)
 * ========================= */
const DB_CONFIG = {
  host: "project-db-campus.smhrd.com",
  port: 3307,
  user: "campus_25SW_BD_p3_3",
  password: "smhrd3",
  database: "campus_25SW_BD_p3_3",
};

const pool = mysql.createPool({
  ...DB_CONFIG,
  waitForConnections: true,
  connectionLimit: 10,
});

/* =========================
 * JWT 설정 (하드코딩)
 * ========================= */
const JWT_SECRET = "malhaebom";
const JWT_EXPIRES_IN = "7d";

function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function auth(req, res, next) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ message: "토큰 필요" });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: "유효하지 않은 토큰" });
  }
}

/* =========================
 * 테이블: tb_user
 *  - user_id  (PK, 전화번호)
 *  - pwd      (해시 저장)
 *  - nick
 *  - birthyear (YEAR)
 *  - gender   (CHAR(1))
 * ========================= */

/* 회원가입 */
router.post("/register", async (req, res) => {
  try {
    let { user_id, pwd, nick, birthyear, gender } = req.body;
    if (!user_id || !pwd || !nick || !birthyear || !gender) {
      return res.status(400).json({ message: "모든 필드(user_id, pwd, nick, birthyear, gender)가 필요합니다." });
    }

    // YEAR 타입은 4자리 숫자 필요
    birthyear = Number(birthyear);
    if (!Number.isInteger(birthyear) || birthyear < 1900 || birthyear > 2100) {
      return res.status(400).json({ message: "birthyear는 4자리 연도여야 합니다." });
    }

    // 비밀번호 해시
    const hash = await bcrypt.hash(pwd, 12);

    const sql = `
      INSERT INTO tb_user (user_id, pwd, nick, birthyear, gender)
      VALUES (?, ?, ?, ?, ?)
    `;
    await pool.execute(sql, [user_id, hash, nick, birthyear, gender]);

    res.status(201).json({ message: "회원가입 성공" });
  } catch (e) {
    if (e.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "이미 존재하는 user_id(전화번호)입니다." });
    }
    console.error(e);
    res.status(500).json({ message: "서버 오류" });
  }
});

/* 로그인 */
router.post("/login", async (req, res) => {
  const { user_id, pwd } = req.body;
  if (!user_id || !pwd) {
    return res.status(400).json({ message: "user_id, pwd가 필요합니다." });
  }

  const [rows] = await pool.execute(
    "SELECT * FROM tb_user WHERE user_id = ? LIMIT 1",
    [user_id]
  );
  if (!rows.length) {
    return res.status(401).json({ message: "아이디 또는 비밀번호 오류" });
  }

  const user = rows[0];
  const ok = await bcrypt.compare(pwd, user.pwd);
  if (!ok) {
    return res.status(401).json({ message: "아이디 또는 비밀번호 오류" });
  }

  const token = sign({ id: user.user_id, nick: user.nick });
  res.json({
    token,
    user: {
      user_id: user.user_id,
      nick: user.nick,
      birthyear: user.birthyear,
      gender: user.gender,
    },
  });
});

/* 내 정보 조회 (JWT 필요) */
router.get("/me", auth, async (req, res) => {
  const userId = req.user.id;
  const [rows] = await pool.execute(
    "SELECT user_id, nick, birthyear, gender FROM tb_user WHERE user_id = ? LIMIT 1",
    [userId]
  );
  if (!rows.length) return res.status(404).json({ message: "사용자 없음" });
  res.json({ user: rows[0] });
});


/* 비밀번호 변경 (옵션) */
/*
router.post("/change-password", auth, async (req, res) => {
  const { old_pwd, new_pwd } = req.body;
  if (!old_pwd || !new_pwd) {
    return res.status(400).json({ message: "old_pwd, new_pwd가 필요합니다." });
  }

  const userId = req.user.id;
  const [rows] = await pool.execute(
    "SELECT pwd FROM tb_user WHERE user_id = ? LIMIT 1",
    [userId]
  );
  if (!rows.length) return res.status(404).json({ message: "사용자 없음" });

  const ok = await bcrypt.compare(old_pwd, rows[0].pwd);
  if (!ok) return res.status(401).json({ message: "기존 비밀번호가 일치하지 않습니다." });

  const hash = await bcrypt.hash(new_pwd, 12);
  await pool.execute("UPDATE tb_user SET pwd = ? WHERE user_id = ?", [hash, userId]);
  res.json({ message: "비밀번호 변경 완료" });
});
*/

module.exports = router;

// src/Server/router/JoinServer.js
const express = require("express");
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");

const router = express.Router();

/* =========================
 * DB 설정 (LoginServer.js와 동일)
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
 * 유효성 검사 유틸 (필요 최소한)
 * ========================= */
function isValidYear(v) {
  const y = Number(v);
  return Number.isInteger(y) && y >= 1900 && y <= 2100;
}
function nonEmpty(v, maxLen = 255) {
  return typeof v === "string" && v.trim().length > 0 && v.length <= maxLen;
}
function isGender1(v) {
  // 필요 시 'M','F'만 허용. 확장하려면 정규식 수정.
  return typeof v === "string" && /^[MF]$/.test(v);
}

/* =========================
 * (선택) 아이디 중복 체크
 *  GET /join/exists/user_id?user_id=01012341234
 * ========================= */
router.get("/exists/user_id", async (req, res) => {
  try {
    const user_id = (req.query.user_id ?? "").trim();
    if (!nonEmpty(user_id, 50)) {
      return res.status(400).json({ ok: false, message: "user_id 형식 오류" });
    }
    const [rows] = await pool.execute(
      "SELECT 1 FROM tb_user WHERE user_id = ? LIMIT 1",
      [user_id]
    );
    return res.json({ ok: true, exists: rows.length > 0 });
  } catch (e) {
    console.error("[/join/exists/user_id] error:", e);
    return res.status(500).json({ ok: false, message: "서버 오류" });
  }
});

/* =========================
 * (선택) 닉네임 중복 체크
 *  GET /join/exists/nick?nick=레벤
 * ========================= */
router.get("/exists/nick", async (req, res) => {
  try {
    const nick = (req.query.nick ?? "").trim();
    if (!nonEmpty(nick, 20)) {
      return res.status(400).json({ ok: false, message: "nick 형식 오류(1~20자)" });
    }
    const [rows] = await pool.execute(
      "SELECT 1 FROM tb_user WHERE nick = ? LIMIT 1",
      [nick]
    );
    return res.json({ ok: true, exists: rows.length > 0 });
  } catch (e) {
    console.error("[/join/exists/nick] error:", e);
    return res.status(500).json({ ok: false, message: "서버 오류" });
  }
});

/* =========================
 * 회원가입
 *  POST /join/register
 *  body: { user_id, pwd, nick, birthyear, gender }
 * ========================= */
router.post("/register", async (req, res) => {
  try {
    let { user_id, pwd, nick, birthyear, gender } = req.body ?? {};

    // 1) 필수값 체크
    if (!user_id || !pwd || !nick || !birthyear || !gender) {
      return res
        .status(400)
        .json({ message: "모든 필드(user_id, pwd, nick, birthyear, gender)가 필요합니다." });
    }

    // 2) 형식 검증
    if (!nonEmpty(user_id, 50)) {
      return res.status(400).json({ message: "user_id 형식 오류" });
    }
    if (!nonEmpty(pwd, 255)) {
      return res.status(400).json({ message: "pwd 형식 오류" });
    }
    if (!nonEmpty(nick, 20)) {
      return res.status(400).json({ message: "nick 형식 오류(1~20자)" });
    }
    if (!isValidYear(birthyear)) {
      return res.status(400).json({ message: "birthyear는 4자리 연도(1900~2100)여야 합니다." });
    }
    if (!isGender1(gender)) {
      return res.status(400).json({ message: "gender는 'M' 또는 'F' 여야 합니다." });
    }

    // 3) user_id 중복 검사
    const [dups] = await pool.execute(
      "SELECT 1 FROM tb_user WHERE user_id = ? LIMIT 1",
      [user_id]
    );
    if (dups.length > 0) {
      return res.status(409).json({ message: "이미 존재하는 user_id(전화번호)입니다." });
    }

    // (선택) 닉네임 중복 제한을 원하면 주석 해제
    // const [dupsNick] = await pool.execute(
    //   "SELECT 1 FROM tb_user WHERE nick = ? LIMIT 1",
    //   [nick]
    // );
    // if (dupsNick.length > 0) {
    //   return res.status(409).json({ message: "이미 존재하는 닉네임입니다." });
    // }

    // 4) 비밀번호 해시
    const hash = await bcrypt.hash(pwd, 12);

    // 5) INSERT
    const sql = `
      INSERT INTO tb_user (user_id, pwd, nick, birthyear, gender)
      VALUES (?, ?, ?, ?, ?)
    `;
    await pool.execute(sql, [user_id.trim(), hash, nick.trim(), Number(birthyear), gender]);

    return res.status(201).json({ message: "회원가입 성공" });
  } catch (e) {
    if (e.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "이미 존재하는 user_id(전화번호)입니다." });
    }
    console.error("[/join/register] error:", e);
    return res.status(500).json({ message: "서버 오류" });
  }
});

module.exports = router;
